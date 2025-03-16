#!/bin/bash
# webhook.sh - Generic webhook notification provider for docker-ripper
#
# This module implements a flexible webhook notification system.

# Webhook configuration from environment variables
WEBHOOK_ENABLED="${WEBHOOK_ENABLED:-false}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
WEBHOOK_CONTENT_TYPE="${WEBHOOK_CONTENT_TYPE:-application/json}"
WEBHOOK_METHOD="${WEBHOOK_METHOD:-POST}"
WEBHOOK_CUSTOM_HEADERS="${WEBHOOK_CUSTOM_HEADERS:-}"

# Initialize webhook provider
init_webhook() {
    if [ "$WEBHOOK_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Webhook notifications disabled"
        return 1
    fi
    
    if [ -z "$WEBHOOK_URL" ]; then
        echo "[WARNING] Webhook URL not configured"
        WEBHOOK_ENABLED="false"
        return 1
    fi
    
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Webhook notifications enabled"
    return 0
}

# Send a notification via webhook
send_webhook_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"
    local extra_data="$4"
    
    # Check if webhook is enabled
    if [ "$WEBHOOK_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Webhook notifications are disabled"
        return 1
    fi
    
    # Escape special characters in the message and title
    local escaped_title=$(echo "$title" | sed 's/"/\\"/g')
    local escaped_message=$(echo "$message" | sed 's/"/\\"/g')
    
    # Create the default JSON payload
    local payload=$(cat << EOF
{
    "title": "${escaped_title}",
    "message": "${escaped_message}",
    "priority": "${priority}",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    )
    
    # Merge with extra data if provided
    if [ -n "$extra_data" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Extra data provided: $extra_data"
        # In a more complete implementation, you'd want to merge the JSON here
        # For now, we'll use the extra data as-is if it's provided
        if [ -n "$extra_data" ]; then
            payload="$extra_data"
        fi
    fi
    
    # Build curl command
    local curl_cmd="curl -s -S -f -X $WEBHOOK_METHOD"
    curl_cmd="$curl_cmd -H 'Content-Type: $WEBHOOK_CONTENT_TYPE'"
    
    # Add custom headers if specified
    if [ -n "$WEBHOOK_CUSTOM_HEADERS" ]; then
        # Parse JSON headers and add them
        # This is a simplified implementation - in production you might want to use jq
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Using custom headers: $WEBHOOK_CUSTOM_HEADERS"
    fi
    
    # Complete the curl command
    curl_cmd="$curl_cmd -d '$payload' '$WEBHOOK_URL'"
    
    # Send the notification
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Sending webhook notification: $escaped_title"
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Webhook command: $curl_cmd"
    
    # Execute the curl command
    local response
    response=$(eval "$curl_cmd" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] Failed to send webhook notification: $response"
        return 1
    else
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Webhook notification sent successfully"
        return 0
    fi
}