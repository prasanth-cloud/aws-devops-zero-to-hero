#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

MODE="${1:-docker}"
PORT="${PORT:-8000}"
HEALTH_URL="http://127.0.0.1:${PORT}/api/analytics/summary"

wait_for_health() {
  local retries=30
  local sleep_s=1
  for _ in $(seq 1 "$retries"); do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      echo "✅ App is healthy at http://127.0.0.1:${PORT}"
      return 0
    fi
    sleep "$sleep_s"
  done
  echo "❌ App did not become healthy at ${HEALTH_URL}" >&2
  return 1
}

case "$MODE" in
  docker)
    if ! command -v docker >/dev/null 2>&1; then
      echo "❌ Docker is not installed. Use: ./deploy.sh local" >&2
      exit 1
    fi
    echo "Starting app with Docker Compose..."
    docker compose up --build -d
    wait_for_health
    ;;
  local)
    echo "Starting app in local background mode..."
    nohup python -m src.main >/tmp/swing-trading-app.log 2>&1 &
    echo $! > /tmp/swing-trading-app.pid
    wait_for_health
    echo "Logs: /tmp/swing-trading-app.log"
    ;;
  stop)
    if command -v docker >/dev/null 2>&1; then
      docker compose down || true
    fi
    if [[ -f /tmp/swing-trading-app.pid ]]; then
      kill "$(cat /tmp/swing-trading-app.pid)" || true
      rm -f /tmp/swing-trading-app.pid
    fi
    echo "Stopped app (docker and local modes)."
    ;;
  *)
    echo "Usage: ./deploy.sh [docker|local|stop]"
    exit 1
    ;;
esac
