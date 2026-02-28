# Sententia

OpenClaw container with Playwright, kubectl, git, Python, Java, and FFmpeg.

## Manual Build & Push

The GitHub Action builds on push to main, but if you need to do it manually:

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Build and push natively on the Pi
docker build -t ghcr.io/albindalbert/sententia:latest .
docker push ghcr.io/albindalbert/sententia:latest

# Or cross-compile from another machine
docker buildx build --platform linux/arm64 -t ghcr.io/albindalbert/sententia:latest --push .
```

sudo docker build --pull -t ghcr.io/albindalbert/sententia:latest .
sudo docker save ghcr.io/albindalbert/sententia:latest -o sententia.tar
sudo ctr -n=k8s.io images import sententia.tar
