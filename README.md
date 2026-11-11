# Modular CLI Email OSINT Toolkit

A lightweight, zero-API-key Bash suite designed to safely redact, parse, and investigate raw `.eml` files using native Linux utilities (`grep`, `perl`, `sed`, `dig`, `whois`, `sha256sum`, `file`, and optional `ripmime`/`clamscan`).

## Pipeline Architecture

* **`01_eml_prep.sh`** — Creates a dedicated report directory, copies the `.eml` non-destructively, redacts personal addresses listed in `my_emails.txt`, decodes Quoted-Printable/URL-encoded obfuscation, and extracts clean target domain and public IP lists.
* **`02_domain_dig.sh`** — Queries `A`, `MX`, `TXT`/`SPF`, `DMARC`, and `DKIM` records for every extracted target domain and outputs individual `dig_<domain>.txt` reports.
* **`03_ip_whois.sh`** — Performs rate-limited (`2s` delay) `whois` lookups against all extracted public IPv4 addresses and saves individual `whois_<ip>.txt` reports.
* **`04_file_triage.sh`** — Generates SHA-256 fingerprints, scans for MIME attachments, extracts embedded files into `attachments/` for magic-byte inspection, and runs an optional local `clamscan` if active signature databases are present.
* **`run_osint.sh`** — Master wrapper script that executes modules `01` through `04` sequentially against a target `.eml` file.

---

## Setup & Prerequisites

1. **Create your private exclusion file** (ignored by Git) containing your personal email addresses, one per line:
   ```bash
   cat << 'EOF' > my_emails.txt
   first.alias@example.com
   second.alias@example.com
   EOF
   chmod 600 my_emails.txt
   ```

2. **Verify native CLI dependencies** (pre-installed on most Kali builds):
   ```bash
   apt update && apt install -y dnsutils whois perl file ripmime
   ```

---

## Usage

### Run the Full Pipeline (Recommended)
Point the master wrapper at any raw `.eml` file:
```bash
./run_osint.sh raw_emails/suspicious_email.eml
```
All outputs are saved inside `<filename>_report/`.

### Run Individual Modules
You can also run each step independently:
```bash
./01_eml_prep.sh raw_emails/suspicious_email.eml
./02_domain_dig.sh suspicious_email_report/
./03_ip_whois.sh suspicious_email_report/
./04_file_triage.sh suspicious_email_report/
```
