# OpenClaw Docker Deploy Skill 🐳

**Version**: v1.0.0  
**Created**: 2026-03-29  
**Author**: 叶萌

Deploy OpenClaw agents in isolated Docker containers with multi-instance support, automated model configuration, and production-ready health checks.

## Features

- ✅ **Isolated Deployment** - Each agent runs in its own container
- ✅ **Multi-Instance** - Deploy multiple agents with different ports
- ✅ **Auto Configuration** - Automatic model setup on first startup
- ✅ **Health Checks** - Built-in health monitoring
- ✅ **Management Scripts** - Deploy, verify, list, stop, remove
- ✅ **Templates** - Docker Compose templates for single/multi deployment

## Quick Start

### Install

```bash
# Clone or copy this skill to your workspace
cd /home/leoye/.openclaw/workspace/skills/openclaw-docker-deploy
```

### Deploy Single Agent

```bash
./scripts/deploy-agent.sh --name my-agent --port 18888 --api-key sk-xxx
```

### Deploy Specialized Agents (NEW!)

```bash
# Deploy 3 data analyst agents
./scripts/deploy-specialized-agents.sh --role data-analyst --count 3 --base-port 19000

# Deploy 5 coding experts
./scripts/deploy-specialized-agents.sh --role coding-expert --count 5 --base-port 19100
```

### Deploy Multiple Agents

```bash
# Using docker run
docker run -d --name agent-1 -p 18891:18789 -e QWEN_API_KEY=sk-xxx docker-openclaw-openclaw
docker run -d --name agent-2 -p 18892:18789 -e QWEN_API_KEY=sk-xxx docker-openclaw-openclaw

# Or using docker compose
docker compose -f templates/docker-compose.multi.yml up -d
```

### Verify

```bash
./scripts/verify-deployment.sh --name my-agent
```

### Chat

```bash
# Direct command
docker exec my-agent openclaw agent --session-id chat --message "你好"

# Using router (recommended)
./scripts/router.sh -c my-agent "你好"

# Round-robin mode
./scripts/router.sh -r "处理任务"
```

## Scripts

| Script | Description |
|--------|-------------|
| `deploy-agent.sh` | Deploy new agent with custom name/port |
| `verify-deployment.sh` | Verify deployment (5-point check) |
| `list-agents.sh` | List all OpenClaw agents |
| `stop-agent.sh` | Stop an agent |
| `remove-agent.sh` | Remove an agent |
| `router.sh` | Route messages to containers |

## Templates

| Template | Description |
|----------|-------------|
| `docker-compose.single.yml` | Single agent deployment |
| `docker-compose.multi.yml` | Multi-agent deployment (3 agents) |

## Roles (Specialized Agents)

| Role | Description | Use Cases |
|------|-------------|-----------|
| `data-analyst` | Data analysis expert | Data processing, statistics, visualization |
| `coding-expert` | Full-stack developer | Code generation, review, debugging |
| `devops-expert` | Infrastructure expert | Deployment, monitoring, troubleshooting |
| `decision-maker` | Strategic advisor | Analysis, evaluation, planning |
| `qa-expert` | Quality assurance | Testing, verification, review |

See `docs/SPECIALIZED-AGENTS.md` for details.

## Examples

See `examples/deploy-example.sh` for a complete deployment workflow demonstration.

## Documentation

Full SOP documentation: `/home/leoye/.openclaw/workspace/docs/docker-deployment-sop.md`

## Version History

### v1.0.0 (2026-03-29)

- Initial release
- Deploy/verify/list/stop/remove scripts
- Docker Compose templates
- Complete SOP documentation
- GitHub version control

## License

MIT
