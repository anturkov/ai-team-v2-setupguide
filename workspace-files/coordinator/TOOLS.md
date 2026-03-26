# Tools & Environment

## Available Session Tools
- `sessions_send`: Send message to another agent, optionally wait for reply
- `sessions_spawn`: Spawn a sub-agent session for independent tasks (non-blocking)
- `sessions_list`: List all active sessions across agents
- `sessions_history`: Review past session results

## Environment
- **Gateway**: PC1 / ATU-RIG02 (192.168.1.106:18789)
- **Local Ollama**: localhost:11434 (qwen3-coder:30b-a3b)
- **Remote Ollama PC2**: 192.168.1.112:11434 (qwen3:14b)
- **Remote Ollama Laptop**: 192.168.1.113:11434 (qwen3:4b)
- **Telegram**: Bot connected, all messages routed to coordinator

## Restrictions
- Do NOT use `exec` tools — delegate shell commands to specialists
- Do NOT write code directly — delegate to senior engineers
- Do NOT make external API calls — use specialists or escalate to human
