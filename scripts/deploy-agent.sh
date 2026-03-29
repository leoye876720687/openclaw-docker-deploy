#!/bin/bash
set -e

# OpenClaw Docker Agent Deployment Script
# Usage: ./deploy-agent.sh --name <name> --port <port> --api-key <key>

NAME="openclaw-agent"
PORT="18888"
API_KEY=""
MEMORY="2048"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --name <name> --port <port> --api-key <key> [--memory <mb>]"
            echo ""
            echo "Options:"
            echo "  --name    Container name (default: openclaw-agent)"
            echo "  --port    External port (default: 18888)"
            echo "  --api-key Qwen API Key (required)"
            echo "  --memory  Node.js memory limit in MB (default: 2048)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate
if [ -z "$API_KEY" ]; then
    echo "❌ Error: API Key is required (--api-key)"
    exit 1
fi

echo "============================================"
echo "   🐳 OpenClaw Agent Deployment"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Container Name: $NAME"
echo "  External Port:  $PORT"
echo "  Memory Limit:   ${MEMORY}MB"
echo ""

# Check if container exists
if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
    echo "⚠️  Warning: Container '$NAME' already exists"
    read -p "Do you want to remove it and create a new one? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping and removing existing container..."
        docker stop $NAME 2>/dev/null || true
        docker rm $NAME 2>/dev/null || true
    else
        echo "Aborted."
        exit 0
    fi
fi

# Deploy
echo "🚀 Deploying container..."
docker run -d \
  --name $NAME \
  -p $PORT:18789 \
  -e QWEN_API_KEY=$API_KEY \
  -e NODE_OPTIONS=--max-old-space-size=$MEMORY \
  docker-openclaw-openclaw

# Wait for startup
echo "⏳ Waiting for Gateway initialization..."
sleep 10

# Verify
echo ""
echo "=== Verification ==="
if docker ps --filter "name=$NAME" --format '{{.Status}}' | grep -q "healthy"; then
    echo "✅ Container is running (healthy)"
else
    echo "⚠️  Container status:"
    docker ps --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi

# Check model configuration
echo ""
echo "=== Model Configuration ==="
docker logs $NAME 2>&1 | grep "agent model" | tail -1

echo ""
echo "============================================"
echo "   ✅ Deployment Complete!"
echo "============================================"
echo ""
echo "Container: $NAME"
echo "Port:      $PORT"
echo ""
echo "Commands:"
echo "  Status:   docker ps --filter name=$NAME"
echo "  Logs:     docker logs -f $NAME"
echo "  Chat:     docker exec -it $NAME openclaw agent --session-id my-session --message '你好'"
echo "  Shell:    docker exec -it $NAME bash"
echo ""
