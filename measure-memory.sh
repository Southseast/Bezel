#!/bin/bash
# Measures the real memory cost of the black bar.
#
# A/B test on the running app: physical footprint with the bar disabled
# vs enabled (same binary, only the bar window differs). The previous
# barEnabled setting is restored afterwards.
#
# Usage: ./measure-memory.sh    (app must be built: ./make.sh)
set -euo pipefail
cd "$(dirname "$0")"

DOMAIN="st.southsea.bezel"
KEY="barEnabled"
APP="build/Bezel.app"

[ -d "$APP" ] || { echo "App bundle missing — run ./make.sh first"; exit 1; }

footprint() {
    local pid
    pid=$(pgrep -f "MacOS/Bezel" | head -1)
    [ -z "$pid" ] && { echo "app not running"; exit 1; }
    vmmap --summary "$pid" 2>/dev/null \
        | awk '/^Physical footprint:/ {printf "%.1f", $3 + 0; exit}'
}

restart() {
    pkill -f "MacOS/Bezel" 2>/dev/null || true
    sleep 1
    open "$APP"
    sleep 4
}

prev=$(defaults read "$DOMAIN" "$KEY" 2>/dev/null || echo 1)

restart
on=$(footprint)
echo "bar on:  ${on} MB"

defaults write "$DOMAIN" "$KEY" -bool false
restart
off=$(footprint)
echo "bar off: ${off} MB"

# Restore the setting the user had before the measurement.
if [ "$prev" = "1" ] || [ "$prev" = "true" ]; then
    defaults write "$DOMAIN" "$KEY" -bool true
else
    defaults write "$DOMAIN" "$KEY" -bool false
fi
restart

echo "-----------------------------"
awk -v o="$on" -v f="$off" 'BEGIN { printf "black bar memory cost: %.1f MB\n", o - f }'
echo "setting restored to: barEnabled=$(defaults read "$DOMAIN" "$KEY"), app restarted"
