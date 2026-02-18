#!/bin/sh
set -eu

js_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g'
}

google_client_id="${GOOGLE_CLIENT_ID:-${VITE_GOOGLE_CLIENT_ID:-}}"
google_oauth_redirect_uri="${GOOGLE_OAUTH_REDIRECT_URI:-${VITE_GOOGLE_OAUTH_REDIRECT_URI:-}}"
google_calendar_id="${GOOGLE_CALENDAR_ID:-${VITE_GOOGLE_CALENDAR_ID:-}}"

cat > /usr/share/nginx/html/env-config.js <<EOF
window.__PLANNER_ENV__ = {
  VITE_GOOGLE_CLIENT_ID: "$(js_escape "$google_client_id")",
  VITE_GOOGLE_OAUTH_REDIRECT_URI: "$(js_escape "$google_oauth_redirect_uri")",
  VITE_GOOGLE_CALENDAR_ID: "$(js_escape "$google_calendar_id")",
  GOOGLE_CLIENT_ID: "$(js_escape "$google_client_id")",
  GOOGLE_OAUTH_REDIRECT_URI: "$(js_escape "$google_oauth_redirect_uri")",
  GOOGLE_CALENDAR_ID: "$(js_escape "$google_calendar_id")"
};
EOF
