FROM kalilinux/kali-rolling

# Install only essential tools and clean caches immediately to minimize disk size
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    whois \
    ca-certificates \
    nano \
    bind9-dnsutils \
    clamav-daemon \
    ripmime \
    file \
    git \
    openssh-client \
    mc \
    python3-dotenv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

