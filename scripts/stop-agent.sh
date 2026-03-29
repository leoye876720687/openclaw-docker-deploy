#!/bin/bash
set -e

# Stop OpenClaw agent
# Usage: ./stop-agent.sh --name <name>

NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NAME="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 --name <name> [-f]"
            echo ""
            echo "Options:"
            echo "  --name    Container name (required)"
            echo "  -f, --force  Force stop"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$NAME" ]; then
    echo "❌ Error: Container name is required (--name)"
    exit 1
fi

echo "Stopping container: $NAME"
if [ "$FORCE" = "true" ]; then
    docker kill $NAME
else
    docker stop $NAME
fi
echo "✅ Container stopped"
