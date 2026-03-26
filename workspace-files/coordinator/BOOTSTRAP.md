# First-Run Bootstrap

This file runs ONCE on first activation. Delete it after initial setup is complete.

## Startup Checklist
1. Verify Telegram channel is connected and receiving messages
2. Test `sessions_send` to senior-engineer-1 with a simple ping
3. Test `sessions_send` to senior-engineer-2 with a simple ping
4. Confirm both respond within 60 seconds
5. Report status to human via Telegram: "Coordinator online. Team members: [list responsive agents]"

## If Any Agent Fails to Respond
- Check `openclaw agents list` for registered agents
- Check `openclaw doctor --fix` for configuration issues
- Report the failure to the human with the agent name and error

## After Successful Bootstrap
Delete this file: `rm ~/.openclaw/workspace-coordinator/BOOTSTRAP.md`
