ARG OPENCLAW_TAG=latest
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_TAG}

USER root

# Base system deps — only what's needed at container start or requires root/apt:
# - dumb-init: entrypoint init
# - ca-certificates, curl, wget, gnupg: bootstrap for secure fetches
# - temurin-21-jre: system JRE (apt-managed, root-required)
# - Playwright shared system libs: browser automation deps (apt-level, shared libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    apt-transport-https \
    dumb-init \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    ffmpeg \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
      | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
      > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-21-jre \
    && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /home/node

# Userland tools (kubectl, gh, rust, docker cli, nerdctl) are installed
# on first run via scripts/install-runtime-tools.sh — persisted by PVC-backed $HOME.

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "/app/openclaw.mjs", "gateway", "--bind", "0.0.0.0"]
