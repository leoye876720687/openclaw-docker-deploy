#!/bin/bash
set -e

# OpenClaw Docker Agent Verification Script
# Usage: ./verify-deployment.sh --name <name>

NAME=""

# Parse arguments
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

# Validate
if [ -z "$NAME" ]; then
    echo "❌ Error: Container name is required (--name)"
    exit 1
fi

echo "============================================"
echo "   🐳 OpenClaw Deployment Verification"
echo "============================================"
echo ""

# Check 1: Container status
echo "[1/5] Container Status:"
if docker ps --filter "name=$NAME" --format '{{.Status}}' | grep -q "healthy"; then
    echo "   ✅ Running (healthy)"
else
    STATUS=$(docker ps --filter "name=$NAME" --format '{{.Status}}' 2>/dev/null || echo "not found")
    if [ -z "$STATUS" ]; then
        echo "   ❌ Container not found"
        exit 1
    else
        echo "   ⚠️  Status: $STATUS"
    fi
fi

# Check 2: Port mapping
echo ""
echo "[2/5] Port Mapping:"
PORTS=$(docker port $NAME 2>/dev/null | head -1)
if [ -n "$PORTS" ]; then
    echo "   ✅ $PORTS"
else
    echo "   ❌ No port mapping found"
fi

# Check 3: Model configuration
echo ""
echo "[3/5] Model Configuration:"
MODEL_LOG=$(docker logs $NAME 2>&1 | grep "agent model" | tail -1)
if echo "$MODEL_LOG" | grep -q "aliyun-qwen"; then
    echo "   ✅ $MODEL_LOG"
elif echo "$MODEL_LOG" | grep -q "anthropic"; then
    echo "   ⚠️  Using Anthropic (may need configuration)"
    echo "   $MODEL_LOG"
else
    echo "   ⚠️  Model log not found"
    echo "   $MODEL_LOG"
fi

# Check 4: HTTP health
echo ""
echo "[4/5] HTTP Health Check:"
PORT=$(docker port $NAME 2>/dev/null | head -1 | awk '{print $3}' | cut -d':' -f2)
if [ -n "$PORT" ]; then
    HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null || echo "000")
    if [ "$HEALTH" = "200" ]; then
        echo "   ✅ HTTP 200 OK"
    else
        echo "   ⚠️  HTTP $HEALTH (may need more startup time)"
    fi
else
    echo "   ❌ Cannot determine port"
fi

# Check 5: Conversation test
echo ""
echo "[5/5] Conversation Test:"
RESPONSE=$(docker exec $NAME openclaw agent --session-id verify-test --message "只回复OK" --timeout 20 2>&1 | head -3)
if [ -n "$RESPONSE" ] && ! echo "$RESPONSE" | grep -qi "error\|failed\|timed out\|timeout"; then
    echo "   ✅ Response received"
    echo "   Preview: ${RESPONSE:0:50}..."
else
    echo "   ⚠️  Test failed or timed out"
    echo "   $RESPONSE"
fi

echo ""
echo "============================================"
echo "   Verification Complete!"
echo "============================================"
echo ""

# Summary
docker ps --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
