#!/bin/sh
set -eu

# Force the panel's own base path to match nginx's routing path,
# BEFORE the panel ever starts.
/app/x-ui setting -webBasePath /xp9k3panel/ >/dev/null 2>&1 || true

# Start the panel + Xray core using 3x-ui's own entrypoint, in the background.
/app/DockerEntrypoint.sh &

# Give x-ui a moment to bind its ports before nginx starts proxying to them.
sleep 3

# Railway injects PORT automatically; default to 8080 for local testing.
export PORT="${PORT:-8080}"

envsubst '${PORT}' < /etc/nginx/http.d/default.conf.template > /etc/nginx/http.d/default.conf

echo "=== Generated nginx config (/etc/nginx/http.d/default.conf) ==="
cat /etc/nginx/http.d/default.conf
echo "================================================================"

# Test the config BEFORE trying to run it. nginx's own error_log
# normally goes to a FILE, not stdout, so a bad config would otherwise
# fail completely silently in Railway's logs. This makes it visible.
if ! nginx -t; then
    echo "!!! NGINX CONFIG TEST FAILED (see errors above) !!!"
    echo "!!! Keeping container alive so you can read this in Railway logs !!!"
    # Don't exit -> avoids an infinite crash-loop that hides the error.
    exec tail -f /dev/null
fi

# Run nginx in the foreground. Force error_log to stderr so any runtime
# error (not just config-test errors) shows up in Railway's logs too.
exec nginx -g "daemon off; error_log /dev/stderr info;"
