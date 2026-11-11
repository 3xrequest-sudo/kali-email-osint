```text
   ____________________

  |\                  /|   [ Kali Email OSINT & Triage ]
  | \   [REDACTED]   / |   > Zero-API-Key CLI Pipeline
  |  \______________/  |   > Modular Recon + ClamAV Microservice
  |____________________|
```

# Modular CLI Email OSINT & Malware Triage Toolkit

A lightweight, zero-API-key Bash suite designed to safely redact, parse, and investigate raw `.eml` files using native Linux utilities (`grep`, `perl`, `sed`, `dig`, `whois`, `sha256sum`, `file`, `ripmime`) paired with a standalone ClamAV Docker microservice.

> **Built Collaboratively:** Designed and iterated step-by-step on a Raspberry Pi ARM64 Docker environment in collaboration with Gemini AI, focusing on operational security, minimal resource footprint, and true Unix modularity.

---

## Why This Exists (Design Philosophy)

While enterprise SOC platforms (TheHive, MISP), web tools (CyberChef, PhishTool), and Python parsers (`eml_analyzer`) exist, most require heavy RAM overhead, external Python dependencies, paid API keys (VirusTotal, AbuseIPDB), or uploading private emails to third-party web servers.

This toolkit takes a different approach:
* **Zero API Keys & Zero Third-Party Leaks:** Every DNS query, WHOIS trace, hash check, and antivirus scan runs locally or directly against authoritative infrastructure with zero cloud dependencies.
* **OpSec-First Redaction:** Personal email aliases and name variations are scrubbed *before* any parsing or report generation occurs, ensuring private details never leak into saved OSINT logs or ISP abuse reports.
* **Microservice Architecture:** Heavy antivirus signature databases are isolated in a separate, self-updating ClamAV container rather than bloating the analysis container.

---

## Pipeline Architecture

* **`01_eml_prep.sh`** — Creates a dedicated `<filename>_report/` workspace, copies the `.eml` non-destructively, redacts personal addresses/names listed in `my_emails.txt`, decodes Quoted-Printable/URL-encoded obfuscation, and extracts clean target domain and public IP lists.
* **`02_domain_dig.sh`** — Queries `A`, `MX`, `TXT`/`SPF`, `DMARC`, and `DKIM` records for every extracted target domain and outputs individual `dig_<domain>.txt` reports.
* **`03_ip_whois.sh`** — Performs rate-limited (`2s` delay) `whois` lookups against all extracted public IPv4 addresses and saves individual `whois_<ip>.txt` reports.
* **`04_file_triage.sh`** — Generates SHA-256 fingerprints, scans for MIME attachments, extracts embedded files into `attachments/` for magic-byte inspection, and streams the payload over TCP (`--stream`) to the standalone ClamAV container.
* **`05_build_report.sh`** — Compiles core headers, extracted domains, IP abuse contacts, attachment triage findings, and the redacted raw email source into a copy-pasteable `abuse_report_draft.txt`.
* **`run_osint.sh`** — Master wrapper script that executes modules `01` through `05` sequentially against a target `.eml` file.

---

## Standalone ClamAV Container Setup

To avoid `systemd` issues and keep 300MB+ of virus signatures out of the Kali container, ClamAV runs as a dedicated microservice on the Raspberry Pi host bound strictly to the Docker bridge gateway (`172.17.0.1`).

### 1. Host `docker-compose.yml` (`~/docker/clamav/docker-compose.yml`)
```yaml
services:
  clamav:
    image: clamav/clamav-debian:latest
    container_name: clamav-service
    restart: unless-stopped
    ports:
      - "172.17.0.1:3310:3310"
    volumes:
      - ./data:/var/lib/clamav
```
*(Note: Allow 2–3 minutes on initial startup for `freshclam` to download `daily.cvd`, `main.cvd`, and `bytecode.cvd` before `clamd` opens port `3310`).*

### 2. Kali Client Configuration (`clamd_remote.conf`)
Inside the Kali container (`172.17.0.2`), install the client binary (`apt update && apt install -y clamav-daemon`) and point `clamd_remote.conf` at the Docker bridge gateway:
```text
TCPSocket 3310
TCPAddr 172.17.0.1
```
Test connectivity anytime with:
```bash
clamdscan --config-file=/home/kali/analysis/clamd_remote.conf --ping 5
```

---

## Setup & Usage

### 1. Configure Your Private Exclusion List
Create `my_emails.txt` (ignored by Git) with your personal email addresses and name variations, one per line:
```bash
cat << 'EOF' > my_emails.txt
first.alias@example.com
second.alias@example.com
First Last
first.last
EOF
chmod 600 my_emails.txt
```

### 2. Capture a Suspicious Email
View the raw message source (`Show Original` / `View Source`) in your mail client, copy it to your clipboard, and paste it directly into a timestamped file inside `raw_emails/`:
```bash
nano "raw_emails/$(date +%F)_raw-description.eml"
```
*(Save and exit `nano` with `Ctrl+O`, `Enter`, `Ctrl+X`).*

### 3. Run the Full Pipeline
Point the master wrapper at your newly captured `.eml` file:
```bash
./run_osint.sh "raw_emails/\$(date +%F)_raw-description.eml"
```
All outputs—including `abuse_report_draft.txt`—are saved inside `<filename>_report/`.

### 4. Or Run Individual Modules
You can also run each step independently against an existing report folder:
```bash
./01_eml_prep.sh raw_emails/suspicious_email.eml
./02_domain_dig.sh suspicious_email_report/
./03_ip_whois.sh suspicious_email_report/
./04_file_triage.sh suspicious_email_report/
./05_build_report.sh suspicious_email_report/
```

---

## Lessons Learned & Real-World Roadblocks Solved

Building and testing this toolkit against live phishing lures uncovered several classic email-parsing traps that are now hardened in the code:

* **Quoted-Printable & Open-Redirect Obfuscation:** Phishing emails frequently wrap malicious links inside legitimate Google open redirects (`google.ca/url?q=...`) and split URLs across lines using `=3D` and trailing `=` soft line breaks. Added `perl -MMIME::QuotedPrint` and URL percent-decoding in `01_eml_prep.sh` to automatically unwrap hidden payload domains.
* **Phantom IP Regex Collisions (`DODIIS` / Version Numbers):** Scanning entire raw `.eml` bodies for `0.0.0.0` patterns matched timestamps and software version strings (e.g., `11.09.19.43`), triggering false-positive `whois` lookups against legacy U.S. Department of Defense (`11.0.0.0/8`) IP blocks. Fixed by scoping IP extraction strictly to routing headers (`Received:`, `X-Originating-Ip:`, `Authentication-Results:`) and `http` URLs with strict octet validation.
* **Reversed PTR Hostname IPs:** Reverse DNS hostnames (such as `static.252.13.245.188.clients.your-server.de`) embed the server's IP backwards. Added boundary checks around IP matching so embedded PTR strings do not trigger bogus `whois` queries.
* **Leading Hyphens Breaking `dig`:** MIME boundary markers attached to domain strings (e.g., `--static...`) caused `dig` to interpret the target domain as a CLI option flag. Hardened domain regex extraction to require an alphanumeric starting character.
* **Debian `clamdscan` Packaging:** On Debian/Kali, `clamdscan` is packaged inside `clamav-daemon` rather than a standalone `clamdscan` package, and `clamd_remote.conf` must be populated before `clamdscan` will parse or ping the remote container.
