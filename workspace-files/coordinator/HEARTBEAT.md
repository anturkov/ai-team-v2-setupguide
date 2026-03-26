# Heartbeat Tasks

These tasks run periodically (~every 30 minutes) to maintain team health.

## Check Active Sessions
Review `sessions_list` for any stalled or timed-out agent sessions. If a session has been running for more than 15 minutes with no progress, notify the human via Telegram.

## Check Agent Availability
Verify that all team members are responsive by checking recent session activity. If an agent hasn't responded in the last hour, note it for the next human interaction.

## Summarize Pending Work
If there are completed sub-agent sessions that haven't been reported to the human yet, compile a brief status update.
