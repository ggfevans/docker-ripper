#!/bin/bash
# discord.sh - Discord notification provider for docker-ripper
#
# This module implements Discord webhook notifications.

# Discord configuration from environment variables
DISCORD_ENABLED="${DISCORD_ENABLED:-false}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
DISCORD_USERNAME="${DISCORD_USERNAME:-Docker-Ripper}"
DISCORD_AVATAR_URL="${DISCORD_AVATAR_URL:-}"

# Color codes for different notification priorities
DISCORD_COLOR_INFO="3066993"      # Green
DISCORD_COLOR_WARNING="16776960"  # Yellow
DISCORD_COLOR_ERROR="15158332"    # Red

# Initialize Discord provider
init_discord() {
    if [ "$DISCORD_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Discord notifications disabled"
        return 1
    fi
    
    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        echo "[WARNING] Discord webhook URL not configured"
        DISCORD_ENABLED="false"
        return 1
    fi
    
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Discord notifications enabled"
    return 0
}

# Send a notification to Discord
send_discord_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"
    local extra_data="$4"
    
    # Check if Discord is enabled
    if [ "$DISCORD_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Discord notifications are disabled"
        return 1
    fi
    
    # Set color based on priority
    local color="$DISCORD_COLOR_INFO"
    case "$priority" in
        "warning") color="$DISCORD_COLOR_WARNING" ;;
        "error") color="$DISCORD_COLOR_ERROR" ;;
    esac
    
    # Escape special characters in the message and title
    local escaped_title=$(echo "$title" | sed 's/"/\\"/g')
    local escaped_message=$(echo "$message" | sed 's/"/\\"/g')
    
    # Prepare timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create JSON payload
    local payload=$(cat << EOF
{
    "username": "${DISCORD_USERNAME}",
    "avatar_url": "${DISCORD_AVATAR_URL}",
    "embeds": [
        {
            "title": "${escaped_title}",
            "description": "${escaped_message}",
            "color": ${color},
            "timestamp": "${timestamp}"
        }
    ]
}
EOF
    )
    
    # Add extra fields if provided
    if [ -n "$extra_data" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Extra data provided: $extra_data"
        # This is a simple implementation - for production, you might want to use jq to parse JSON
    fi
    
    # Send the notification
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Sending Discord notification: $escaped_title"
    
    local response
    response=$(curl -s -S -f -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_WEBHOOK_URL" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] Failed to send Discord notification: $response"
        return 1
    else
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Discord notification sent successfully"
        return 0
    fi
}