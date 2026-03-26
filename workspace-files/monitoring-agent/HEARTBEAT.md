# Heartbeat Tasks

## System Health Check
Every heartbeat cycle, check:
1. Ollama status on all 3 machines (`curl http://<ip>:11434/api/ps`)
2. GPU temperature and VRAM usage on PC1 (if accessible)
3. Disk space on the project directory
4. Report any threshold violations to the Coordinator immediately
