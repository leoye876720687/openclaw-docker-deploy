---
name: openclaw-docker-deploy
description: Deploy OpenClaw agents in isolated Docker containers with multi-instance support, health checks, and automated model configuration.
metadata: {"clawdbot":{"emoji":"🐳","requires":{"bins":["docker","docker compose"]},"install":[{"id":"docker","kind":"apt","formula":"docker.io","bins":["docker","dockerd"],"label":"Install Docker"},{"id":"docker-compose","kind":"apt","formula":"docker-compose-v2","bins":["docker compose"],"label":"Install Docker Compose"}]}}
---

# OpenClaw Docker Deploy 🐳

Deploy OpenClaw agents in isolated Docker containers with multi-instance support, automated model configuration, and production-ready health checks.

## Quick Start

### Single Instance

```bash
# Build image
cd /home/leoye/.openclaw/docker-openclaw
docker compose build

# Deploy
QWEN_API_KEY=sk-your-key docker compose up -d

# Verify
docker ps --filter "name=openclaw"
```

### Multi-Instance

```bash
# Container 1 (port 18891)
docker run -d --name openclaw-agent-1 -p 18891:18789 \
  -e QWEN_API_KEY=sk-key-1 \
  -e NODE_OPTIONS=--max-old-space-size=2048 \
  docker-openclaw-openclaw

# Container 2 (port 18892)
docker run -d --name openclaw-agent-2 -p 18892:18789 \
  -e QWEN_API_KEY=sk-key-2 \
  -e NODE_OPTIONS=--max-old-space-size=2048 \
  docker-openclaw-openclaw
```

## Scripts

### Deploy Script

```bash
# Deploy new agent
./scripts/deploy-agent.sh --name my-agent --port 18899 --api-key sk-xxx

# Verify deployment
./scripts/verify-deployment.sh --name my-agent
```

### Management

```bash
# List all agents
./scripts/list-agents.sh

# Stop agent
./scripts/stop-agent.sh --name openclaw-agent-1

# Remove agent
./scripts/remove-agent.sh --name openclaw-agent-1
```

### Router (Route to Containers)

```bash
# Route to specific container
./scripts/router.sh -c openclaw-agent-1 "你好"

# Route by port
./scripts/router.sh -p 18892 "帮我分析数据"

# Auto select (first healthy)
./scripts/router.sh -a "今天天气怎么样"

# Round-robin (auto switch)
./scripts/router.sh -r "处理这个任务"

# List containers
./scripts/router.sh -l

# Show status
./scripts/router.sh -s
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `QWEN_API_KEY` | ✅ | - | Alibaba Cloud DashScope API Key |
| `CONTAINER_NAME` | ❌ | `openclaw-agent` | Container name |
| `EXTERNAL_PORT` | ❌ | `18888` | External port |
| `NODE_OPTIONS` | ❌ | `--max-old-space-size=2048` | Node.js memory limit |

### Model Configuration

Default model: `aliyun-qwen/qwen3.5-plus`

The entrypoint script automatically configures the model on first startup.

## Health Checks

```bash
# HTTP health
curl http://localhost:18888/health

# Container status
docker ps --filter "name=openclaw" --format "table {{.Names}}\t{{.Status}}"

# Logs
docker logs -f openclaw-agent
```

## Conversation

```bash
# Direct conversation
docker exec -it openclaw-agent openclaw agent --session-id my-session --message "你好"

# Interactive shell
docker exec -it openclaw-agent bash
openclaw agent --session-id my-session --message "你好"
```

## Templates

### Docker Compose (Single)

```yaml
services:
  openclaw:
    image: docker-openclaw-openclaw
    container_name: openclaw-agent
    ports:
      - "18888:18789"
    environment:
      - QWEN_API_KEY=sk-your-key
      - NODE_OPTIONS=--max-old-space-size=2048
    restart: unless-stopped
```

### Docker Compose (Multi)

```yaml
services:
  agent-1:
    extends:
      file: docker-compose.yml
      service: openclaw
    container_name: agent-1
    ports:
      - "18891:18789"
    environment:
      - QWEN_API_KEY=sk-key-1

  agent-2:
    extends:
      file: docker-compose.yml
      service: openclaw
    container_name: agent-2
    ports:
      - "18892:18789"
    environment:
      - QWEN_API_KEY=sk-key-2
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs openclaw-agent --tail=50

# Check port conflict
lsof -i :18888

# Rebuild
docker compose build --no-cache
docker compose up -d
```

### Model configuration failed

```bash
# Check config
docker exec openclaw-agent cat /home/openclaw/.openclaw/openclaw.json

# Restart container
docker restart openclaw-agent
```

### Remove stuck container

```bash
docker stop openclaw-agent
docker rm openclaw-agent
```

## Files

- `scripts/deploy-agent.sh` - Deploy new agent
- `scripts/verify-deployment.sh` - Verify deployment
- `scripts/list-agents.sh` - List all agents
- `scripts/stop-agent.sh` - Stop agent
- `scripts/remove-agent.sh` - Remove agent
- `templates/docker-compose.single.yml` - Single instance template
- `templates/docker-compose.multi.yml` - Multi-instance template
- `examples/deploy-example.sh` - Deployment example

## Version

- **v1.1.0** (2026-03-30) - Fixed container initialization
  - ✅ Added `init-agent-container.sh` script for automatic directory structure setup
  - ✅ Fixed missing `sessions/` directory causing `EACCES: permission denied` errors
  - ✅ Auto-configure default model to `qwen-portal/coder-model` (avoid Anthropic dependency)
  - ✅ Updated `deploy-agent.sh` to call initialization script after container startup
  - ✅ Proper permission handling for all agent directories

- **v1.0.0** (2026-03-29) - Initial release

## License

MIT
