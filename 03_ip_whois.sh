#!/bin/bash

# Check if a report directory argument was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_report_directory>"
    exit 1
fi

REPORT_DIR="${1%/}"
IPS_FILE="$REPORT_DIR/target_ips.txt"

if [ ! -f "$IPS_FILE" ]; then
    echo "[-] Error: '$IPS_FILE' not found. Run 01_eml_prep.sh first."
    exit 1
fi

echo "[+] Starting WHOIS network trace on IPs in $REPORT_DIR..."

while IFS= read -r ip || [ -n "$ip" ]; do
    [[ -z "$ip" ]] && continue

    OUT_FILE="$REPORT_DIR/whois_${ip}.txt"
    echo "[*] Querying WHOIS for: $ip"

    {
        echo "=================================================="
        echo "WHOIS Network Report: $ip"
        echo "Timestamp (UTC): $(date -u)"
        echo "=================================================="
        echo ""
        whois "$ip"
    } > "$OUT_FILE"

    # Polite 2-second delay to prevent RIR rate-limiting
    sleep 2

done < "$IPS_FILE"

echo "[+] WHOIS lookups complete. Reports saved in $REPORT_DIR/"
