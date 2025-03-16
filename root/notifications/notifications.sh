#!/bin/bash
# notifications.sh - Main notification handler for docker-ripper
# 
# This module provides a unified interface for sending notifications
# through multiple notification providers.

# Set the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration from environment variables
NOTIFICATION_ENABLED="${NOTIFICATION_ENABLED:-false}"
NOTIFICATION_LEVEL="${NOTIFICATION_LEVEL:-all}" # all, error, none
NOTIFICATION_PROVIDERS="${NOTIFICATION_PROVIDERS:-}" # comma-separated list of enabled providers

# Load provider modules if they exist
PROVIDERS_DIR="${SCRIPT_DIR}/providers"

if [ -f "${PROVIDERS_DIR}/discord.sh" ]; then
    source "${PROVIDERS_DIR}/discord.sh"
fi

if [ -f "${PROVIDERS_DIR}/pushover.sh" ]; then
    source "${PROVIDERS_DIR}/pushover.sh"
fi

if [ -f "${PROVIDERS_DIR}/webhook.sh" ]; then
    source "${PROVIDERS_DIR}/webhook.sh"
fi

# Check if a provider is enabled
is_provider_enabled() {
    local provider="$1"
    
    if [ -z "$NOTIFICATION_PROVIDERS" ]; then
        return 1
    fi
    
    echo "$NOTIFICATION_PROVIDERS" | grep -q "\b$provider\b"
    return $?
}

# Main notification function that delegates to appropriate providers
notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-info}" # info, warning, error
    local extra_data="${4:-}"   # optional JSON string with additional data
    
    # Check if notifications are enabled
    if [ "$NOTIFICATION_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Notifications are disabled"
        return 0
    fi
    
    # Check notification level
    if [ "$NOTIFICATION_LEVEL" = "none" ]; then
        return 0
    elif [ "$NOTIFICATION_LEVEL" = "error" ] && [ "$priority" != "error" ]; then
        return 0
    fi
    
    # Log the notification attempt
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Sending notification: $title - $message (Priority: $priority)"
    
    # Send to all enabled providers
    IFS=',' read -ra PROVIDERS <<< "$NOTIFICATION_PROVIDERS"
    for provider in "${PROVIDERS[@]}"; do
        case "$provider" in
            "discord")
                if type send_discord_notification &>/dev/null; then
                    send_discord_notification "$title" "$message" "$priority" "$extra_data"
                else
                    [ "$DEBUG" = "true" ] && echo "[DEBUG] Discord provider not loaded"
                fi
                ;;
            "pushover")
                if type send_pushover_notification &>/dev/null; then
                    send_pushover_notification "$title" "$message" "$priority" "$extra_data"
                else
                    [ "$DEBUG" = "true" ] && echo "[DEBUG] Pushover provider not loaded"
                fi
                ;;
            "webhook")
                if type send_webhook_notification &>/dev/null; then
                    send_webhook_notification "$title" "$message" "$priority" "$extra_data"
                else
                    [ "$DEBUG" = "true" ] && echo "[DEBUG] Webhook provider not loaded"
                fi
                ;;
            *)
                [ "$DEBUG" = "true" ] && echo "[DEBUG] Unknown provider: $provider"
                ;;
        esac
    done
}

# Convenience functions for different notification types
notify_info() {
    notify "$1" "$2" "info" "$3"
}

notify_warning() {
    notify "$1" "$2" "warning" "$3"
}

notify_error() {
    notify "$1" "$2" "error" "$3"
}

# Initialize notification system
init_notifications() {
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Initializing notification system"
    
    if [ "$NOTIFICATION_ENABLED" != "true" ]; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Notification system disabled"
        return 0
    fi
    
    # Initialize enabled providers
    for provider in $(echo "$NOTIFICATION_PROVIDERS" | tr ',' ' '); do
        case "$provider" in
            "discord")
                if type init_discord &>/dev/null; then
                    init_discord
                else
                    echo "[WARNING] Discord provider requested but not available"
                fi
                ;;
            "pushover")
                if type init_pushover &>/dev/null; then
                    init_pushover
                else
                    echo "[WARNING] Pushover provider requested but not available"
                fi
                ;;
            "webhook")
                if type init_webhook &>/dev/null; then
                    init_webhook
                else
                    echo "[WARNING] Webhook provider requested but not available"
                fi
                ;;
            *)
                echo "[WARNING] Unknown notification provider: $provider"
                ;;
        esac
    done
    
    # Log initialization status
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Notification system initialized with providers: $NOTIFICATION_PROVIDERS"
}

# Call initialization if this script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Initialize immediately when sourced
    init_notifications
fi