#!/bin/bash

# OpenClaw Docker Deployment Example
# This script demonstrates the complete deployment workflow

set -e

echo "============================================"
echo "   🐳 OpenClaw Docker Deployment Example"
echo "============================================"
echo ""

# Configuration
API_KEY="${QWEN_API_KEY:-sk-your-api-key}"
BASE_PORT=18900

echo "This example will:"
echo "1. Deploy 3 isolated OpenClaw agents"
echo "2. Verify each deployment"
echo "3. Test conversation with each agent"
echo ""
echo "Configuration:"
echo "  API Key: ${API_KEY:0:10}..."
echo "  Base Port: $BASE_PORT"
echo ""

# Deploy agents
for i in 1 2 3; do
    NAME="openclaw-example-agent-$i"
    PORT=$((BASE_PORT + i))
    
    echo "============================================"
    echo "   Deploying Agent $i: $NAME (Port $PORT)"
    echo "============================================"
    
    # Check if exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
        echo "⚠️  Container exists, removing..."
        docker stop $NAME 2>/dev/null || true
        docker rm $NAME 2>/dev/null || true
    fi
    
    # Deploy
    docker run -d \
      --name $NAME \
      -p $PORT:18789 \
      -e QWEN_API_KEY=$API_KEY \
      -e NODE_OPTIONS=--max-old-space-size=2048 \
      docker-openclaw-openclaw
    
    # Wait
    echo "⏳ Waiting for startup..."
    sleep 8
    
    # Verify
    STATUS=$(docker ps --filter "name=$NAME" --format '{{.Status}}')
    echo "✅ Status: $STATUS"
    
    echo ""
done

# Summary
echo "============================================"
echo "   📊 Deployment Summary"
echo "============================================"
echo ""
docker ps -a --filter "name=openclaw-example" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Test conversation
echo "============================================"
echo "   💬 Conversation Test"
echo "============================================"
echo ""

for i in 1 2 3; do
    NAME="openclaw-example-agent-$i"
    echo "Testing $NAME..."
    RESPONSE=$(docker exec $NAME openclaw agent --session-id example-test --message "你好" --timeout 15 2>&1 | head -1)
    echo "  Response: ${RESPONSE:0:60}..."
    echo ""
done

echo "============================================"
echo "   ✅ Example Complete!"
echo "============================================"
echo ""
echo "To clean up:"
echo "  for i in 1 2 3; do docker stop openclaw-example-agent-\$i && docker rm openclaw-example-agent-\$i; done"
echo ""
