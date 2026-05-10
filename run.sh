#!/bin/bash
#
# Docker script to configure and start an Ollama LLM server
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC! THIS IS ONLY MEANT TO BE RUN
# IN A CONTAINER!
#
# This file is part of Ollama Docker image, available at:
# https://github.com/hwdsl2/docker-ollama
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

check_port() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^[0-9]+$' \
  && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

check_dns_name() {
  FQDN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$FQDN_REGEX"
}

# Source bind-mounted env file if present (takes precedence over --env-file)
if [ -f /ollama.env ]; then
  # shellcheck disable=SC1091
  . /ollama.env
fi

if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
  && [ -z "$KUBERNETES_SERVICE_HOST" ] \
  && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
  exiterr "This script ONLY runs in a container (e.g. Docker, Podman)."
fi

# Read and sanitize environment variables
OLLAMA_API_KEY=$(nospaces "$OLLAMA_API_KEY")
OLLAMA_API_KEY=$(noquotes "$OLLAMA_API_KEY")
OLLAMA_PORT=$(nospaces "$OLLAMA_PORT")
OLLAMA_PORT=$(noquotes "$OLLAMA_PORT")
OLLAMA_HOST=$(nospaces "$OLLAMA_HOST")
OLLAMA_HOST=$(noquotes "$OLLAMA_HOST")
OLLAMA_MODELS_PULL=$(nospaces "$OLLAMA_MODELS")
OLLAMA_MODELS_PULL=$(noquotes "$OLLAMA_MODELS_PULL")
OLLAMA_MAX_LOADED_MODELS=$(nospaces "$OLLAMA_MAX_LOADED_MODELS")
OLLAMA_MAX_LOADED_MODELS=$(noquotes "$OLLAMA_MAX_LOADED_MODELS")
OLLAMA_NUM_PARALLEL=$(nospaces "$OLLAMA_NUM_PARALLEL")
OLLAMA_NUM_PARALLEL=$(noquotes "$OLLAMA_NUM_PARALLEL")
OLLAMA_CONTEXT_LENGTH=$(nospaces "$OLLAMA_CONTEXT_LENGTH")
OLLAMA_CONTEXT_LENGTH=$(noquotes "$OLLAMA_CONTEXT_LENGTH")

# Apply defaults
[ -z "$OLLAMA_PORT" ] && OLLAMA_PORT=11434

# Internal port for Ollama (Caddy proxies the user-facing port to this)
OLLAMA_INTERNAL_PORT=41434

# Validate port
if ! check_port "$OLLAMA_PORT"; then
  exiterr "OLLAMA_PORT must be an integer between 1 and 65535."
fi

if [ "$OLLAMA_PORT" = "$OLLAMA_INTERNAL_PORT" ]; then
  exiterr "Port $OLLAMA_INTERNAL_PORT is reserved for internal use. Please choose a different OLLAMA_PORT."
fi

# Validate server hostname/IP
if [ -n "$OLLAMA_HOST" ]; then
  if ! check_dns_name "$OLLAMA_HOST" && ! check_ip "$OLLAMA_HOST"; then
    exiterr "OLLAMA_HOST '$OLLAMA_HOST' is not a valid hostname or IP address."
  fi
fi

# Validate optional tuning integers
for _var in OLLAMA_MAX_LOADED_MODELS OLLAMA_NUM_PARALLEL OLLAMA_CONTEXT_LENGTH; do
  _val=$(eval "printf '%s' \"\$$_var\"")
  if [ -n "$_val" ]; then
    printf '%s' "$_val" | grep -Eq '^[0-9]+$' \
      || exiterr "$_var must be a positive integer."
  fi
done

# Ensure data directory exists
mkdir -p /var/lib/ollama
chmod 700 /var/lib/ollama

API_KEY_FILE="/var/lib/ollama/.api_key"
PORT_FILE="/var/lib/ollama/.port"
SERVER_ADDR_FILE="/var/lib/ollama/.server_addr"
INITIALIZED_MARKER="/var/lib/ollama/.initialized"

# Generate or load API key
if [ -n "$OLLAMA_API_KEY" ]; then
  api_key="$OLLAMA_API_KEY"
  printf '%s' "$api_key" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
else
  if [ -f "$API_KEY_FILE" ]; then
    api_key=$(cat "$API_KEY_FILE")
  else
    api_key="ollama-$(head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n' | head -c 48)"
    printf '%s' "$api_key" > "$API_KEY_FILE"
    chmod 600 "$API_KEY_FILE"
  fi
fi

# Save port for use by ollama_manage
printf '%s' "$OLLAMA_PORT" > "$PORT_FILE"

# Determine server address for display
if [ -n "$OLLAMA_HOST" ]; then
  server_addr="$OLLAMA_HOST"
else
  public_ip=$(curl -sf --max-time 10 http://ipv4.icanhazip.com 2>/dev/null)
  check_ip "$public_ip" || public_ip=$(curl -sf --max-time 10 http://ip1.dynupdate.no-ip.com 2>/dev/null)
  if check_ip "$public_ip"; then
    server_addr="$public_ip"
  else
    server_addr="<server ip>"
  fi
fi
printf '%s' "$server_addr" > "$SERVER_ADDR_FILE"

echo
echo "Ollama Docker - https://github.com/hwdsl2/docker-ollama"

if ! grep -q " /var/lib/ollama " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /var/lib/ollama is not mounted. Model data and the API key"
  echo "      will be lost on container removal."
  echo "      Mount a Docker volume at /var/lib/ollama to persist data."
fi

# Detect first run
first_run=false
[ ! -f "$INITIALIZED_MARKER" ] && first_run=true

if $first_run; then
  echo
  echo "Starting Ollama first-run setup..."
  echo "Port: $OLLAMA_PORT"
  echo
fi

# Build Ollama environment
# Note: OLLAMA_HOST is Ollama's env var for the bind address of ollama serve.
# We save the user-set OLLAMA_HOST (display hostname) to server_addr above, then
# overwrite OLLAMA_HOST here so ollama serve and the ollama CLI both use localhost.
export OLLAMA_HOST="127.0.0.1:${OLLAMA_INTERNAL_PORT}"
export OLLAMA_MODELS="/var/lib/ollama/models"

[ -n "$OLLAMA_MAX_LOADED_MODELS" ] && export OLLAMA_MAX_LOADED_MODELS
[ -n "$OLLAMA_NUM_PARALLEL" ]      && export OLLAMA_NUM_PARALLEL
[ -n "$OLLAMA_CONTEXT_LENGTH" ]    && export OLLAMA_CONTEXT_LENGTH

# Enable Ollama debug logging if requested
[ -n "$OLLAMA_DEBUG" ] && export OLLAMA_DEBUG

# Graceful shutdown handler
cleanup() {
  echo
  echo "Stopping Ollama..."
  kill "${CADDY_PID:-}" 2>/dev/null
  kill "${OLLAMA_PID:-}" 2>/dev/null
  wait "${CADDY_PID:-}" 2>/dev/null
  wait "${OLLAMA_PID:-}" 2>/dev/null
  exit 0
}
trap cleanup INT TERM

# Start ollama serve (always bound to localhost)
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to become ready (up to 30 seconds)
wait_for_ollama() {
  local i=0
  while [ "$i" -lt 30 ]; do
    if ! kill -0 "$OLLAMA_PID" 2>/dev/null; then
      return 1
    fi
    if curl -sf "http://127.0.0.1:${OLLAMA_INTERNAL_PORT}/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

echo "Starting Ollama server..."
if ! wait_for_ollama; then
  if ! kill -0 "$OLLAMA_PID" 2>/dev/null; then
    exiterr "Ollama failed to start. Check the container logs for details."
  else
    exiterr "Ollama did not become ready after 30 seconds."
  fi
fi

# First-run: pull requested models
if $first_run && [ -n "$OLLAMA_MODELS_PULL" ]; then
  echo "Pulling models: $OLLAMA_MODELS_PULL"
  # Split comma-separated list
  _IFS_ORIG="$IFS"
  IFS=','
  for _model in $OLLAMA_MODELS_PULL; do
    IFS="$_IFS_ORIG"
    _model=$(printf '%s' "$_model" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$_model" ] && continue
    echo "  Pulling $_model ..."
    if ! ollama pull "$_model"; then
      echo "  Warning: failed to pull '$_model'. You can retry with:" >&2
      echo "    docker exec <container> ollama_manage --pull $_model" >&2
    fi
    IFS=','
  done
  IFS="$_IFS_ORIG"
fi

if $first_run; then
  touch "$INITIALIZED_MARKER"
fi

# Start Caddy auth proxy (always enabled)
CADDY_CONFIG_FILE="/var/lib/ollama/.Caddyfile"
cat > "$CADDY_CONFIG_FILE" << CADDYEOF
:${OLLAMA_PORT} {
  @unauthed {
    not header Authorization "Bearer ${api_key}"
    not path /
  }
  respond @unauthed "Unauthorized" 401
  reverse_proxy 127.0.0.1:${OLLAMA_INTERNAL_PORT} {
    header_up Host 127.0.0.1:${OLLAMA_INTERNAL_PORT}
  }
}
CADDYEOF
caddy fmt --overwrite "$CADDY_CONFIG_FILE" 2>/dev/null || true
caddy run --config "$CADDY_CONFIG_FILE" --adapter caddyfile &
CADDY_PID=$!
# Wait up to 5 seconds for Caddy to start
_i=0
while [ "$_i" -lt 5 ]; do
  kill -0 "$CADDY_PID" 2>/dev/null || break
  curl -sf --max-time 1 "http://127.0.0.1:${OLLAMA_PORT}/" >/dev/null 2>&1 && break
  sleep 1
  _i=$((_i + 1))
done
if ! kill -0 "$CADDY_PID" 2>/dev/null; then
  exiterr "Caddy auth proxy failed to start."
fi

# Copy API key to shared volume if mounted (used by docker-ai-stack)
if grep -q " /var/lib/ollama-shared " /proc/mounts 2>/dev/null; then
  cp "$API_KEY_FILE" /var/lib/ollama-shared/.api_key
  chmod 600 /var/lib/ollama-shared/.api_key
fi

# Display connection info
echo
echo "==========================================================="
echo " Ollama API key"
echo "==========================================================="
echo " ${api_key}"
echo "==========================================================="
echo
echo "API endpoint: http://${server_addr}:${OLLAMA_PORT}"
echo
echo "Test with:"
echo "  curl http://localhost:${OLLAMA_PORT}/api/tags \\"
echo "    -H \"Authorization: Bearer ${api_key}\""
echo
echo "Manage models: docker exec <container> ollama_manage --help"
echo
echo "Setup complete."
echo

# Wait for main process
wait "$OLLAMA_PID"