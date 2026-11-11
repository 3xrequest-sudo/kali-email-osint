#!/bin/bash

# Check if a report directory argument was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_report_directory>"
    exit 1
fi

REPORT_DIR="${1%/}"
DOMAINS_FILE="$REPORT_DIR/target_domains.txt"

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "[-] Error: '$DOMAINS_FILE' not found. Run 01_eml_prep.sh first."
    exit 1
fi

echo "[+] Starting DNS recon on domains in $REPORT_DIR..."

while IFS= read -r raw_domain || [ -n "$raw_domain" ]; do
    [[ -z "$raw_domain" ]] && continue

    # Strip 'www.' prefix so MX, SPF, and DMARC lookups hit the root domain
    ROOT_DOMAIN="${raw_domain#www.}"
    OUT_FILE="$REPORT_DIR/dig_${ROOT_DOMAIN}.txt"

    echo "[*] Querying DNS for: $ROOT_DOMAIN (from $raw_domain)"

    {
        echo "=================================================="
        echo "DNS OSINT Report: $ROOT_DOMAIN"
        echo "Original Extracted String: $raw_domain"
        echo "Timestamp (UTC): $(date -u)"
        echo "=================================================="

        echo -e "\n[+] A Records (IPv4):"
        dig +short A "$ROOT_DOMAIN"

        echo -e "\n[+] MX Records (Mail Servers):"
        dig +short MX "$ROOT_DOMAIN"

        echo -e "\n[+] TXT / SPF Records:"
        dig +short TXT "$ROOT_DOMAIN"

        echo -e "\n[+] DMARC Policy (_dmarc):"
        dig +short TXT "_dmarc.$ROOT_DOMAIN"

        echo -e "\n[+] DKIM Record (default selector):"
        dig +short TXT "default._domainkey.$ROOT_DOMAIN"
    } > "$OUT_FILE"

done < "$DOMAINS_FILE"

echo "[+] DNS recon complete. Reports saved in $REPORT_DIR/"
