FROM ghcr.io/openclaw/openclaw:latest

USER root

# Adoptium Temurin repo for JRE 21
RUN apt-get update && apt-get install -y --no-install-recommends wget apt-transport-https gnupg && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ca-certificates-java \
    && update-ca-certificates \
    temurin-21-jre \
    ffmpeg \
    dumb-init \
    curl \
    git \
    vim \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl for read-only cluster access
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl" \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# Install Playwright dependencies and Chromium
# System deps for Chromium on Debian Bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright and Chromium as node user
USER node
WORKDIR /home/node
RUN npm install playwright && npx playwright install chromium

USER node
WORKDIR /home/node

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "/app/openclaw.mjs", "gateway", "--bind", "0.0.0.0"]
