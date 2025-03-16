# Docker-Ripper Notification System

This directory contains the notification system for Docker-Ripper, allowing you to receive alerts about disc detection, ripping progress, and errors via multiple notification providers.

## Enabling the Notification System

To enable notifications, set the following environment variables in your Docker configuration:

```yaml
NOTIFICATION_ENABLED=true
NOTIFICATION_PROVIDERS=discord,pushover,webhook  # Use any combination
NOTIFICATION_LEVEL=all  # Options: all, error, none
```

## Core Environment Variables

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `NOTIFICATION_ENABLED` | Master switch for notifications | `false` | `true`, `false` |
| `NOTIFICATION_PROVIDERS` | Comma-separated list of enabled providers | empty | `discord`, `pushover`, `webhook` |
| `NOTIFICATION_LEVEL` | Controls which notifications are sent | `all` | `all`, `error`, `none` |
| `DEBUG` | Enables detailed logging for notifications | `false` | `true`, `false` |

## Provider Configuration

### Discord

Send notifications to Discord channels using webhooks.

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `DISCORD_ENABLED` | Enable Discord notifications | Yes | `true` |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL | Yes | `https://discord.com/api/webhooks/123456789/abcdef...` |
| `DISCORD_USERNAME` | Override the webhook's username | No | `Ripper Bot` |
| `DISCORD_AVATAR_URL` | Override the webhook's avatar | No | `https://example.com/avatar.png` |

### Pushover

Send mobile notifications through the Pushover service.

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `PUSHOVER_ENABLED` | Enable Pushover notifications | Yes | `true` |
| `PUSHOVER_APP_TOKEN` | Pushover application token | Yes | `azGDORePK8gMaC0QOYAMyEEuzJnyUi` |
| `PUSHOVER_USER_KEY` | Pushover user/group key | Yes | `uQiRzpo4DXghDmr9QzzfQu27cmVRsG` |
| `PUSHOVER_DEVICE` | Target specific device | No | `iphone,desktop` |
| `PUSHOVER_SOUND` | Alert sound to use | No | `cosmic` |

### Webhook

Send notifications to any custom webhook endpoint.

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `WEBHOOK_ENABLED` | Enable webhook notifications | Yes | `true` |
| `WEBHOOK_URL` | URL to send webhook requests to | Yes | `https://example.com/webhook` |
| `WEBHOOK_METHOD` | HTTP method to use | No | `POST` (default) |
| `WEBHOOK_CONTENT_TYPE` | Content type header | No | `application/json` (default) |
| `WEBHOOK_CUSTOM_HEADERS` | Additional headers (JSON format) | No | `{"Authorization": "Bearer token"}` |

## Usage Examples

### Docker Compose Example

```yaml
version: '3.3'
services:
  docker-ripper:
    image: rix1337/docker-ripper:latest
    environment:
      # Core notification settings
      - NOTIFICATION_ENABLED=true
      - NOTIFICATION_PROVIDERS=discord,pushover
      - NOTIFICATION_LEVEL=all
      
      # Discord configuration
      - DISCORD_ENABLED=true
      - DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/123456789/abcdef...
      
      # Pushover configuration
      - PUSHOVER_ENABLED=true
      - PUSHOVER_APP_TOKEN=azGDORePK8gMaC0QOYAMyEEuzJnyUi
      - PUSHOVER_USER_KEY=uQiRzpo4DXghDmr9QzzfQu27cmVRsG
      - PUSHOVER_DEVICE=iphone
      
    volumes:
      - /path/to/config/:/config:rw
      - /path/to/rips/:/out:rw
    devices:
      - /dev/sr0:/dev/sr0
      - /dev/sg0:/dev/sg0
```

### Docker Run Example

```bash
docker run -d \
  --name="Ripper" \
  -e NOTIFICATION_ENABLED=true \
  -e NOTIFICATION_PROVIDERS=webhook \
  -e WEBHOOK_ENABLED=true \
  -e WEBHOOK_URL=https://example.com/webhook \
  -v /path/to/config/:/config:rw \
  -v /path/to/rips/:/out:rw \
  --device=/dev/sr0:/dev/sr0 \
  --device=/dev/sg0:/dev/sg0 \
  rix1337/docker-ripper:latest
```

## Notification Events

The notification system sends alerts for the following events:

1. **Disc Detection** - When a disc is inserted and detected
2. **Rip Start** - When the ripping process begins
3. **Rip Completion** - When the ripping process successfully completes
4. **Error Events** - When errors occur during the ripping process

## Troubleshooting

### No Notifications Received

- Verify that `NOTIFICATION_ENABLED` is set to `true`
- Check that you've properly configured at least one provider in `NOTIFICATION_PROVIDERS`
- Confirm that all required environment variables for your chosen provider(s) are set correctly
- If using Discord, check that the webhook URL is correct and the webhook hasn't been deleted
- For Pushover, verify your API tokens and user keys are valid

### Enable Debug Mode

Add `DEBUG=true` to your environment variables to see detailed logs:

```
DEBUG=true
```

Check the container logs for errors:

```bash
docker logs ripper
```

### Provider-Specific Issues

#### Discord
- Make sure your webhook URL is valid and the channel still exists
- Check that the bot has permission to post in the channel
- If messages are missing embeds, your webhook may have permission issues

#### Pushover
- Verify your user key and application token are correct 
- Make sure you haven't exceeded your message quota
- Check if you've specified a non-existent device name

#### Webhook
- Verify your webhook endpoint is accessible from the container
- Check that your webhook endpoint accepts the content type you've configured
- Use `DEBUG=true` to view the full request and response