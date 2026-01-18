#!/bin/bash

APP_BUNDLE_ID="calebsideras.nativebar"
APP_NAME="nativebar"

show_help() {
    echo "Usage: ./logs.sh [option]"
    echo "  -s, --stream    Stream live logs"
    echo "  -r, --recent    Show recent logs (5 min)"
    echo "  -a, --all       Show today's logs" 
    echo "  -p, --process   Show process logs"
    echo "  -c, --console   Open Console.app"
}

stream_logs() {
    echo "Streaming logs (Ctrl+C to stop)..."
    /usr/bin/log stream \
        --predicate 'subsystem == "'$APP_BUNDLE_ID'" OR processImagePath ENDSWITH "'$APP_NAME'" OR process == "'$APP_NAME'"' \
        --info --debug
}

recent_logs() {
    /usr/bin/log show \
        --predicate 'subsystem == "'$APP_BUNDLE_ID'" OR processImagePath ENDSWITH "'$APP_NAME'" OR process == "'$APP_NAME'"' \
        --info --debug --last 5m
}

all_logs() {
    /usr/bin/log show \
        --predicate 'subsystem == "'$APP_BUNDLE_ID'" OR processImagePath ENDSWITH "'$APP_NAME'" OR process == "'$APP_NAME'"' \
        --info --debug \
        --start $(date -v0H -v0M -v0S "+%Y-%m-%d %H:%M:%S")
}

process_logs() {
    PID=$(pgrep -f "$APP_NAME" | head -1)
    if [ -n "$PID" ]; then
        echo "Found process: PID $PID"
        /usr/bin/log stream --process $PID --info --debug
    else
        echo "No running process found, showing recent logs..."
        /usr/bin/log show --predicate 'process == "'$APP_NAME'"' --info --debug --last 1h
    fi
}

open_console() {
    open /Applications/Utilities/Console.app
}

case "${1:-}" in
    --stream|-s) stream_logs ;;
    --recent|-r) recent_logs ;;
    --all|-a) all_logs ;;
    --process|-p) process_logs ;;
    --console|-c) open_console ;;
    --help|-h) show_help ;;
    "") recent_logs ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
esac