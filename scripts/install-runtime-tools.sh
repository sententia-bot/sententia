#!/usr/bin/env bash
# install-runtime-tools.sh
# Installs userland CLI tools into $HOME (PVC-backed, persistent across pod restarts).
# Idempotent — safe to re-run; skips already-installed tools.
# Run as user: node
set -euo pipefail

ARCH_RAW="$(uname -m)"
case "${ARCH_RAW}" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)  ARCH="arm-v7" ;;
  *) echo "Unsupported architecture: ${ARCH_RAW}" >&2; exit 1 ;;
esac

OS="linux"
HOME_BIN="${HOME}/.local/bin"
DOCKER_PLUGINS_DIR="${HOME}/.docker/cli-plugins"

mkdir -p "${HOME_BIN}" "${DOCKER_PLUGINS_DIR}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

download() { curl -fsSL "$1" -o "$2"; }

latest_gh_tag() {
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" -o "$tmp"
  grep -m1 '"tag_name"' "$tmp" | sed -E 's/.*"([^"]+)".*/\1/'
  rm -f "$tmp"
}

# --- kubectl ---
install_kubectl() {
  if need_cmd kubectl; then
    echo "kubectl: already installed ($(kubectl version --client --short 2>/dev/null | head -n1))"
    return 0
  fi
  echo "Installing kubectl..."
  local ver tmp
  ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  tmp="$(mktemp)"
  download "https://dl.k8s.io/release/${ver}/bin/${OS}/${ARCH}/kubectl" "$tmp"
  install -m 0755 "$tmp" "${HOME_BIN}/kubectl"
  rm -f "$tmp"
  echo "kubectl: installed ${ver}"
}

# --- gh CLI ---
install_gh() {
  if need_cmd gh; then
    echo "gh: already installed ($(gh --version | head -n1))"
    return 0
  fi
  echo "Installing gh CLI..."
  local tag ver archive tmpdir
  tag="$(latest_gh_tag cli/cli)"
  ver="${tag#v}"
  archive="gh_${ver}_${OS}_${ARCH}.tar.gz"
  tmpdir="$(mktemp -d)"
  download "https://github.com/cli/cli/releases/download/${tag}/${archive}" "${tmpdir}/${archive}"
  tar -xzf "${tmpdir}/${archive}" -C "${tmpdir}"
  install -m 0755 "${tmpdir}/gh_${ver}_${OS}_${ARCH}/bin/gh" "${HOME_BIN}/gh"
  rm -rf "$tmpdir"
  echo "gh: installed ${ver}"
}

# --- Rust ---
install_rust() {
  if need_cmd rustc; then
    echo "rust: already installed ($(rustc --version))"
    return 0
  fi
  echo "Installing Rust toolchain..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable
  echo "rust: installed"
}

# --- Docker CLI + buildx ---
install_docker() {
  if need_cmd docker; then
    echo "docker: already installed ($(docker --version))"
  else
    echo "Installing Docker CLI..."
    local tag ver docker_arch tgz tmpdir
    tag="$(latest_gh_tag docker/cli)"
    ver="${tag#v}"
    case "$ARCH" in
      amd64) docker_arch="x86_64" ;;
      arm64) docker_arch="aarch64" ;;
      *) echo "docker CLI: unsupported arch ${ARCH}" >&2; return 1 ;;
    esac
    tgz="docker-${ver}.tgz"
    tmpdir="$(mktemp -d)"
    download "https://download.docker.com/${OS}/static/stable/${docker_arch}/${tgz}" "${tmpdir}/${tgz}"
    tar -xzf "${tmpdir}/${tgz}" -C "${tmpdir}"
    install -m 0755 "${tmpdir}/docker/docker" "${HOME_BIN}/docker"
    rm -rf "$tmpdir"
    echo "docker: installed ${ver}"
  fi

  if [[ -x "${DOCKER_PLUGINS_DIR}/docker-buildx" ]]; then
    echo "docker-buildx: already installed"
  else
    echo "Installing docker-buildx..."
    local tag tmp
    tag="$(latest_gh_tag docker/buildx)"
    tmp="$(mktemp)"
    download "https://github.com/docker/buildx/releases/download/${tag}/buildx-${tag}.${OS}-${ARCH}" "$tmp"
    install -m 0755 "$tmp" "${DOCKER_PLUGINS_DIR}/docker-buildx"
    rm -f "$tmp"
    echo "docker-buildx: installed ${tag}"
  fi
}

# --- nerdctl (containerd CLI for local image builds) ---
install_nerdctl() {
  if need_cmd nerdctl; then
    echo "nerdctl: already installed ($(nerdctl --version))"
    return 0
  fi
  echo "Installing nerdctl..."
  local tag ver nerd_arch archive tmpdir
  tag="$(latest_gh_tag containerd/nerdctl)"
  ver="${tag#v}"
  case "$ARCH" in
    amd64)  nerd_arch="amd64" ;;
    arm64)  nerd_arch="arm64" ;;
    arm-v7) nerd_arch="arm-v7" ;;
    *) echo "nerdctl: unsupported arch ${ARCH}" >&2; return 1 ;;
  esac
  archive="nerdctl-${ver}-${OS}-${nerd_arch}.tar.gz"
  tmpdir="$(mktemp -d)"
  download "https://github.com/containerd/nerdctl/releases/download/${tag}/${archive}" "${tmpdir}/${archive}"
  tar -xzf "${tmpdir}/${archive}" -C "${tmpdir}"
  install -m 0755 "${tmpdir}/nerdctl" "${HOME_BIN}/nerdctl"
  rm -rf "$tmpdir"
  echo "nerdctl: installed ${ver}"
}

# --- ffmpeg (amd64 static only; skipped on arm) ---
install_ffmpeg() {
  if need_cmd ffmpeg; then
    echo "ffmpeg: already installed ($(ffmpeg -version 2>&1 | head -n1))"
    return 0
  fi
  if [[ "$ARCH" != "amd64" ]]; then
    echo "ffmpeg: skipping static install on ${ARCH} (install via apt on this arch if needed)"
    return 0
  fi
  echo "Installing ffmpeg static (amd64)..."
  local tmpdir archive dir
  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/ffmpeg.tar.xz"
  download "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz" "$archive"
  tar -xJf "$archive" -C "$tmpdir"
  dir="$(find "$tmpdir" -maxdepth 1 -type d -name 'ffmpeg-*static' | head -n1)"
  install -m 0755 "${dir}/ffmpeg"  "${HOME_BIN}/ffmpeg"
  install -m 0755 "${dir}/ffprobe" "${HOME_BIN}/ffprobe"
  rm -rf "$tmpdir"
  echo "ffmpeg: installed"
}

# --- PATH hint ---
ensure_path() {
  local rc="${HOME}/.bashrc"
  if ! grep -q 'HOME/.local/bin' "$rc" 2>/dev/null; then
    printf '\n# Added by scripts/install-runtime-tools.sh\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
  fi
  # Also add cargo/bin if rust was installed
  if ! grep -q 'cargo/bin' "$rc" 2>/dev/null; then
    printf 'export PATH="$HOME/.cargo/bin:$PATH"\n' >> "$rc"
  fi
}

main() {
  echo "=== install-runtime-tools.sh (arch: ${ARCH}) ==="
  install_kubectl
  install_gh
  install_rust
  install_docker
  install_nerdctl
  install_ffmpeg
  ensure_path
  echo
  echo "=== Done. Tools installed to: ${HOME_BIN} ==="
}

main "$@"
