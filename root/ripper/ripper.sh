#!/bin/bash
# ripper.sh - Automatically detect optical disks by their type and rip them
#
# This script handles the complete workflow for automatically detecting and ripping
# optical discs based on their type (BluRay, DVD, CD, Data).

# Set default values
STORAGE_CD="${STORAGE_CD:-/out/Ripper/CD}"
STORAGE_DATA="${STORAGE_DATA:-/out/Ripper/DATA}"
STORAGE_DVD="${STORAGE_DVD:-/out/Ripper/DVD}"
STORAGE_BD="${STORAGE_BD:-/out/Ripper/BluRay}"
DRIVE="${DRIVE:-/dev/sr0}"
BAD_THRESHOLD="${BAD_THRESHOLD:-5}"
EJECTENABLED="${EJECTENABLED:-true}"
DEBUG="${DEBUG:-false}"
JUSTMAKEISO="${JUSTMAKEISO:-false}"
SEPARATERAWFINISH="${SEPARATERAWFINISH:-false}"
ALSOMAKEISO="${ALSOMAKEISO:-false}"
TIMESTAMPPREFIX="${TIMESTAMPPREFIX:-false}"
MINIMUMLENGTH="${MINIMUMLENGTH:-600}"

# Load notification system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
if [ -f "${ROOT_DIR}/notifications/notifications.sh" ]; then
    source "${ROOT_DIR}/notifications/notifications.sh"
    NOTIFICATIONS_AVAILABLE=true
else
    NOTIFICATIONS_AVAILABLE=false
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Notification system not available"
fi

# Initialize variables
DISC_TYPE=""
DISC_LABEL=""
OUTPUT_PATH=""
PROCESSING=false
BAD_READS=0
START_TIME=0
LAST_DISC_STATE="empty"

# Function to create directories
create_directories() {
    mkdir -p "$STORAGE_BD" "$STORAGE_DVD" "$STORAGE_CD" "$STORAGE_DATA"
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Created storage directories"
}

# Function to detect disc type
detect_disc_type() {
    # First, check if disc is inserted
    if ! dd if="$DRIVE" of=/dev/null count=1 &>/dev/null; then
        [ "$DEBUG" = "true" ] && echo "[DEBUG] No disc detected or drive not ready"
        LAST_DISC_STATE="empty"
        return 1
    fi
    
    # If we previously detected an empty drive, this is a new disc
    if [ "$LAST_DISC_STATE" = "empty" ]; then
        LAST_DISC_STATE="loading"
        [ "$DEBUG" = "true" ] && echo "[DEBUG] Drive loading, waiting for disc to stabilize..."
        sleep 5
    fi
    
    # Use makemkvcon to identify the disc
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Attempting to identify disc type"
    local disc_info=$(makemkvcon -r --cache=1 info disc:0 2>/dev/null)
    
    # Look for BD-Video pattern
    if echo "$disc_info" | grep -q "BD-Video"; then
        DISC_TYPE="BD-Video"
        # Try to extract disc label
        DISC_LABEL=$(echo "$disc_info" | grep "Volume Label" | sed 's/.*: //')
        [ -z "$DISC_LABEL" ] && DISC_LABEL="BluRay-$(date +%Y%m%d-%H%M%S)"
        LAST_DISC_STATE="ready"
        return 0
    fi
    
    # Look for DVD-Video pattern
    if echo "$disc_info" | grep -q "DVD-Video"; then
        DISC_TYPE="DVD-Video"
        # Try to extract disc label
        DISC_LABEL=$(echo "$disc_info" | grep "Volume Label" | sed 's/.*: //')
        [ -z "$DISC_LABEL" ] && DISC_LABEL="DVD-$(date +%Y%m%d-%H%M%S)"
        LAST_DISC_STATE="ready"
        return 0
    fi
    
    # Check for audio CD
    if blkid "$DRIVE" | grep -q "TYPE=\"udf\"" || cdparanoia -Q 2>/dev/null | grep -q "audio tracks"; then
        DISC_TYPE="Audio-CD"
        # Try to get CD title
        DISC_LABEL=$(cd-discid "$DRIVE" 2>/dev/null | head -n 1)
        [ -z "$DISC_LABEL" ] && DISC_LABEL="CD-$(date +%Y%m%d-%H%M%S)"
        LAST_DISC_STATE="ready"
        return 0
    fi
    
    # Assume data disc if mounted
    if mount | grep -q "$DRIVE"; then
        DISC_TYPE="Data-Disc"
        # Try to get volume label
        DISC_LABEL=$(blkid -o value -s LABEL "$DRIVE" 2>/dev/null)
        [ -z "$DISC_LABEL" ] && DISC_LABEL="Data-$(date +%Y%m%d-%H%M%S)"
        LAST_DISC_STATE="ready"
        return 0
    fi
    
    # If we got here, disc type is unknown or drive not ready
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Unknown disc type or drive not ready yet"
    LAST_DISC_STATE="loading"
    return 1
}

# Function to create timestamp prefix if enabled
get_timestamp_prefix() {
    if [ "$TIMESTAMPPREFIX" = "true" ]; then
        echo "$(date +%Y%m%d-%H%M%S)_"
    else
        echo ""
    fi
}

# Function to handle BluRay ripping
rip_bluray() {
    local timestamp_prefix=$(get_timestamp_prefix)
    local output_dir="${STORAGE_BD}/${timestamp_prefix}${DISC_LABEL}"
    
    echo "# Starting BluRay rip of \"${DISC_LABEL}\" at $(date)"
    
    # Send notification that ripping has started
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Started" "Starting to rip BluRay disc: ${DISC_LABEL}"
    fi
    
    START_TIME=$(date +%s)
    
    if [ "$JUSTMAKEISO" = "true" ]; then
        # Create ISO only
        mkdir -p "$output_dir"
        OUTPUT_PATH="${output_dir}/${DISC_LABEL}.iso"
        
        echo "# Creating ISO image at ${OUTPUT_PATH}"
        
        ddrescue -d -b 2048 -n -v "$DRIVE" "$OUTPUT_PATH" "${output_dir}/ddrescue.log"
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo "# Error creating ISO image, exit code: $exit_code"
            
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Failed to create ISO image for BluRay disc: ${DISC_LABEL}"
            fi
            
            return 1
        fi
    else
        # Use MakeMKV for full rip
        mkdir -p "$output_dir"
        OUTPUT_PATH="$output_dir"
        
        echo "# Ripping BluRay to ${OUTPUT_PATH} using MakeMKV"
        
        # Only rip titles longer than minimum length
        makemkvcon --minlength="$MINIMUMLENGTH" -r --progress=-same mkv disc:0 all "$output_dir" 2>&1
        local exit_code=$?
        
        if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
            echo "# Error ripping BluRay, exit code: $exit_code"
            
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Failed to rip BluRay disc: ${DISC_LABEL} (Exit code: $exit_code)"
            fi
            
            return 1
        fi
        
        # Create ISO if requested
        if [ "$ALSOMAKEISO" = "true" ]; then
            echo "# Creating additional ISO image"
            ddrescue -d -b 2048 -n -v "$DRIVE" "${output_dir}/${DISC_LABEL}.iso" "${output_dir}/ddrescue.log"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo "# BluRay rip completed in $(date -d@$duration -u +%H:%M:%S) at $(date)"
    
    # Send completion notification
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Completed" "Successfully ripped BluRay disc: ${DISC_LABEL}\nOutput: ${OUTPUT_PATH}\nTime taken: $(date -d@$duration -u +%H:%M:%S)"
    fi
    
    return 0
}

# Function to handle DVD ripping
rip_dvd() {
    local timestamp_prefix=$(get_timestamp_prefix)
    local output_dir="${STORAGE_DVD}/${timestamp_prefix}${DISC_LABEL}"
    
    echo "# Starting DVD rip of \"${DISC_LABEL}\" at $(date)"
    
    # Send notification that ripping has started
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Started" "Starting to rip DVD disc: ${DISC_LABEL}"
    fi
    
    START_TIME=$(date +%s)
    
    if [ "$JUSTMAKEISO" = "true" ]; then
        # Create ISO only
        mkdir -p "$output_dir"
        OUTPUT_PATH="${output_dir}/${DISC_LABEL}.iso"
        
        echo "# Creating ISO image at ${OUTPUT_PATH}"
        
        ddrescue -d -b 2048 -n -v "$DRIVE" "$OUTPUT_PATH" "${output_dir}/ddrescue.log"
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo "# Error creating ISO image, exit code: $exit_code"
            
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Failed to create ISO image for DVD disc: ${DISC_LABEL}"
            fi
            
            return 1
        fi
    else
        # Use MakeMKV for full rip
        mkdir -p "$output_dir"
        OUTPUT_PATH="$output_dir"
        
        echo "# Ripping DVD to ${OUTPUT_PATH} using MakeMKV"
        
        # Only rip titles longer than minimum length
        makemkvcon --minlength="$MINIMUMLENGTH" -r --progress=-same mkv disc:0 all "$output_dir" 2>&1
        local exit_code=$?
        
        if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
            echo "# Error ripping DVD, exit code: $exit_code"
            
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Failed to rip DVD disc: ${DISC_LABEL} (Exit code: $exit_code)"
            fi
            
            return 1
        fi
        
        # Create ISO if requested
        if [ "$ALSOMAKEISO" = "true" ]; then
            echo "# Creating additional ISO image"
            ddrescue -d -b 2048 -n -v "$DRIVE" "${output_dir}/${DISC_LABEL}.iso" "${output_dir}/ddrescue.log"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo "# DVD rip completed in $(date -d@$duration -u +%H:%M:%S) at $(date)"
    
    # Send completion notification
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Completed" "Successfully ripped DVD disc: ${DISC_LABEL}\nOutput: ${OUTPUT_PATH}\nTime taken: $(date -d@$duration -u +%H:%M:%S)"
    fi
    
    return 0
}

# Function to handle Audio CD ripping
rip_cd() {
    local timestamp_prefix=$(get_timestamp_prefix)
    local output_dir="${STORAGE_CD}/${timestamp_prefix}${DISC_LABEL}"
    
    echo "# Starting Audio CD rip of \"${DISC_LABEL}\" at $(date)"
    
    # Send notification that ripping has started
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Started" "Starting to rip Audio CD: ${DISC_LABEL}"
    fi
    
    START_TIME=$(date +%s)
    
    if [ "$JUSTMAKEISO" = "true" ]; then
        # Create ISO only
        mkdir -p "$output_dir"
        OUTPUT_PATH="${output_dir}/${DISC_LABEL}.iso"
        
        echo "# Creating ISO image at ${OUTPUT_PATH}"
        
        ddrescue -d -b 2048 -n -v "$DRIVE" "$OUTPUT_PATH" "${output_dir}/ddrescue.log"
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo "# Error creating ISO image, exit code: $exit_code"
            
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Failed to create ISO image for Audio CD: ${DISC_LABEL}"
            fi
            
            return 1
        fi
    else
        # Use abcde for full CD ripping
        mkdir -p "$output_dir"
        OUTPUT_PATH="$output_dir"
        
        echo "# Ripping Audio CD to ${OUTPUT_PATH} using abcde"
        
        # Use abcde to rip CD
        cd "$output_dir" && abcde -d "$DRIVE" -o mp3,flac -V -x 2>&1
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo "# Error ripping Audio CD, exit code: $exit_code"
            
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Failed to rip Audio CD: ${DISC_LABEL} (Exit code: $exit_code)"
            fi
            
            return 1
        fi
        
        # Create ISO if requested
        if [ "$ALSOMAKEISO" = "true" ]; then
            echo "# Creating additional ISO image"
            ddrescue -d -b 2048 -n -v "$DRIVE" "${output_dir}/${DISC_LABEL}.iso" "${output_dir}/ddrescue.log"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo "# Audio CD rip completed in $(date -d@$duration -u +%H:%M:%S) at $(date)"
    
    # Send completion notification
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Completed" "Successfully ripped Audio CD: ${DISC_LABEL}\nOutput: ${OUTPUT_PATH}\nTime taken: $(date -d@$duration -u +%H:%M:%S)"
    fi
    
    return 0
}

# Function to handle Data disc ripping
rip_data() {
    local timestamp_prefix=$(get_timestamp_prefix)
    local output_dir="${STORAGE_DATA}/${timestamp_prefix}${DISC_LABEL}"
    
    echo "# Starting Data disc rip of \"${DISC_LABEL}\" at $(date)"
    
    # Send notification that ripping has started
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Started" "Starting to rip Data disc: ${DISC_LABEL}"
    fi
    
    START_TIME=$(date +%s)
    
    # Create ISO image
    mkdir -p "$output_dir"
    OUTPUT_PATH="${output_dir}/${DISC_LABEL}.iso"
    
    echo "# Creating ISO image at ${OUTPUT_PATH}"
    
    ddrescue -d -b 2048 -n -v "$DRIVE" "$OUTPUT_PATH" "${output_dir}/ddrescue.log"
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "# Error creating ISO image, exit code: $exit_code"
        
        if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
            notify_error "Rip Error" "Failed to create ISO image for Data disc: ${DISC_LABEL}"
        fi
        
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo "# Data disc rip completed in $(date -d@$duration -u +%H:%M:%S) at $(date)"
    
    # Send completion notification
    if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
        notify_info "Rip Completed" "Successfully ripped Data disc: ${DISC_LABEL}\nOutput: ${OUTPUT_PATH}\nTime taken: $(date -d@$duration -u +%H:%M:%S)"
    fi
    
    return 0
}

# Function to eject disc
eject_disc() {
    if [ "$EJECTENABLED" = "true" ]; then
        echo "# Ejecting disc"
        eject "$DRIVE"
        sleep 5
        LAST_DISC_STATE="empty"
    fi
}

# Function to check for override scripts
check_override_script() {
    local disc_type="$1"
    local script_name=""
    
    case "$disc_type" in
        "BD-Video") script_name="BLURAYrip.sh" ;;
        "DVD-Video") script_name="DVDrip.sh" ;;
        "Audio-CD") script_name="CDrip.sh" ;;
        "Data-Disc") script_name="DATArip.sh" ;;
    esac
    
    if [ -n "$script_name" ] && [ -x "/config/$script_name" ]; then
        echo "# Found override script for $disc_type: $script_name"
        
        # Send notification about using override script
        if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
            notify_info "Using Override Script" "Using custom script for ${disc_type}: ${script_name}"
        fi
        
        # Execute the override script
        cd /config && "./$script_name"
        local exit_code=$?
        
        # Send notification based on result
        if [ $exit_code -eq 0 ]; then
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_info "Rip Completed" "Custom script for ${disc_type} completed successfully"
            fi
        else
            if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                notify_error "Rip Error" "Custom script for ${disc_type} failed with exit code: $exit_code"
            fi
        fi
        
        return 0
    fi
    
    return 1
}

# Main function to detect optical discs and process them
process_discs() {
    [ "$DEBUG" = "true" ] && echo "[DEBUG] Starting disc detection loop"
    
    # Create necessary directories
    create_directories
    
    # Main processing loop
    while true; do
        # Skip if already processing a disc
        if [ "$PROCESSING" = true ]; then
            sleep 10
            continue
        fi
        
        # Try to detect disc type
        if ! detect_disc_type; then
            # No disc or not ready
            sleep 5
            BAD_READS=$((BAD_READS + 1))
            
            if [ $BAD_READS -gt "$BAD_THRESHOLD" ]; then
                BAD_READS=0
                LAST_DISC_STATE="empty"
                [ "$DEBUG" = "true" ] && echo "[DEBUG] Bad read threshold reached, resetting state"
            fi
            
            continue
        fi
        
        # Reset bad reads counter
        BAD_READS=0
        
        # Check if disc is ready to process
        if [ "$LAST_DISC_STATE" != "ready" ]; then
            [ "$DEBUG" = "true" ] && echo "[DEBUG] Disc not ready yet, waiting..."
            sleep 5
            continue
        fi
        
        echo "# Detected $DISC_TYPE: \"$DISC_LABEL\" at $(date)"
        
        # Send notification about disc detection
        if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
            notify_info "Disc Detected" "Detected ${DISC_TYPE} disc: ${DISC_LABEL}"
        fi
        
        # Set processing flag
        PROCESSING=true
        
        # Check for override script
        if check_override_script "$DISC_TYPE"; then
            # Override script took care of processing
            PROCESSING=false
            eject_disc
            continue
        fi
        
        # Process based on disc type
        case "$DISC_TYPE" in
            "BD-Video")
                rip_bluray
                ;;
            "DVD-Video")
                rip_dvd
                ;;
            "Audio-CD")
                rip_cd
                ;;
            "Data-Disc")
                rip_data
                ;;
            *)
                echo "# Unknown disc type: $DISC_TYPE"
                if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
                    notify_warning "Unknown Disc Type" "Cannot process unknown disc type: ${DISC_TYPE}"
                fi
                ;;
        esac
        
        # Reset processing flag
        PROCESSING=false
        
        # Eject disc if enabled
        eject_disc
    done
}

# Script entry point
echo "# Docker-Ripper started at $(date)"

# Check for notification system
if [ "$NOTIFICATIONS_AVAILABLE" = true ]; then
    echo "# Notification system available and initialized"
else
    echo "# Notification system not available"
fi

# Start processing discs
process_discs