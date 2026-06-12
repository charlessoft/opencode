#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTNAME="${OPENCODE_WEB_HOSTNAME:-0.0.0.0}"
PORT="${OPENCODE_WEB_PORT:-4090}"
RUNTIME_DIR="${OPENCODE_WEB_RUNTIME_DIR:-${TMPDIR:-/tmp}/opencode-web-$(id -u)}"
PID_FILE="$RUNTIME_DIR/opencode-web.pid"
LOG_FILE="$RUNTIME_DIR/opencode-web.log"

usage() {
    cat <<EOF2
OpenCode web background helper

Usage:
    ./script/web-bg.sh <start|stop|restart|status|logs>

Environment:
    OPENCODE_WEB_HOSTNAME      Host to bind (default: 0.0.0.0)
    OPENCODE_WEB_PORT          Port to bind (default: 4090)
    OPENCODE_WEB_RUNTIME_DIR   Runtime dir for pid/log files
    OPENCODE_WEB_EXECUTABLE    Explicit built opencode binary path
EOF2
}

ensure_runtime_dir() {
    mkdir -p "$RUNTIME_DIR"
}

resolve_executable() {
    if [[ -n "${OPENCODE_WEB_EXECUTABLE:-}" ]]; then
        if [[ -x "$OPENCODE_WEB_EXECUTABLE" ]]; then
            printf '%s\n' "$OPENCODE_WEB_EXECUTABLE"
            return 0
        fi
        echo "configured OPENCODE_WEB_EXECUTABLE is not executable: $OPENCODE_WEB_EXECUTABLE" >&2
        return 1
    fi

    local match
    match="$(find "$ROOT_DIR/packages/opencode/dist" -path '*/bin/opencode' -type f -print -quit 2>/dev/null || true)"
    if [[ -n "$match" && -x "$match" ]]; then
        printf '%s\n' "$match"
        return 0
    fi

    return 1
}

is_running() {
    if [[ ! -f "$PID_FILE" ]]; then
        return 1
    fi

    local pid
    pid="$(cat "$PID_FILE")"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

cleanup_stale_pid() {
    if [[ -f "$PID_FILE" ]] && ! is_running; then
        rm -f "$PID_FILE"
    fi
}

start() {
    ensure_runtime_dir
    cleanup_stale_pid

    if is_running; then
        echo "opencode web is already running (pid $(cat "$PID_FILE"))"
        echo "log: $LOG_FILE"
        return 0
    fi

    local executable
    if ! executable="$(resolve_executable)"; then
        echo "built opencode binary not found"
        echo "run: bun run --cwd packages/opencode build --single --skip-install"
        return 1
    fi

    local original_dir
    original_dir="$(pwd)"
    cd "$ROOT_DIR"
    nohup "$executable" web --hostname "$HOSTNAME" --port "$PORT" >>"$LOG_FILE" 2>&1 < /dev/null &
    local pid=$!
    cd "$original_dir"

    echo "$pid" >"$PID_FILE"
    sleep 1

    if kill -0 "$pid" 2>/dev/null; then
        echo "started opencode web"
        echo "pid: $pid"
        echo "url: http://$HOSTNAME:$PORT"
        echo "binary: $executable"
        echo "log: $LOG_FILE"
        return 0
    fi

    echo "failed to start opencode web"
    echo "binary: $executable"
    echo "log: $LOG_FILE"
    rm -f "$PID_FILE"
    return 1
}

stop() {
    cleanup_stale_pid

    if ! is_running; then
        echo "opencode web is not running"
        return 0
    fi

    local pid
    pid="$(cat "$PID_FILE")"
    kill "$pid"

    for _ in {1..20}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            echo "stopped opencode web"
            return 0
        fi
        sleep 0.5
    done

    echo "process did not exit after 10s, sending SIGKILL"
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "stopped opencode web"
}

status() {
    cleanup_stale_pid

    if is_running; then
        echo "opencode web is running"
        echo "pid: $(cat "$PID_FILE")"
        echo "url: http://$HOSTNAME:$PORT"
        echo "log: $LOG_FILE"
        return 0
    fi

    echo "opencode web is not running"
    echo "log: $LOG_FILE"
    return 1
}

logs() {
    ensure_runtime_dir
    touch "$LOG_FILE"
    tail -f "$LOG_FILE"
}

command="${1:-}"

case "$command" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        echo "unknown command: $command" >&2
        usage
        exit 1
        ;;
esac
