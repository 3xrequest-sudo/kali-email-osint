#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_report_directory>"
    exit 1
fi

REPORT_DIR="${1%/}"
EML_FILE=$(find "$REPORT_DIR" -maxdepth 1 -name "*_redacted.eml" | head -n 1)

if [ -z "$EML_FILE" ] || [ ! -f "$EML_FILE" ]; then
    echo "[-] Error: No *_redacted.eml file found in '$REPORT_DIR'."
    exit 1
fi

TRIAGE_REPORT="$REPORT_DIR/file_triage_report.txt"
ATTACH_DIR="$REPORT_DIR/attachments"
REMOTE_CLAM_CONF="/home/kali/analysis/clamd_remote.conf"

echo "[+] Starting file & attachment triage in $REPORT_DIR..."

{
    echo "=================================================="
    echo "File & Attachment Triage Report"
    echo "Target File: $(basename "$EML_FILE")"
    echo "Timestamp (UTC): $(date -u)"
    echo "=================================================="

    echo -e "\n[+] Email SHA-256 Hash:"
    sha256sum "$EML_FILE"

    echo -e "\n[+] MIME Attachment Headers Found:"
    grep -Ei '(Content-Disposition:|filename=)' "$EML_FILE" || echo "None detected."

} > "$TRIAGE_REPORT"

# Check if any attachments exist and unpack them safely
if grep -Eiq 'filename=' "$EML_FILE"; then
    mkdir -p "$ATTACH_DIR"
    echo "[!] Attachment markers detected! Extracting to $ATTACH_DIR..."

    if command -v ripmime >/dev/null 2>&1; then
        ripmime -i "$EML_FILE" -d "$ATTACH_DIR" --no-nameless
    elif command -v munpack >/dev/null 2>&1; then
        munpack -q -C "$ATTACH_DIR" "$EML_FILE" >/dev/null 2>&1
    else
        echo "[-] Note: Install 'ripmime' or 'mpack' to auto-extract attachments." >> "$TRIAGE_REPORT"
    fi

    {
        echo -e "\n[+] Extracted Attachments Analysis (Magic Bytes & SHA-256):"
        for item in "$ATTACH_DIR"/*; do
            [ -f "$item" ] || continue
            echo "--------------------------------------------------"
            file "$item"
            sha256sum "$item"
        done
    } >> "$TRIAGE_REPORT"
fi

# Stream file to the standalone ClamAV container if clamdscan and config exist
if command -v clamdscan >/dev/null 2>&1 && [ -f "$REMOTE_CLAM_CONF" ]; then
    echo "[*] Streaming file to standalone ClamAV container..."
    {
        echo -e "\n[+] ClamAV Container Scan Result:"
        clamdscan --config-file="$REMOTE_CLAM_CONF" --stream --no-summary "$EML_FILE" 2>&1
    } >> "$TRIAGE_REPORT"
else
    echo "[-] Note: clamdscan missing (run: apt update && apt install -y clamav-daemon)"
    echo -e "\n[+] ClamAV Scan Result: Skipped (install 'clamav-daemon' to enable container scanning)." >> "$TRIAGE_REPORT"
fi

echo "[+] Triage complete. Saved to: $TRIAGE_REPORT"
