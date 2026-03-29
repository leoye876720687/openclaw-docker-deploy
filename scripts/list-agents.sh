#!/bin/bash

# List all OpenClaw agents
echo "============================================"
echo "   🐳 OpenClaw Agents"
echo "============================================"
echo ""
docker ps -a --filter "name=openclaw" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Total: $(docker ps -a --filter "name=openclaw" -q | wc -l) container(s)"
echo ""
