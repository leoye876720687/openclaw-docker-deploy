#!/bin/bash
set -e

# Deploy specialized agents with role configurations
# Usage: ./deploy-specialized-agents.sh --role <role> --count <n> [--base-port <port>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$SCRIPT_DIR/../roles"

# Default values
ROLE=""
COUNT=1
BASE_PORT=19000
API_KEY="${QWEN_API_KEY:-}"
MEMORY=2048

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "============================================"
    echo "   🤖 Specialized Agent Deployment"
    echo "============================================"
    echo ""
    echo "用法：$0 --role <role> --count <n> [选项]"
    echo ""
    echo "必需参数:"
    echo "  --role <role>      角色名称 (data-analyst, coding-expert, devops-expert, decision-maker, qa-expert)"
    echo "  --count <n>        部署数量"
    echo ""
    echo "可选参数:"
    echo "  --base-port <port> 起始端口 (默认：19000)"
    echo "  --api-key <key>    API Key (默认：\$QWEN_API_KEY)"
    echo "  --memory <mb>      内存限制 (默认：2048)"
    echo ""
    echo "可用角色:"
    ls -1 "$ROLES_DIR" 2>/dev/null | sed 's/.yml$//' | while read role; do
        echo "  - $role"
    done
    echo ""
    echo "示例:"
    echo "  # 部署 3 个数据分析智能体"
    echo "  $0 --role data-analyst --count 3"
    echo ""
    echo "  # 部署 5 个编码专家 (从端口 19100 开始)"
    echo "  $0 --role coding-expert --count 5 --base-port 19100"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --role)
            ROLE="$2"
            shift 2
            ;;
        --count)
            COUNT="$2"
            shift 2
            ;;
        --base-port)
            BASE_PORT="$2"
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
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 未知参数：$1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate
if [ -z "$ROLE" ]; then
    echo -e "${RED}❌ 错误：必须指定角色 (--role)${NC}"
    show_help
    exit 1
fi

if [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ 错误：必须提供 API Key (--api-key 或设置 \$QWEN_API_KEY)${NC}"
    exit 1
fi

ROLE_FILE="$ROLES_DIR/${ROLE}.yml"
if [ ! -f "$ROLE_FILE" ]; then
    echo -e "${RED}❌ 错误：角色配置文件不存在：$ROLE_FILE${NC}"
    echo ""
    echo "可用角色:"
    ls -1 "$ROLES_DIR" 2>/dev/null | sed 's/.yml$//' | while read r; do
        echo "  - $r"
    done
    exit 1
fi

# Read role config
ROLE_NAME=$(grep "^name:" "$ROLE_FILE" | cut -d':' -f2 | tr -d ' ')
DISPLAY_NAME=$(grep "^display_name:" "$ROLE_FILE" | cut -d':' -f2 | tr -d ' ')

echo "============================================"
echo "   🤖 专业化智能体部署"
echo "============================================"
echo ""
echo "配置信息:"
echo "  角色：$ROLE ($DISPLAY_NAME)"
echo "  数量：$COUNT"
echo "  起始端口：$BASE_PORT"
echo "  内存限制：${MEMORY}MB"
echo ""

# Deploy agents
deployed=0
for i in $(seq 1 $COUNT); do
    CONTAINER_NAME="${ROLE}-${i}"
    PORT=$((BASE_PORT + i - 1))
    
    echo "-------------------------------------------"
    echo "[$i/$COUNT] 部署：$CONTAINER_NAME (端口 $PORT)"
    echo "-------------------------------------------"
    
    # Check if exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}⚠️  容器已存在${NC}"
        read -p "是否删除并重新创建？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "停止并删除旧容器..."
            docker stop $CONTAINER_NAME 2>/dev/null || true
            docker rm $CONTAINER_NAME 2>/dev/null || true
        else
            echo "跳过此容器"
            continue
        fi
    fi
    
    # Create config injection script
    CONFIG_SCRIPT="/tmp/config-${CONTAINER_NAME}.sh"
    cat > "$CONFIG_SCRIPT" << 'CONFIGEOF'
#!/bin/bash
# This script will be executed inside the container after startup
echo "🔧 Applying role configuration..."
CONFIGEOF
    
    # Deploy
    echo "🚀 创建容器..."
    docker run -d \
      --name $CONTAINER_NAME \
      -p $PORT:18789 \
      -e QWEN_API_KEY=$API_KEY \
      -e NODE_OPTIONS=--max-old-space-size=$MEMORY \
      -e ROLE_NAME=$ROLE \
      -e ROLE_DISPLAY_NAME="$DISPLAY_NAME" \
      docker-openclaw-openclaw
    
    # Wait for startup
    echo "⏳ 等待 Gateway 初始化..."
    sleep 10
    
    # Inject role configuration
    echo "📦 注入角色配置..."
    
    # Create role config inside container
    docker exec $CONTAINER_NAME mkdir -p /home/openclaw/.openclaw/roles 2>/dev/null || true
    docker cp "$ROLE_FILE" "$CONTAINER_NAME:/home/openclaw/.openclaw/roles/active-role.yml" 2>/dev/null || \
      echo "⚠️  角色配置注入失败（容器可能还在启动）"
    
    # Create system prompt override
    SYSTEM_PROMPT=$(grep -A100 "^system_prompt_prefix:" "$ROLE_FILE" | tail -n +2 | sed 's/^  //')
    if [ -n "$SYSTEM_PROMPT" ]; then
        docker exec $CONTAINER_NAME bash -c "cat > /home/openclaw/.openclaw/system-prompt.txt << 'PROMPTEOF'
$SYSTEM_PROMPT
PROMPTEOF" 2>/dev/null || true
    fi
    
    # Verify
    STATUS=$(docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' 2>/dev/null || echo "not found")
    if echo "$STATUS" | grep -q "healthy"; then
        echo -e "${GREEN}✅ 部署成功${NC}"
        ((deployed++))
    else
        echo -e "${YELLOW}⚠️  容器状态：$STATUS${NC}"
    fi
    
    echo ""
done

# Summary
echo "============================================"
echo "   📊 部署完成"
echo "============================================"
echo ""
echo "成功部署：$deployed / $COUNT"
echo ""
echo "运行中的容器:"
docker ps --filter "name=${ROLE}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Generate usage commands
echo "============================================"
echo "   💡 使用示例"
echo "============================================"
echo ""
for i in $(seq 1 $deployed); do
    CONTAINER_NAME="${ROLE}-${i}"
    PORT=$((BASE_PORT + i - 1))
    echo "# 与 $CONTAINER_NAME 对话"
    echo "docker exec -it $CONTAINER_NAME openclaw agent --session-id chat --message '你好'"
    echo ""
done

echo "# 或使用 router 脚本"
echo "cd $SCRIPT_DIR"
echo "./router.sh -c ${ROLE}-1 \"你好\""
echo ""
