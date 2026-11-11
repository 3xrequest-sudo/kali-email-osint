#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_report_directory>"
    exit 1
fi

REPORT_DIR="${1%/}"
# Locate the redacted .eml file inside the report folder
EML_FILE=$(find "$REPORT_DIR" -maxdepth 1 -name "*_redacted.eml" | head -n 1)

if [ -z "$EML_FILE" ] || [ ! -f "$EML_FILE" ]; then
    echo "[-] Error: No *_redacted.eml file found in '$REPORT_DIR'."
    exit 1
fi

TRIAGE_REPORT="$REPORT_DIR/file_triage_report.txt"
ATTACH_DIR="$REPORT_DIR/attachments"

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

    # Use ripmime if installed, otherwise fallback to munpack
    if command -v ripmime >/dev/null 2>&1; then
        ripmime -i "$EML_FILE" -d "$ATTACH_DIR" --no-nameless
    elif command -v munpack >/dev/null 2>&1; then
        munpack -q -C "$ATTACH_DIR" "$EML_FILE" >/dev/null 2>&1
    else
        echo "[-] Note: Install 'ripmime' or 'mpack' to auto-extract attachments." >> "$TRIAGE_REPORT"
    fi

    # Hash and identify the true file type of every extracted attachment
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

# Optional: Run ClamAV only if databases exist and clamscan is present
if command -v clamscan >/dev/null 2>&1 && [ -d /var/lib/clamav ] && [ "$(ls -A /var/lib/clamav 2>/dev/null)" ]; then
    echo "[*] Running local ClamAV scan..."
    {
        echo -e "\n[+] ClamAV Scan Result:"
        clamscan --no-summary "$EML_FILE"
    } >> "$TRIAGE_REPORT"
else
    echo -e "\n[+] ClamAV Scan Result: Skipped (No active local signature database found)." >> "$TRIAGE_REPORT"
fi

echo "[+] Triage complete. Saved to: $TRIAGE_REPORT"
