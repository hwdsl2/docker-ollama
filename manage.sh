#!/bin/bash
#
# https://github.com/hwdsl2/docker-ollama
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

OLLAMA_DATA="/var/lib/ollama"
API_KEY_FILE="${OLLAMA_DATA}/.api_key"
PORT_FILE="${OLLAMA_DATA}/.port"
SERVER_ADDR_FILE="${OLLAMA_DATA}/.server_addr"

exiterr() { echo "Error: $1" >&2; exit 1; }

show_usage() {
  local exit_code="${2:-1}"
  if [ -n "$1" ]; then
    echo "Error: $1" >&2
  fi
  cat 1>&2 <<'EOF'

Ollama Docker - Model Management
https://github.com/hwdsl2/docker-ollama

Usage: docker exec <container> ollama_manage [options]

Options:
  --listmodels             list downloaded models
  --pull   <model>         pull (download) a model
  --remove <model>         remove a downloaded model
  --status                 show currently running models and memory usage
  --update                 pull latest version of all downloaded models
  --showkey                show the API key and endpoint
  --getkey                 output the API key (machine-readable, no decoration)

  -h, --help               show this help message and exit

Examples:
  docker exec ollama ollama_manage --listmodels
  docker exec ollama ollama_manage --pull llama3.2:3b
  docker exec ollama ollama_manage --pull qwen2.5:7b
  docker exec ollama ollama_manage --remove llama3.2:3b
  docker exec ollama ollama_manage --status
  docker exec ollama ollama_manage --update
  docker exec ollama ollama_manage --showkey
  docker exec ollama ollama_manage --getkey

EOF
  exit "$exit_code"
}

check_container() {
  if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
    && [ -z "$KUBERNETES_SERVICE_HOST" ] \
    && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
    exiterr "This script must be run inside a container (e.g. Docker, Podman)."
  fi
}

load_config() {
  if [ -z "$OLLAMA_PORT" ]; then
    if [ -f "$PORT_FILE" ]; then
      OLLAMA_PORT=$(cat "$PORT_FILE")
    else
      OLLAMA_PORT=11434
    fi
  fi

  if [ -z "$OLLAMA_API_KEY" ]; then
    if [ -f "$API_KEY_FILE" ]; then
      OLLAMA_API_KEY=$(cat "$API_KEY_FILE")
    fi
  fi

  if [ -f "$SERVER_ADDR_FILE" ]; then
    SERVER_ADDR=$(cat "$SERVER_ADDR_FILE")
  else
    SERVER_ADDR="<server ip>"
  fi

  # ollama_manage communicates with ollama serve directly on localhost
  # (internal port, bypasses Caddy auth proxy)
  OLLAMA_BASE="http://127.0.0.1:41434"
  export OLLAMA_HOST="127.0.0.1:41434"
}

check_server() {
  if ! curl -sf "${OLLAMA_BASE}/" >/dev/null 2>&1; then
    exiterr "Ollama is not responding on port ${OLLAMA_PORT}. Is the container running?"
  fi
}

parse_args() {
  list_models=0
  pull_model=0
  remove_model=0
  show_status=0
  update_models=0
  show_key=0
  get_key=0

  model_arg=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --listmodels)
        list_models=1
        shift
        ;;
      --pull)
        pull_model=1
        model_arg="$2"
        shift; shift
        ;;
      --remove)
        remove_model=1
        model_arg="$2"
        shift; shift
        ;;
      --status)
        show_status=1
        shift
        ;;
      --update)
        update_models=1
        shift
        ;;
      --showkey)
        show_key=1
        shift
        ;;
      --getkey)
        get_key=1
        shift
        ;;
      -h|--help)
        show_usage "" 0
        ;;
      *)
        show_usage "Unknown parameter: $1"
        ;;
    esac
  done
}

check_args() {
  local action_count
  action_count=$((list_models + pull_model + remove_model + show_status + update_models + show_key + get_key))

  if [ "$action_count" -eq 0 ]; then
    show_usage
  fi
  if [ "$action_count" -gt 1 ]; then
    show_usage "Specify only one action at a time."
  fi

  if [ "$pull_model" = 1 ] && [ -z "$model_arg" ]; then
    exiterr "Missing model name. Usage: --pull <model>"
  fi

  if [ "$remove_model" = 1 ] && [ -z "$model_arg" ]; then
    exiterr "Missing model name. Usage: --remove <model>"
  fi
}

do_list_models() {
  echo
  echo "Downloaded models:"
  echo
  ollama list
  echo
  echo "Use '--pull <model>' to download a model, '--remove <model>' to delete one."
  echo
}

do_pull_model() {
  echo
  echo "Pulling model '${model_arg}'..."
  echo
  if ollama pull -- "$model_arg"; then
    echo
    echo "Model '${model_arg}' is ready."
  else
    exiterr "Failed to pull model '${model_arg}'."
  fi
  echo
}

do_remove_model() {
  echo
  echo "Removing model '${model_arg}'..."
  if ollama rm -- "$model_arg"; then
    echo "Model '${model_arg}' removed."
  else
    exiterr "Failed to remove model '${model_arg}'. Use '--listmodels' to see available models."
  fi
  echo
}

do_status() {
  echo
  echo "Running models:"
  echo
  ollama ps
  echo
  echo "Downloaded models:"
  echo
  ollama list
  echo
}

do_update() {
  echo
  echo "Updating all downloaded models..."
  echo

  # Get list of model names from 'ollama list' (skip header line)
  model_list=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

  if [ -z "$model_list" ]; then
    echo "No models downloaded. Use '--pull <model>' to download one."
    echo
    return
  fi

  updated=0
  failed=0
  while IFS= read -r _model; do
    [ -z "$_model" ] && continue
    echo "  Updating $_model ..."
    if ollama pull -- "$_model"; then
      updated=$((updated + 1))
    else
      echo "  Warning: failed to update '$_model'." >&2
      failed=$((failed + 1))
    fi
  done << EOF
$model_list
EOF

  echo
  echo "Update complete: ${updated} updated, ${failed} failed."
  echo
}

do_show_key() {
  echo
  if [ -z "$OLLAMA_API_KEY" ]; then
    echo "No API key found."
    echo
    return
  fi
  echo "==========================================================="
  echo " Ollama API key"
  echo "==========================================================="
  echo " ${OLLAMA_API_KEY}"
  echo "==========================================================="
  echo
  echo "API endpoint:  http://${SERVER_ADDR}:${OLLAMA_PORT}"
  echo
}

do_get_key() {
  if [ -z "$OLLAMA_API_KEY" ]; then
    exit 1
  fi
  printf '%s' "$OLLAMA_API_KEY"
}

check_container
load_config
parse_args "$@"
check_args

if [ "$show_key" = 1 ]; then
  do_show_key
  exit 0
fi

if [ "$get_key" = 1 ]; then
  do_get_key
  exit 0
fi

check_server

if [ "$list_models" = 1 ]; then
  do_list_models
  exit 0
fi

if [ "$pull_model" = 1 ]; then
  do_pull_model
  exit 0
fi

if [ "$remove_model" = 1 ]; then
  do_remove_model
  exit 0
fi

if [ "$show_status" = 1 ]; then
  do_status
  exit 0
fi

if [ "$update_models" = 1 ]; then
  do_update
  exit 0
fi