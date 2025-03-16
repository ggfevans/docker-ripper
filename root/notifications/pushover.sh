#!/bin/bash
# pushover.sh - Pushover notification provider for docker-ripper
#
# This module implements Pushover API notifications.

# Pushover configuration from environment variables
PUSHOVER_ENABLED="${PUSHOVER_ENABLED:-false}"
PUSHOVER_APP_TOKEN="${PUSHOVER_APP_TOKEN:-}"
PUSHOVER_USER_KEY="${PUSHOVER_USER_KEY:-}"
PUSHOVER_DEVICE="${PUSHOVER_DEVICE:-}"
PUSHOVER_SOUND="${PUSHOVER_SOUND:-}"

# Pushover API endpoint
PUSHOVER_API_URL="https://api.pushover.net/1/messages.json"

# Initialize Pushover provider
init_pushover() {
    if [ "$PUSHOVER_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Pushover notifications disabled"
        return 1
    fi
    
    if [ -z "$PUSHOVER_APP_TOKEN" ]; then
        echo "[WARNING] Pushover app token not configured"
        PUSHOVER_ENABLED="false"
        return 1
    fi
    
    if [ -z "$PUSHOVER_USER_KEY" ]; then
        echo "[WARNING] Pushover user key not configured"
        PUSHOVER_ENABLED="false"
        return 1
    fi
    
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Pushover notifications enabled"
    return 0
}

# Send a notification to Pushover
send_pushover_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"
    local extra_data="$4"
    
    # Check if Pushover is enabled
    if [ "$PUSHOVER_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Pushover notifications are disabled"
        return 1
    fi
    
    # Map our priority to Pushover's priority
    local pushover_priority=0
    case "$priority" in
        "info") pushover_priority=0 ;;
        "warning") pushover_priority=1 ;;
        "error") pushover_priority=2 ;;
    esac
    
    # Build the request data
    local request_data="token=${PUSHOVER_APP_TOKEN}&user=${PUSHOVER_USER_KEY}"
    request_data="${request_data}&title=${title}&message=${message}&priority=${pushover_priority}"
    
    # Add device if specified
    if [ -n "$PUSHOVER_DEVICE" ]; then
        request_data="${request_data}&device=${PUSHOVER_DEVICE}"
    fi
    
    # Add sound if specified
    if [ -n "$PUSHOVER_SOUND" ]; then
        request_data="${request_data}&sound=${PUSHOVER_SOUND}"
    fi
    
    # Send the notification
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Sending Pushover notification: $title"
    
    local response
    response=$(curl -s -S -f -X POST --data-urlencode "$request_data" "$PUSHOVER_API_URL" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] Failed to send Pushover notification: $response"
        return 1
    else
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Pushover notification sent successfully"
        return 0
    fi
}