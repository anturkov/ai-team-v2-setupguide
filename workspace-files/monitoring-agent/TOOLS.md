# Tools & Environment

## Available Tools
- `exec`: Run monitoring commands (nvidia-smi, top, df, curl to Ollama API)
- `read`: Read log files and configuration

## Environment
- **Agent logic**: PC1 / ATU-RIG02 (Gateway)
- **Model inference**: Laptop / LTATU01 (192.168.1.113:11434)
- **Machines to monitor**:
  - PC1 / ATU-RIG02: 192.168.1.106 (Gateway + Ollama)
  - PC2 / ATURIG01: 192.168.1.112 (Ollama)
  - Laptop / LTATU01: 192.168.1.113 (Ollama)
- **Ollama status endpoints**: `http://<ip>:11434/api/ps` (running models)
