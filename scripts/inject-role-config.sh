#!/bin/bash
set -e

# Inject role configuration into running container
# Usage: ./inject-role-config.sh --container <name> --role <role>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$SCRIPT_DIR/../roles"

CONTAINER=""
ROLE=""

show_help() {
    echo "============================================"
    echo "   🔧 Role Configuration Injector"
    echo "============================================"
    echo ""
    echo "用法：$0 --container <name> --role <role>"
    echo ""
    echo "参数:"
    echo "  --container <name>  容器名称"
    echo "  --role <role>       角色名称"
    echo ""
    echo "可用角色:"
    ls -1 "$ROLES_DIR" 2>/dev/null | sed 's/.yml$//' | while read role; do
        echo "  - $role"
    done
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --container)
            CONTAINER="$2"
            shift 2
            ;;
        --role)
            ROLE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ 未知参数：$1"
            show_help
            exit 1
            ;;
    esac
done

if [ -z "$CONTAINER" ] || [ -z "$ROLE" ]; then
    echo "❌ 错误：必须指定容器和角色"
    show_help
    exit 1
fi

ROLE_FILE="$ROLES_DIR/${ROLE}.yml"
if [ ! -f "$ROLE_FILE" ]; then
    echo "❌ 错误：角色配置文件不存在：$ROLE_FILE"
    exit 1
fi

echo "============================================"
echo "   🔧 注入角色配置"
echo "============================================"
echo ""
echo "容器：$CONTAINER"
echo "角色：$ROLE"
echo "配置文件：$ROLE_FILE"
echo ""

# Check container
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "❌ 错误：容器不存在或未运行"
    docker ps -a --filter "name=$CONTAINER" --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

# Read role config
DISPLAY_NAME=$(grep "^display_name:" "$ROLE_FILE" | cut -d':' -f2 | tr -d ' ')
SYSTEM_PROMPT=$(grep -A100 "^system_prompt_prefix:" "$ROLE_FILE" | tail -n +2 | sed 's/^  //')

echo "📦 创建配置目录..."
docker exec $CONTAINER mkdir -p /home/openclaw/.openclaw/roles 2>/dev/null || true

echo "📄 复制角色配置..."
docker cp "$ROLE_FILE" "$CONTAINER:/home/openclaw/.openclaw/roles/active-role.yml"

if [ -n "$SYSTEM_PROMPT" ]; then
    echo "📝 注入系统提示词..."
    docker exec $CONTAINER bash -c "cat > /home/openclaw/.openclaw/system-prompt.txt << 'PROMPTEOF'
$SYSTEM_PROMPT
PROMPTEOF"
fi

echo "🔧 设置环境变量..."
docker exec $CONTAINER bash -c "cat >> /home/openclaw/.openclaw/.env << 'ENVEOF'
ROLE_NAME=$ROLE
ROLE_DISPLAY_NAME=$DISPLAY_NAME
ENVEOF" 2>/dev/null || true

echo ""
echo "✅ 配置注入完成！"
echo ""
echo "建议重启容器使配置生效:"
echo "  docker restart $CONTAINER"
echo ""
