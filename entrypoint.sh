#!/bin/sh
set -eu

# Panel base path must match nginx's routing path, BEFORE the panel starts.
/app/x-ui setting -webBasePath /xp9k3panel/ >/dev/null 2>&1 || true

# Fixed panel login. Override with Railway Variables PANEL_USER / PANEL_PASS.
PANEL_USER="${PANEL_USER:-AXIS}"
PANEL_PASS="${PANEL_PASS:-e456t530}"
/app/x-ui setting -username "$PANEL_USER" -password "$PANEL_PASS" >/dev/null 2>&1 || true

# Start panel + Xray via 3x-ui's own entrypoint, in the background.
/app/DockerEntrypoint.sh &

sleep 3

export PORT="${PORT:-8080}"

# Default "worker_processes auto" spawns one worker per host core.
sed -i 's/^worker_processes.*/worker_processes 2;/' /etc/nginx/nginx.conf

envsubst '${PORT}' < /etc/nginx/http.d/default.conf.template > /etc/nginx/http.d/default.conf

echo "=== Generated nginx config (/etc/nginx/http.d/default.conf) ==="
cat /etc/nginx/http.d/default.conf
echo "================================================================"

if ! nginx -t; then
    echo "!!! NGINX CONFIG TEST FAILED (see errors above) !!!"
    echo "!!! Keeping container alive so you can read this in Railway logs !!!"
    exec tail -f /dev/null
fi

# nginx in background so this script can watch x-ui.
nginx -g "daemon off; error_log /dev/stderr info;" &
NGINX_PID=$!
trap 'kill "$NGINX_PID" 2>/dev/null || true; exit 0' TERM INT

# Watchdog: if x-ui dies, exit so Railway restarts the container
# (otherwise nginx keeps it "healthy" while nothing works).
# Only armed if x-ui was actually seen running, so a wrong process name
# can never cause a restart loop.
SEEN=0; i=0
while [ "$i" -lt 20 ]; do
    if pidof x-ui >/dev/null 2>&1; then SEEN=1; break; fi
    sleep 3; i=$((i+1))
done

if [ "$SEEN" -eq 0 ]; then
    echo "watchdog: x-ui process not found, watchdog disabled"
    wait "$NGINX_PID"
    exit $?
fi

echo "watchdog: armed"
MISS=0
while kill -0 "$NGINX_PID" 2>/dev/null; do
    if pidof x-ui >/dev/null 2>&1; then MISS=0; else MISS=$((MISS+1)); fi
    if [ "$MISS" -ge 3 ]; then
        echo "watchdog: x-ui is gone, exiting so Railway restarts the container"
        kill "$NGINX_PID" 2>/dev/null || true
        exit 1
    fi
    sleep 10
done
echo "nginx exited, exiting"
exit 1
