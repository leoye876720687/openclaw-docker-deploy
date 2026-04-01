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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
ready=false
for _ in $(seq 1 24); do
    status=$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || true)
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$NAME" 2>/dev/null || true)

    if [ "$status" = "running" ] && { [ -z "$health" ] || [ "$health" = "healthy" ] || [ "$health" = "starting" ]; }; then
        ready=true
        break
    fi

    if [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
        echo "❌ Container exited during startup"
        docker logs "$NAME" --tail 80 2>&1 || true
        exit 1
    fi

    sleep 2
done

if [ "$ready" != "true" ]; then
    echo "❌ Container did not become ready in time"
    docker ps -a --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    docker logs "$NAME" --tail 80 2>&1 || true
    exit 1
fi

# Initialize container directories and configuration
echo ""
echo "📁 Initializing container configuration..."
if [ -f "$SCRIPT_DIR/init-agent-container.sh" ]; then
    bash "$SCRIPT_DIR/init-agent-container.sh" $NAME
else
    # Fallback: create directories manually
    echo "⚠️  init-agent-container.sh not found, using fallback..."
    docker exec -u root $NAME mkdir -p \
      /home/openclaw/.openclaw/.openclaw/agents/main/agent \
      /home/openclaw/.openclaw/.openclaw/agents/main/sessions
    docker exec -u root $NAME chown -R openclaw:openclaw \
      /home/openclaw/.openclaw/.openclaw/agents/main
fi

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

# Test directory structure
echo ""
echo "=== Directory Structure ==="
docker exec $NAME ls -la /home/openclaw/.openclaw/.openclaw/agents/main/ 2>/dev/null && echo "✅ Directory structure OK" || echo "⚠️  Directory structure may need manual setup"

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
