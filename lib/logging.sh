#!/bin/bash
#
# Logging functions for Linux Setup System
#

# Global logging variables
LOG_FILE=""
LOG_LEVEL="INFO"

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Function to setup logging
setup_logging() {
    local script_name="$1"
    local log_level="${2:-INFO}"
    
    # Ensure log directory exists
    create_directory "$LOG_DIR"
    
    # Create log file with timestamp
    LOG_FILE="$LOG_DIR/${script_name}-$(date +%Y%m%d-%H%M%S).log"
    LOG_LEVEL="$log_level"
    
    # Initialize log file
    cat > "$LOG_FILE" << EOF
================================================================================
Linux Setup System Log
================================================================================
Script: $script_name
Started: $(date '+%Y-%m-%d %H:%M:%S')
User: $(whoami)
Host: $(hostname)
Working Directory: $(pwd)
================================================================================

EOF
    
    # Set log file permissions
    chmod 644 "$LOG_FILE"
    
    log_info "Logging initialized: $LOG_FILE"
}

# Function to get log level number
get_log_level_number() {
    local level="$1"
    
    case "$level" in
        "DEBUG") echo $LOG_LEVEL_DEBUG ;;
        "INFO") echo $LOG_LEVEL_INFO ;;
        "WARN") echo $LOG_LEVEL_WARN ;;
        "ERROR") echo $LOG_LEVEL_ERROR ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# Function to write log message
write_log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Check if we should log this level
    local current_level_num=$(get_log_level_number "$LOG_LEVEL")
    local message_level_num=$(get_log_level_number "$level")
    
    if [[ $message_level_num -ge $current_level_num ]]; then
        # Write to log file
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
        
        # Also output to console for errors and warnings
        if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
            echo "[$timestamp] [$level] $message" >&2
        fi
    fi
}

# Specific logging functions
log_debug() {
    write_log "DEBUG" "$1"
}

log_info() {
    write_log "INFO" "$1"
}

log_warn() {
    write_log "WARN" "$1"
}

log_error() {
    write_log "ERROR" "$1"
}

# Function to log command execution
log_command() {
    local command="$1"
    local description="${2:-Executing command}"
    
    log_info "$description: $command"
    
    # Execute command and capture output
    local output
    local exit_code
    
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Command succeeded: $command"
        if [[ -n "$output" ]]; then
            log_debug "Command output: $output"
        fi
    else
        log_error "Command failed (exit code: $exit_code): $command"
        if [[ -n "$output" ]]; then
            log_error "Command output: $output"
        fi
    fi
    
    return $exit_code
}

# Function to log system information
log_system_info() {
    log_info "System Information:"
    log_info "  OS: $(uname -s)"
    log_info "  Kernel: $(uname -r)"
    log_info "  Architecture: $(uname -m)"
    log_info "  Hostname: $(hostname)"
    log_info "  Uptime: $(get_uptime)"
    log_info "  Memory: $(get_memory_info)"
    log_info "  Disk: $(get_disk_info)"
    log_info "  Primary IP: $(get_primary_ip)"
}

# Function to log function entry/exit
log_function_enter() {
    local function_name="$1"
    log_debug "Entering function: $function_name"
}

log_function_exit() {
    local function_name="$1"
    local exit_code="${2:-0}"
    log_debug "Exiting function: $function_name (exit code: $exit_code)"
}

# Function to create log archive
archive_logs() {
    local archive_dir="$LOG_DIR/archive"
    local max_age_days="${1:-30}"
    
    create_directory "$archive_dir"
    
    # Find and compress old log files
    find "$LOG_DIR" -name "*.log" -type f -mtime +$max_age_days -not -path "$archive_dir/*" | while read -r logfile; do
        if [[ -f "$logfile" ]]; then
            local basename=$(basename "$logfile")
            local archive_name="$archive_dir/${basename}.$(date +%Y%m%d).gz"
            
            if gzip -c "$logfile" > "$archive_name"; then
                rm "$logfile"
                log_info "Archived log file: $logfile -> $archive_name"
            else
                log_error "Failed to archive log file: $logfile"
            fi
        fi
    done
}

# Function to cleanup old logs
cleanup_logs() {
    local max_archive_days="${1:-90}"
    local archive_dir="$LOG_DIR/archive"
    
    if [[ -d "$archive_dir" ]]; then
        find "$archive_dir" -name "*.gz" -type f -mtime +$max_archive_days -delete
        log_info "Cleaned up archived logs older than $max_archive_days days"
    fi
}

# Function to get log file size
get_log_size() {
    if [[ -f "$LOG_FILE" ]]; then
        du -h "$LOG_FILE" | cut -f1
    else
        echo "0"
    fi
}

# Function to rotate logs if they get too large
rotate_log_if_needed() {
    local max_size_mb="${1:-10}"
    
    if [[ -f "$LOG_FILE" ]]; then
        local size_mb=$(du -m "$LOG_FILE" | cut -f1)
        
        if [[ $size_mb -gt $max_size_mb ]]; then
            local rotated_name="${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
            mv "$LOG_FILE" "$rotated_name"
            
            # Restart logging
            setup_logging "$(basename "${LOG_FILE%%-*}")" "$LOG_LEVEL"
            log_info "Log rotated: $rotated_name"
        fi
    fi
}