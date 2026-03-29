# 专业化智能体部署指南

## 📖 概述

本系统支持基于**角色配置**批量部署专业化智能体。每个角色预定义了：
- 核心能力 (capabilities)
- 技能包 (skills)
- 行为配置 (behavior)
- 系统提示词 (system prompt)
- 工具偏好 (tools)

## 🎯 可用角色

| 角色 | 描述 | 适用场景 |
|------|------|----------|
| `data-analyst` | 数据分析专家 | 数据处理、统计分析、可视化 |
| `coding-expert` | 编码专家 | 全栈开发、代码审查、Debug |
| `devops-expert` | 运维专家 | 部署、监控、故障排查 |
| `decision-maker` | 决策专家 | 战略分析、方案评估 |
| `qa-expert` | 验证专家 | 测试设计、质量审查 |

## 🚀 快速开始

### 方式 1: 批量部署专业化智能体

```bash
cd /home/leoye/.openclaw/workspace/skills/openclaw-docker-deploy

# 部署 3 个数据分析智能体
./scripts/deploy-specialized-agents.sh \
  --role data-analyst \
  --count 3 \
  --base-port 19000

# 部署 5 个编码专家
./scripts/deploy-specialized-agents.sh \
  --role coding-expert \
  --count 5 \
  --base-port 19100
```

### 方式 2: 为现有容器注入角色

```bash
# 为运行中的容器注入角色配置
./scripts/inject-role-config.sh \
  --container openclaw-agent-1 \
  --role data-analyst

# 重启容器使配置生效
docker restart openclaw-agent-1
```

## 📋 角色配置文件结构

```yaml
# roles/data-analyst.yml
name: data-analyst
display_name: 数据分析专家

# 核心能力
capabilities:
  - data_processing
  - statistical_analysis
  - data_visualization

# 技能包
skills:
  - name: pandas-expert
    enabled: true
    config:
      prefer_python: true

# 行为配置
behavior:
  tone: professional
  detail_level: high
  show_reasoning: true

# 系统提示词
system_prompt_prefix: |
  你是一位资深数据分析专家...

# 环境变量
environment:
  PYTHON_LIBRARIES: "pandas,numpy,matplotlib"
```

## 💡 使用示例

### 示例 1: 创建数据分析团队

```bash
# 部署 3 个数据分析智能体（端口 19001-19003）
./deploy-specialized-agents.sh --role data-analyst --count 3 --base-port 19000

# 与第一个数据分析智能体对话
docker exec -it data-analyst-1 openclaw agent --session-id analysis-001 --message "帮我分析这个销售数据集"
```

### 示例 2: 创建全栈开发团队

```bash
# 部署 5 个编码专家（端口 19101-19105）
./deploy-specialized-agents.sh --role coding-expert --count 5 --base-port 19100

# 使用 router 轮询模式分发任务
./router.sh -r "审查这段代码的安全性"
```

### 示例 3: 混合部署

```bash
# 决策专家 (1 个)
./deploy-specialized-agents.sh --role decision-maker --count 1 --base-port 19200

# 编码专家 (3 个)
./deploy-specialized-agents.sh --role coding-expert --count 3 --base-port 19300

# QA 专家 (2 个)
./deploy-specialized-agents.sh --role qa-expert --count 2 --base-port 19400
```

## 🔧 自定义角色

### 创建新角色

1. 在 `roles/` 目录创建新的 YAML 文件：

```yaml
# roles/customer-support.yml
name: customer-support
display_name: 客服专家
version: 1.0.0
description: 客户服务专家，擅长问题解答、投诉处理

capabilities:
  - problem_solving
  - communication
  - empathy

behavior:
  tone: friendly
  detail_level: medium
  patience: high

system_prompt_prefix: |
  你是一位资深客服专家，拥有 5 年客户服务经验。
  你的特点：耐心、友好、专业、善于倾听...
```

2. 部署新角色：

```bash
./deploy-specialized-agents.sh --role customer-support --count 10
```

## 📊 批量部署最佳实践

### 1. 端口规划

```
角色              端口范围      数量
data-analyst     19001-19010   10
coding-expert    19101-19120   20
devops-expert    19201-19205   5
decision-maker   19301-19303   3
qa-expert        19401-19410   10
```

### 2. 资源配置

```bash
# 轻量级角色（决策、QA）- 1GB 内存
./deploy-specialized-agents.sh --role decision-maker --count 3 --memory 1024

# 重量级角色（数据分析、编码）- 4GB 内存
./deploy-specialized-agents.sh --role data-analyst --count 5 --memory 4096
```

### 3. 环境隔离

```bash
# 生产环境使用独立 API Key
export QWEN_API_KEY=sk-production-key

# 开发环境
export QWEN_API_KEY=sk-dev-key

# 分别部署
./deploy-specialized-agents.sh --role coding-expert --count 5  # 使用生产 Key
```

## 🎛️ 高级配置

### 技能包定制

在角色配置文件中启用/禁用技能：

```yaml
skills:
  - name: pandas-expert
    enabled: true
    config:
      version: "2.0"
  
  - name: statistics
    enabled: false  # 禁用此技能
```

### 行为调优

```yaml
behavior:
  tone: professional      # professional | casual | friendly
  detail_level: high      # low | medium | high
  show_reasoning: true    # 显示推理过程
  ask_clarifying: true    # 主动询问澄清问题
  prefer_code: true       # 优先提供代码
```

## 📈 扩展能力

### 添加新技能包

1. 在 `skills/` 目录创建技能配置
2. 在角色配置中引用

### 动态配置更新

```bash
# 修改角色配置文件
vim roles/data-analyst.yml

# 重新注入到运行中的容器
./inject-role-config.sh --container data-analyst-1 --role data-analyst

# 重启容器
docker restart data-analyst-1
```

## 🔗 相关文件

- 角色配置：`roles/*.yml`
- 部署脚本：`scripts/deploy-specialized-agents.sh`
- 注入工具：`scripts/inject-role-config.sh`
- 路由管理：`scripts/router.sh`

---

*版本：1.0 | 最后更新：2026-03-29*
