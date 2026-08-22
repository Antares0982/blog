#!/usr/bin/env bash
# Copy just the uploads the posts actually reference into static/.
# scripts/assets.txt is written by import-wordpress.py.
set -euo pipefail

HOST="${1:-antares}"
REMOTE_ROOT="${2:-/var/lib/wordpress/chr.fan/uploads}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# URLs are percent-encoded; the files on disk are not.
python3 -c '
import sys, urllib.parse
for line in sys.stdin:
    line = line.strip()
    if line:
        print(urllib.parse.unquote(line).removeprefix("/wp-content/uploads/"))
' < "$ROOT/scripts/assets.txt" > /tmp/blog-assets-decoded.txt

mkdir -p "$ROOT/static/wp-content/uploads"
ssh "$HOST" "sudo tar -C '$REMOTE_ROOT' -czf - -T -" \
    < /tmp/blog-assets-decoded.txt \
    | tar -C "$ROOT/static/wp-content/uploads" -xzf -

echo "fetched $(wc -l < /tmp/blog-assets-decoded.txt) files"
du -sh "$ROOT/static/wp-content/uploads"
