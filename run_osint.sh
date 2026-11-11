#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_email.eml>"
    exit 1
fi

EML_FILE="$1"
BASE_DIR="/home/kali/analysis"

if [ ! -f "$EML_FILE" ]; then
    echo "[-] Error: File '$EML_FILE' not found."
    exit 1
fi

BASENAME=$(basename "$EML_FILE" .eml)
REPORT_DIR="$BASE_DIR/${BASENAME}_report"

echo "=================================================="
echo " Starting Full Email OSINT Pipeline"
echo " Target: $EML_FILE"
echo "=================================================="

"$BASE_DIR/01_eml_prep.sh" "$EML_FILE" || exit 1
"$BASE_DIR/02_domain_dig.sh" "$REPORT_DIR"
"$BASE_DIR/03_ip_whois.sh" "$REPORT_DIR"
"$BASE_DIR/04_file_triage.sh" "$REPORT_DIR"
"$BASE_DIR/05_build_report.sh" "$REPORT_DIR"

echo "=================================================="
echo " [+] All modules complete! Reports saved to:"
echo "     $REPORT_DIR/"
echo "=================================================="

