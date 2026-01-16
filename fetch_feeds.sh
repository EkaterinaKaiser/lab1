#!/usr/bin/env bash
set -uo pipefail

FEEDS_DIR="feeds"
mkdir -p "$FEEDS_DIR"

echo "[*] Fetching IoC feeds..."

echo "[+] Downloading Feodo Tracker IPs..."
curl -s "https://feodotracker.abuse.ch/downloads/ipblocklist_recommended.txt" \
  -o "$FEEDS_DIR/feodo_ips.txt" || echo "[!] Failed to download Feodo Tracker"

echo "[+] Downloading URLhaus IPs..."
curl -s "https://urlhaus.abuse.ch/downloads/csv_recent/" | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u > "$FEEDS_DIR/urlhaus_ips.txt" || \
  echo "[!] Failed to download URLhaus"

echo "[+] Downloading Botvrij.eu IPs..."
curl -s "https://www.botvrij.eu/data/ioclist.ip-src" \
  -o "$FEEDS_DIR/botvrij_ips.txt" || echo "[!] Failed to download Botvrij.eu"

echo "[+] Downloading Google Cloud IPs..."
if command -v jq >/dev/null 2>&1; then
  curl -s "https://www.gstatic.com/ipranges/cloud.json" | \
    jq -r '.prefixes[]? | select(.ipv4Prefix != null) | .ipv4Prefix' > "$FEEDS_DIR/google_cloud_ips.txt" 2>/dev/null || \
    echo "[!] Failed to download Google Cloud IPs"
else
  curl -s "https://www.gstatic.com/ipranges/cloud.json" | \
    grep -oE '"ipv4Prefix":\s*"[^"]*"' | cut -d'"' -f4 | grep -v '^$' > "$FEEDS_DIR/google_cloud_ips.txt" 2>/dev/null || \
    echo "[!] Failed to download Google Cloud IPs (jq not installed)"
fi

echo "[+] Downloading AWS IPs..."
if command -v jq >/dev/null 2>&1; then
  curl -s "https://ip-ranges.amazonaws.com/ip-ranges.json" | \
    jq -r '.prefixes[]? | select(.ip_prefix != null) | .ip_prefix' > "$FEEDS_DIR/aws_ips.txt" 2>/dev/null || \
    echo "[!] Failed to download AWS IPs"
else
  curl -s "https://ip-ranges.amazonaws.com/ip-ranges.json" | \
    grep -oE '"ip_prefix":\s*"[^"]*"' | cut -d'"' -f4 | grep -v '^$' > "$FEEDS_DIR/aws_ips.txt" 2>/dev/null || \
    echo "[!] Failed to download AWS IPs (jq not installed)"
fi

echo "[+] Downloading Azure IPs..."
curl -s "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519" 2>/dev/null | \
  grep -oE 'https://download\.microsoft\.com[^"]*\.json' | head -1 | \
  xargs -I {} curl -s {} 2>/dev/null | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | sort -u > "$FEEDS_DIR/azure_ips.txt" 2>/dev/null || \
  echo "[!] Failed to download Azure IPs"

echo "[+] Downloading Cloudflare IPs..."
curl -s "https://www.cloudflare.com/ips-v4" > "$FEEDS_DIR/cloudflare_ips.txt" 2>/dev/null || \
  echo "[!] Failed to download Cloudflare IPs"

echo "[+] Downloading DigitalOcean IPs..."
curl -s "https://raw.githubusercontent.com/digitalocean/do_user_scripts/master/Utility/do-ip-ranges.sh" 2>/dev/null | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | sort -u > "$FEEDS_DIR/digitalocean_ips.txt" 2>/dev/null || \
  curl -s "https://www.digitalocean.com/geo/google.csv" 2>/dev/null | \
  cut -d',' -f1 | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}' > "$FEEDS_DIR/digitalocean_ips.txt" 2>/dev/null || \
  echo "[!] Failed to download DigitalOcean IPs"

echo "[+] Downloading Antifilter IPs..."
curl -s "https://antifilter.download/list/allyouneed.lst" | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u > "$FEEDS_DIR/antifilter_ips.txt" 2>/dev/null || \
  curl -s "https://antifilter.network/list/allyouneed.lst" | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u > "$FEEDS_DIR/antifilter_ips.txt" 2>/dev/null || \
  echo "[!] Failed to download Antifilter IPs"

echo "[+] Downloading Zapret-info IPs..."
curl -s "https://github.com/zapret-info/z-i/raw/master/dump.csv" 2>/dev/null | \
  awk -F';' '{print $1; if ($2 != "" && $2 ~ /^[0-9]/) print $2}' | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' | \
  grep -vE '^[0-9]{4,}' | sort -u > "$FEEDS_DIR/zapret_ips.txt" || \
  echo "[!] Failed to download Zapret-info IPs"

echo "[+] Downloading Роскомсвобода IPs..."
if command -v jq >/dev/null 2>&1; then
  curl -s "https://reestr.rublacklist.net/api/v2/ips/json/" 2>/dev/null | \
    jq -r '.[] | select(.ip != null) | .ip' > "$FEEDS_DIR/rublacklist_ips.txt" 2>/dev/null || \
    echo "[!] Failed to download Роскомсвобода IPs"
else
  curl -s "https://reestr.rublacklist.net/api/v2/ips/json/" 2>/dev/null | \
    grep -oE '"ip":\s*"[^"]*"' | cut -d'"' -f4 | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$FEEDS_DIR/rublacklist_ips.txt" 2>/dev/null || \
    echo "[!] Failed to download Роскомсвобода IPs (jq not installed)"
fi

echo "[+] Feed download completed!"
echo "[*] Summary:"
for feed in "$FEEDS_DIR"/*.txt; do
  if [ -f "$feed" ]; then
    count=$(wc -l < "$feed" 2>/dev/null || echo "0")
    echo "  - $(basename "$feed"): $count lines"
  fi
done
