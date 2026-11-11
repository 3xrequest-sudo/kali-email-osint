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

DRAFT_FILE="$REPORT_DIR/abuse_report_draft.txt"

echo "[+] Compiling abuse & OSINT summary report in $REPORT_DIR..."

# Extract core header metadata safely
SUBJECT_LINE=$(grep -im 1 "^Subject:" "$EML_FILE" | sed 's/\r//g')
DATE_LINE=$(grep -im 1 "^Date:" "$EML_FILE" | sed 's/\r//g')
RETURN_PATH=$(grep -im 1 "^Return-Path:" "$EML_FILE" | sed 's/\r//g')
ORIGIN_IP=$(grep -im 1 "^X-Originating-Ip:" "$EML_FILE" | sed 's/\r//g')

# Extract SHA-256 hash if triage report exists
EMAIL_HASH=$(sha256sum "$EML_FILE" | awk '{print $1}')

{
    echo "======================================================================"
    echo " AUTOMATED EMAIL OSINT & ABUSE REPORT SUMMARY"
    echo " Generated (UTC): $(date -u)"
    echo "======================================================================"
    echo ""
    echo "To: [Insert Abuse Contact Email from Section 3 Below]"
    echo "Subject: Abuse Report: Unsolicited Email / Phishing Infrastructure"
    echo ""
    echo "Hello Abuse Team,"
    echo ""
    echo "I am reporting unsolicited/malicious email activity observed from"
    echo "infrastructure associated with your network. Key technical indicators"
    echo "are summarized below, followed by the redacted raw email headers."
    echo ""
    echo "----------------------------------------------------------------------"
    echo " 1. CORE MESSAGE METADATA"
    echo "----------------------------------------------------------------------"
    echo "${DATE_LINE:-Date: [Not Found]}"
    echo "${SUBJECT_LINE:-Subject: [Not Found]}"
    echo "${RETURN_PATH:-Return-Path: [Not Found]}"
    [ -n "$ORIGIN_IP" ] && echo "$ORIGIN_IP"
    echo "Redacted EML SHA-256: $EMAIL_HASH"
    echo ""
    echo "----------------------------------------------------------------------"
    echo " 2. EXTRACTED TARGET DOMAINS & URLS"
    echo "----------------------------------------------------------------------"
    if [ -s "$REPORT_DIR/target_domains.txt" ]; then
        cat "$REPORT_DIR/target_domains.txt"
    else
        echo "None extracted."
    fi
    echo ""
    echo "----------------------------------------------------------------------"
    echo " 3. PUBLIC IP INFRASTRUCTURE & ABUSE CONTACTS"
    echo "----------------------------------------------------------------------"
    if [ -s "$REPORT_DIR/target_ips.txt" ]; then
        while IFS= read -r ip || [ -n "$ip" ]; do
            [[ -z "$ip" ]] && continue
            echo "[*] IP Address: $ip"
            WHOIS_FILE="$REPORT_DIR/whois_${ip}.txt"
            if [ -f "$WHOIS_FILE" ]; then
                # Pull key network owner and abuse contact lines from saved whois
                grep -Ei '^(netname:|orgname:|org-name:|descr:|country:|abuse-mailbox:|OrgAbuseEmail:|% Abuse contact)' "$WHOIS_FILE" | head -n 8 | sed 's/^/    /'
            else
                echo "    [No WHOIS file found - run 03_ip_whois.sh first]"
            fi
            echo ""
        done < "$REPORT_DIR/target_ips.txt"
    else
        echo "None extracted."
    fi
    echo "----------------------------------------------------------------------"
    echo " 4. ATTACHMENT & MALWARE TRIAGE SUMMARY"
    echo "----------------------------------------------------------------------"
    if [ -f "$REPORT_DIR/file_triage_report.txt" ]; then
        grep -A 15 "^\[+\] MIME Attachment Headers Found:" "$REPORT_DIR/file_triage_report.txt"
    else
        echo "Triage report not run."
    fi
    echo ""
    echo "======================================================================"
    echo " BEGIN REDACTED RAW EMAIL HEADERS & SOURCE"
    echo "======================================================================"
    echo ""
    cat "$EML_FILE"
    echo ""
    echo "======================================================================"
    echo " END REDACTED RAW EMAIL HEADERS & SOURCE"
    echo "======================================================================"
} > "$DRAFT_FILE"

echo "[+] Report compiled successfully: $DRAFT_FILE"
