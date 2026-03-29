#!/bin/bash
set -e

# OpenClaw Docker Container Router
# 路由请求到不同的容器化智能体

# 容器列表
CONTAINERS=("openclaw-agent-1" "openclaw-agent-2" "openclaw-agent-3")
PORTS=(18891 18892 18893)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助
show_help() {
    echo "============================================"
    echo "   🐳 OpenClaw Docker Router"
    echo "============================================"
    echo ""
    echo "用法：$0 [选项] <消息>"
    echo ""
    echo "选项:"
    echo "  -c, --container <name>   指定容器 (openclaw-agent-1/2/3)"
    echo "  -p, --port <port>        指定端口 (18891/18892/18893)"
    echo "  -a, --auto               自动选择（轮询）"
    echo "  -l, --list               列出所有可用容器"
    echo "  -s, --status             显示所有容器状态"
    echo "  -r, --round-robin        轮询模式（自动切换容器）"
    echo "  -h, --help               显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 -c openclaw-agent-1 \"你好\""
    echo "  $0 -p 18892 \"帮我分析数据\""
    echo "  $0 -a \"今天天气怎么样\""
    echo "  $0 -l"
    echo ""
}

# 列出容器
list_containers() {
    echo "============================================"
    echo "   📋 可用容器列表"
    echo "============================================"
    echo ""
    docker ps --filter "name=openclaw-agent" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    echo "❌ 未找到运行中的容器"
    echo ""
}

# 显示状态
show_status() {
    echo "============================================"
    echo "   📊 容器状态"
    echo "============================================"
    echo ""
    
    for i in "${!CONTAINERS[@]}"; do
        container=${CONTAINERS[$i]}
        port=${PORTS[$i]}
        
        status=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null || echo "not found")
        health=$(docker inspect -f '{{.State.Health.Status}}' $container 2>/dev/null || echo "N/A")
        
        if [ "$status" = "running" ]; then
            echo -e "${GREEN}●${NC} $container (端口 $port)"
            echo "   状态：$status | 健康：$health"
        else
            echo -e "${RED}●${NC} $container (端口 $port)"
            echo "   状态：$status"
        fi
    done
    echo ""
}

# 发送消息到容器
send_message() {
    local container=$1
    local message=$2
    local session_id=${3:-"router-session-$(date +%s)"}
    
    echo -e "${BLUE}📤 发送到：$container${NC}"
    echo -e "${YELLOW}消息：$message${NC}"
    echo ""
    
    # 检查容器是否存在
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}❌ 错误：容器 '$container' 不存在或未运行${NC}"
        echo ""
        echo "可用容器:"
        list_containers
        exit 1
    fi
    
    # 发送消息
    echo -e "${GREEN}💬 对话内容:${NC}"
    echo "-------------------------------------------"
    docker exec $container openclaw agent --session-id $session_id --message "$message" --timeout 30 2>&1
    echo "-------------------------------------------"
    echo ""
}

# 获取下一个容器（轮询）
get_next_container() {
    local state_file="/tmp/openclaw-router-state.json"
    local next=0
    
    if [ -f "$state_file" ]; then
        next=$(cat "$state_file" 2>/dev/null || echo "0")
    fi
    
    # 计算下一个容器索引
    next=$(( (next + 1) % ${#CONTAINERS[@]} ))
    
    # 保存状态
    echo $next > "$state_file"
    
    echo ${CONTAINERS[$next]}
}

# 主逻辑
main() {
    local container=""
    local port=""
    local auto=false
    local list=false
    local status=false
    local round_robin=false
    local message=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--container)
                container="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -a|--auto)
                auto=true
                shift
                ;;
            -l|--list)
                list=true
                shift
                ;;
            -s|--status)
                status=true
                shift
                ;;
            -r|--round-robin)
                round_robin=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                message="$1"
                shift
                ;;
        esac
    done
    
    # 执行操作
    if [ "$list" = true ]; then
        list_containers
        exit 0
    fi
    
    if [ "$status" = true ]; then
        show_status
        exit 0
    fi
    
    if [ "$round_robin" = true ]; then
        if [ -z "$message" ]; then
            echo -e "${RED}❌ 错误：轮询模式需要提供消息${NC}"
            show_help
            exit 1
        fi
        container=$(get_next_container)
        echo -e "${BLUE}🔄 轮询模式：选择容器 $container${NC}"
        send_message "$container" "$message"
        exit 0
    fi
    
    if [ "$auto" = true ]; then
        if [ -z "$message" ]; then
            echo -e "${RED}❌ 错误：自动模式需要提供消息${NC}"
            show_help
            exit 1
        fi
        # 选择第一个健康容器
        for c in "${CONTAINERS[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
                container=$c
                break
            fi
        done
        if [ -z "$container" ]; then
            echo -e "${RED}❌ 错误：没有可用的容器${NC}"
            exit 1
        fi
        echo -e "${BLUE}🤖 自动模式：选择容器 $container${NC}"
        send_message "$container" "$message"
        exit 0
    fi
    
    if [ -n "$container" ]; then
        if [ -z "$message" ]; then
            echo -e "${RED}❌ 错误：需要提供消息${NC}"
            show_help
            exit 1
        fi
        send_message "$container" "$message"
        exit 0
    fi
    
    if [ -n "$port" ]; then
        if [ -z "$message" ]; then
            echo -e "${RED}❌ 错误：需要提供消息${NC}"
            show_help
            exit 1
        fi
        # 根据端口查找容器
        for i in "${!PORTS[@]}"; do
            if [ "${PORTS[$i]}" = "$port" ]; then
                container=${CONTAINERS[$i]}
                break
            fi
        done
        if [ -z "$container" ]; then
            echo -e "${RED}❌ 错误：端口 $port 没有对应的容器${NC}"
            exit 1
        fi
        send_message "$container" "$message"
        exit 0
    fi
    
    # 默认显示帮助
    show_help
}

main "$@"
