# Tools & Environment

## Available Tools
- `read`, `write`, `edit`: File operations in the project directory
- `exec`: Shell commands — run tests, install packages, build projects
- `git`: Version control — commit, branch, diff

## Environment
- **Machine**: PC1 / ATU-RIG02
- **Project directory**: Shared with all agents via `cwd`
- **Model**: qwen3-coder:30b-a3b (local Ollama on localhost:11434)

## Workflow
1. Read existing code to understand context
2. Write/edit code files
3. Run tests via `exec` to verify
4. Report results to the Coordinator
