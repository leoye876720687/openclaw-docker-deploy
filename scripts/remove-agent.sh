#!/bin/bash
set -e

# Remove OpenClaw agent
# Usage: ./remove-agent.sh --name <name>

NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --name <name>"
            echo ""
            echo "Options:"
            echo "  --name    Container name (required)"
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

echo "⚠️  Warning: This will permanently remove container '$NAME'"
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Stopping container..."
docker stop $NAME 2>/dev/null || true

echo "Removing container..."
docker rm $NAME

echo "✅ Container removed"
