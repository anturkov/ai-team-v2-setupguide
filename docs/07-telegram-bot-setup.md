# Chapter 07 - Telegram Bot Setup

This chapter walks you through creating a Telegram bot and integrating it with OpenClaw so you can communicate with your AI team from your phone or desktop.

---

## 7.1 Why Telegram?

Telegram provides:
- Real-time messaging from any device (phone, tablet, desktop, web)
- Bot API that's free and well-documented
- Support for rich messages (code blocks, images, files)
- Reliable message delivery
- No cost for bot usage

---

## 7.2 Create the Telegram Bot

### Step 1: Open Telegram

Open the Telegram app on your phone or desktop.

### Step 2: Find BotFather

1. In the Telegram search bar, type `@BotFather`
2. Click on the official **BotFather** account (it has a blue checkmark)
3. Click **Start** or type `/start`

### Step 3: Create a New Bot

1. Type `/newbot` and send it
2. BotFather will ask: **"Alright, a new bot. How are we going to call it?"**
3. Type a display name for your bot, for example: `AI Team Coordinator`
4. BotFather will ask: **"Good. Now let's choose a username for your bot."**
5. Type a unique username ending in `bot`, for example: `my_ai_team_bot`
   - If the name is taken, try variations like `ai_team_dev_bot` or `myteam_coordinator_bot`

### Step 4: Save Your Bot Token

BotFather will respond with something like:

```
Done! Congratulations on your new bot. You will find it at t.me/my_ai_team_bot.
You can now add a description, about section and profile picture for your bot.

Use this token to access the HTTP API:
7123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw

Keep your token secure and store it safely.
```

**Copy the token** (the long string starting with numbers). You will need it in the next steps.

> **IMPORTANT**: This token gives full control of your bot. Never share it publicly or commit it to a git repository.

### Step 5: Configure the Bot (Optional but Recommended)

While still chatting with BotFather, set up your bot:

```
/setdescription
```
Enter: `AI Development Team Coordinator - manages distributed AI agents`

```
/setabouttext
```
Enter: `I coordinate a team of AI agents for software development. Send me tasks and I'll delegate to the right specialist.`

```
/setcommands
```
Enter the following (paste all at once):
```
status - Check team status and active tasks
assign - Assign a task to the team
review - Request a code review
deploy - Trigger a deployment
health - Check system health and resources
help - Show available commands
cancel - Cancel the current task
```

---

## 7.3 Get Your Chat ID

The bot needs to know which Telegram user(s) are authorized to send it commands.

### Step 1: Start a Chat with Your Bot

1. In Telegram, search for your bot by its username (e.g., `@my_ai_team_bot`)
2. Click **Start** or send `/start`

### Step 2: Get Your Chat ID

Open a browser and visit this URL (replace `YOUR_BOT_TOKEN` with your actual token):

```
https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
```

For example:
```
https://api.telegram.org/bot7123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw/getUpdates
```

You'll see a JSON response. Look for the `"chat"` object:

```json
{
  "ok": true,
  "result": [
    {
      "message": {
        "chat": {
          "id": 123456789,
          "first_name": "Your Name",
          "type": "private"
        },
        "text": "/start"
      }
    }
  ]
}
```

**Copy the `id` number** (e.g., `123456789`). This is your Chat ID.

> **Tip**: If the result is empty `[]`, send another message to your bot first, then refresh the URL.

---

## 7.4 Configure OpenClaw Telegram Integration

### Step 1: Store the Bot Token

On PC1, open PowerShell:

```powershell
# Store the Telegram bot token securely in OpenClaw
openclaw config set telegram.bot_token "7123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"
```

> **Replace** the example token above with your actual bot token from Step 4.

### Step 2: Set Authorized Users

```powershell
# Set your Chat ID as an authorized user
openclaw config set telegram.authorized_users "123456789"

# To add multiple authorized users (comma-separated):
# openclaw config set telegram.authorized_users "123456789,987654321"
```

### Step 3: Configure Bot Behavior

```powershell
# Enable the Telegram integration
openclaw config set telegram.enabled "true"

# Set the bot to forward messages to the coordinator model
openclaw config set telegram.target_model "coordinator"

# Enable rich formatting (code blocks, etc.)
openclaw config set telegram.rich_format "true"

# Set maximum message length before splitting
openclaw config set telegram.max_message_length 4096

# Enable notification sounds for important messages
openclaw config set telegram.notify_on_escalation "true"
```

### Step 4: Create the Telegram Configuration File

Alternatively, you can configure everything in a YAML file.

**File**: `C:\AI-Team\openclaw\config\telegram.yaml`

```yaml
# Telegram Bot Configuration
telegram:
  enabled: true
  bot_token: "YOUR_BOT_TOKEN_HERE"      # Replace with your actual token

  # Security
  authorized_users:
    - 123456789                           # Replace with your Chat ID
  unauthorized_response: "You are not authorized to use this bot."

  # Message routing
  target_model: "coordinator"

  # Formatting
  rich_format: true
  max_message_length: 4096
  code_block_language: "auto"

  # Notifications
  notify_on_escalation: true
  notify_on_error: true
  notify_on_completion: true

  # Rate limiting
  max_messages_per_minute: 30

  # Commands
  commands:
    status:
      description: "Check team status and active tasks"
      handler: "coordinator"
      prompt: "Provide a brief status update on all active tasks and team member availability."

    assign:
      description: "Assign a task to the team"
      handler: "coordinator"
      prompt: "The human operator wants to assign a new task. Analyze the following request and assign it to the appropriate team member(s)."

    review:
      description: "Request a code review"
      handler: "coordinator"
      prompt: "The human operator requests a code review. Route this to the Quality Agent and Security Agent."

    deploy:
      description: "Trigger a deployment"
      handler: "coordinator"
      prompt: "The human operator requests a deployment. Route this to the DevOps Agent with appropriate safety checks."

    health:
      description: "Check system health"
      handler: "monitoring-agent"
      prompt: "Provide a full health report on all machines, GPU usage, VRAM, RAM, disk space, and model status."

    cancel:
      description: "Cancel current task"
      handler: "coordinator"
      prompt: "The human operator wants to cancel the current task. Notify all involved agents and clean up."

    help:
      description: "Show available commands"
      handler: "builtin"
```

Load the configuration:

```powershell
openclaw telegram load --config "C:\AI-Team\openclaw\config\telegram.yaml"
```

---

## 7.5 Start the Telegram Bot

```powershell
# Start the Telegram bot service
openclaw telegram start
```

You should see:

```
[INFO] Telegram bot starting...
[INFO] Bot username: @my_ai_team_bot
[INFO] Authorized users: 1
[INFO] Listening for messages...
```

### Test It

Open Telegram and send a message to your bot:

```
Hello, are you working?
```

The coordinator should receive the message, process it, and reply through the bot. You should see a response within 10-30 seconds (depending on model load time).

### Test the Commands

Try each command:

```
/status
/health
/help
```

Each should trigger the appropriate action and return a response.

---

## 7.6 Telegram Bot as a Windows Service

So the bot starts automatically on boot:

```powershell
# Register the Telegram bot as part of the OpenClaw service
openclaw telegram service install

# Verify
openclaw telegram service status
```

> **Note**: The Telegram bot runs on PC1 alongside the OpenClaw coordinator. If PC1 goes down, the bot goes down too. See [Chapter 14](14-error-handling-recovery.md) for backup strategies.

---

## 7.7 Message Flow Example

Here's a complete flow of what happens when you send a message:

```
YOU (Telegram): "Create a Python function that validates email addresses"
        │
        ▼
[Telegram Cloud API]
        │
        ▼
[PC1: OpenClaw Telegram Service]
        │ Receives message, checks authorization
        │ Forwards to coordinator model
        ▼
[PC1: Coordinator Model]
        │ Analyzes task: "This is an implementation task"
        │ Decides: assign to Senior Engineer #2
        │ Also: Quality Agent should review
        ▼
[PC1 → OpenClaw → PC1: Senior Engineer #2]
        │ Writes the email validation function
        │ Returns code to Coordinator
        ▼
[PC1 → OpenClaw → PC2: Quality Agent]
        │ Reviews the code
        │ Returns review feedback
        ▼
[PC1: Coordinator Model]
        │ Compiles results: code + review feedback
        │ Formats response
        ▼
[PC1: OpenClaw Telegram Service]
        │ Sends formatted response back
        ▼
[Telegram Cloud API]
        │
        ▼
YOU (Telegram): Receives the validated code with review notes
```

---

## 7.8 Escalation Messages

When the AI team needs human input, the coordinator sends an escalation message:

```
🔔 ESCALATION REQUEST

Task: Deploy authentication service to production
Reason: This deployment requires access to production credentials that I don't have.

Required Action:
1. Provide production database connection string
2. Confirm deployment window is acceptable

Please reply with the requested information or type /cancel to abort.
```

These messages are marked as high priority and will trigger a notification sound (if configured).

---

## 7.9 Security Considerations

### 7.9.1 Token Security

- **Never** commit the bot token to git
- Store it only in OpenClaw's secure configuration
- Rotate the token periodically via BotFather (`/revoke` then `/newbot`)

### 7.9.2 User Authorization

- Only authorized Chat IDs can interact with the bot
- Unauthorized users receive a rejection message
- All messages (including unauthorized attempts) are logged

### 7.9.3 Rate Limiting

The bot has built-in rate limiting to prevent:
- Accidental spam from flooding the AI team
- Excessive API usage for the external consultant
- Resource exhaustion from too many concurrent tasks

---

## 7.10 Checklist

- [ ] Bot created via BotFather
- [ ] Bot token saved securely
- [ ] Your Chat ID obtained
- [ ] OpenClaw Telegram configuration completed
- [ ] Telegram bot service started
- [ ] Test message sent and response received
- [ ] All bot commands tested (`/status`, `/health`, `/help`)
- [ ] Bot installed as a Windows service
- [ ] Unauthorized user rejection tested (have a friend try messaging the bot)
- [ ] Escalation messages formatted correctly

---

Next: [Chapter 08 - Inter-Machine Communication](08-inter-machine-communication.md)
