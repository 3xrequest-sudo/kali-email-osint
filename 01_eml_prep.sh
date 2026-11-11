#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_email.eml>"
    exit 1
fi

EML_FILE="$1"
CONFIG_EMAILS="/home/kali/analysis/my_emails.txt"

if [ ! -f "$EML_FILE" ]; then
    echo "[-] Error: File '$EML_FILE' not found."
    exit 1
fi

if [ ! -f "$CONFIG_EMAILS" ]; then
    echo "[-] Error: Config file '$CONFIG_EMAILS' not found."
    exit 1
fi

BASENAME=$(basename "$EML_FILE" .eml)
REPORT_DIR="/home/kali/analysis/${BASENAME}_report"

mkdir -p "$REPORT_DIR"
echo "[+] Created workspace: $REPORT_DIR"

# 1. Non-destructive copy & redaction
REDACTED_FILE="$REPORT_DIR/${BASENAME}_redacted.eml"
cp "$EML_FILE" "$REDACTED_FILE"

while IFS= read -r email || [ -n "$email" ]; do
    [[ -z "$email" || "$email" =~ ^# ]] && continue
    sed -i "s/${email}/[REDACTED]/Ig" "$REDACTED_FILE"
done < "$CONFIG_EMAILS"

echo "[+] Redacted personal email addresses into: ${BASENAME}_redacted.eml"

# 2. Decode Quoted-Printable & URL-encoded strings, then extract target domains
DOMAINS_FILE="$REPORT_DIR/target_domains.txt"

perl -MMIME::QuotedPrint -ne 'print decode_qp($_)' "$REDACTED_FILE" | \
    sed 's/%3A/:/Ig; s/%2F/\//Ig; s/%3F/?/Ig; s/%3D/=/Ig; s/%26/\&/Ig' | \
    grep -Eio '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | \
    tr '[:upper:]' '[:lower:]' | \
    grep -Ev '(^|\.)(yahoo\.com|yahoo\.com\.au|hotmail\.com|outlook\.com|gmail\.com|google\.com|google\.ca|google\.com\.au|1e100\.net|w3\.org|schema\.org)$' | \
    grep -Ev '^(smtp\.mailfrom|header\.from|header\.i|header\.s)$' | \
    grep -Ev '\.(png|jpg|jpeg|gif|css|js|html|htm|eml|txt|pdf|zip)$' | \
    sort -u > "$DOMAINS_FILE"

echo "[+] Extracted $(wc -l < "$DOMAINS_FILE") unique target domains to: target_domains.txt"


# 3. Extract and filter valid public IPv4 addresses from routing headers & URLs
IPS_FILE="$REPORT_DIR/target_ips.txt"

grep -Ei '^(Received:|X-Originating-Ip:|Authentication-Results:|.*https?://)' "$REDACTED_FILE" | \
    grep -Eio '\b((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\b' | \
    grep -Ev '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|0\.|255\.)' | \
    sort -u > "$IPS_FILE"

echo "[+] Extracted $(wc -l < "$IPS_FILE") unique public IPs to: target_ips.txt"

