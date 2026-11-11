FROM kalilinux/kali-rolling

# Install only essential tools and clean caches immediately to minimize disk size
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    whois \
    clamav \
    ca-certificates \
    nano \
    bind9-dnsutils \
    clamav-freshclam \
    mc \
    python3-dotenv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add the convenient terminal shortcut for your upgraded parser script
RUN echo "alias parsephish='python3 /home/kali/analysis/parse_phish.py'" >> /root/.bashrc
RUN echo "alias searchphish='python3 /home/kali/analysis/search_tracker.py'" >> /root/.bashrc
