#!/bin/bash
set -e

# OpenClaw Agent Container Initialization Script
# 初始化 Docker 容器内的 Agent 配置目录结构

CONTAINER_NAME="$1"
AUTH_PROFILES_SOURCE="${2:-$HOME/.openclaw/agents/main/agent/auth-profiles.json}"
MODELS_SOURCE="${3:-$HOME/.openclaw/agents/main/models.json}"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 <container-name> [auth-profiles-source] [models-source]"
    echo ""
    echo "Example:"
    echo "  $0 openclaw-agent-4"
    echo "  $0 openclaw-agent-4 ~/.openclaw/agents/data-expert/agent/auth-profiles.json"
    exit 1
fi

echo "============================================"
echo "   🐳 OpenClaw Container Initialization"
echo "============================================"
echo ""
echo "Container: $CONTAINER_NAME"
echo ""

# Check container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '$CONTAINER_NAME' is not running"
    exit 1
fi

echo "📁 Creating directory structure..."

# Create main agent directories
docker exec -u root $CONTAINER_NAME mkdir -p \
  /home/openclaw/.openclaw/.openclaw/agents/main/agent \
  /home/openclaw/.openclaw/.openclaw/agents/main/sessions

# Create default agent directories (for specialized agents)
docker exec -u root $CONTAINER_NAME mkdir -p \
  /home/openclaw/.openclaw/.openclaw/agents/default/agent \
  /home/openclaw/.openclaw/.openclaw/agents/default/sessions

echo "✅ Directory structure created"
echo ""

# Copy auth-profiles.json if source exists
if [ -f "$AUTH_PROFILES_SOURCE" ]; then
    echo "📋 Copying auth-profiles.json..."
    docker cp "$AUTH_PROFILES_SOURCE" $CONTAINER_NAME:/home/openclaw/.openclaw/.openclaw/agents/main/agent/auth-profiles.json
    docker cp "$AUTH_PROFILES_SOURCE" $CONTAINER_NAME:/home/openclaw/.openclaw/.openclaw/agents/default/agent/auth-profiles.json
    echo "✅ auth-profiles.json copied"
else
    echo "⚠️  auth-profiles.json source not found: $AUTH_PROFILES_SOURCE"
    echo "   You can copy it manually later:"
    echo "   docker cp <path-to-auth-profiles.json> $CONTAINER_NAME:/home/openclaw/.openclaw/.openclaw/agents/main/agent/auth-profiles.json"
fi
echo ""

# Copy models.json if source exists
if [ -f "$MODELS_SOURCE" ]; then
    echo "📋 Copying models.json..."
    docker cp "$MODELS_SOURCE" $CONTAINER_NAME:/home/openclaw/.openclaw/.openclaw/agents/main/models.json
    docker cp "$MODELS_SOURCE" $CONTAINER_NAME:/home/openclaw/.openclaw/.openclaw/agents/default/models.json
    echo "✅ models.json copied"
else
    echo "⚠️  models.json source not found: $MODELS_SOURCE"
fi
echo ""

# Set permissions
echo "🔐 Setting permissions..."
docker exec -u root $CONTAINER_NAME chown -R openclaw:openclaw \
  /home/openclaw/.openclaw/.openclaw/agents/main \
  /home/openclaw/.openclaw/.openclaw/agents/default
docker exec -u root $CONTAINER_NAME chmod 600 \
  /home/openclaw/.openclaw/.openclaw/agents/main/agent/auth-profiles.json \
  /home/openclaw/.openclaw/.openclaw/agents/default/agent/auth-profiles.json 2>/dev/null || true
echo "✅ Permissions set"
echo ""

# Set default model to Qwen (avoid Anthropic dependency)
echo "🤖 Setting default model to qwen-portal/coder-model..."
docker exec $CONTAINER_NAME openclaw config set agents.defaults.model qwen-portal/coder-model 2>&1 | grep -v "^Config overwrite" || true
echo "✅ Default model configured"
echo ""

# Verify
echo "=== Verification ==="
echo "Directory structure:"
docker exec $CONTAINER_NAME ls -la /home/openclaw/.openclaw/.openclaw/agents/main/ 2>/dev/null || echo "  (main agent not configured)"
echo ""
echo "Default model:"
docker exec $CONTAINER_NAME openclaw config get agents.defaults.model 2>/dev/null || echo "  (not configured)"
echo ""

echo "============================================"
echo "   ✅ Initialization Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Verify auth: docker exec $CONTAINER_NAME cat /home/openclaw/.openclaw/.openclaw/agents/main/agent/auth-profiles.json"
echo "  2. Test chat:   docker exec -it $CONTAINER_NAME openclaw agent --session-id test --message '你好'"
echo ""
