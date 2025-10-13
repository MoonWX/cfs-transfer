#!/bin/bash

# CFS Transfer Tool - Quick Deploy Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_usage() {
    cat << EOF
Usage: $0 [target|source] [action]

Actions:
  setup   - Copy .env.example to .env for editing
  start   - Start the service
  stop    - Stop the service
  restart - Restart the service
  logs    - Show logs
  status  - Show status

Examples:
  $0 target setup    # Setup target server
  $0 source start    # Start source server
  $0 target logs     # View target logs
EOF
}

if [ $# -lt 2 ]; then
    print_usage
    exit 1
fi

ROLE=$1
ACTION=$2

if [ "$ROLE" != "target" ] && [ "$ROLE" != "source" ]; then
    echo "Error: Role must be 'target' or 'source'"
    print_usage
    exit 1
fi

cd "$SCRIPT_DIR/$ROLE"

case $ACTION in
    setup)
        if [ ! -f .env ]; then
            cp .env.example .env
            echo "✓ Created .env file in $ROLE directory"
            echo "→ Please edit $ROLE/.env with your configuration"
            echo "→ Then run: $0 $ROLE start"
        else
            echo "! .env file already exists in $ROLE directory"
        fi
        ;;
    
    start)
        if [ ! -f .env ]; then
            echo "Error: .env file not found. Run '$0 $ROLE setup' first"
            exit 1
        fi
        echo "Starting $ROLE service..."
        docker-compose up -d --build
        echo "✓ $ROLE service started"
        echo "→ View logs: $0 $ROLE logs"
        ;;
    
    stop)
        echo "Stopping $ROLE service..."
        docker-compose down
        echo "✓ $ROLE service stopped"
        ;;
    
    restart)
        echo "Restarting $ROLE service..."
        docker-compose restart
        echo "✓ $ROLE service restarted"
        ;;
    
    logs)
        docker-compose logs -f
        ;;
    
    status)
        docker-compose ps
        if [ "$ROLE" = "source" ]; then
            echo ""
            echo "=== Sync Logs (last 20 lines) ==="
            docker-compose exec rsync-source tail -20 /var/log/rsync.log 2>/dev/null || echo "Service not running"
        elif [ "$ROLE" = "target" ]; then
            echo ""
            echo "=== Rsync Daemon Logs (last 20 lines) ==="
            docker-compose exec rsync-target tail -20 /var/log/rsyncd.log 2>/dev/null || echo "Service not running"
        fi
        ;;
    
    *)
        echo "Error: Unknown action '$ACTION'"
        print_usage
        exit 1
        ;;
esac
