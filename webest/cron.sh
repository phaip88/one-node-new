#!/bin/bash

# Clear log file
> /home/$USER/app/backup.log

# Function to restart Node.js application
restart_nodejs_app() {
    echo "$(date) -- Attempting to restart Node.js application"
    
    # Kill all Node.js processes related to our app
    DOMAIN_DIR="/home/$USER/domains/YOUR_DOMAIN/public_html"
    
    # Find and kill processes running our app.js
    APP_PIDS=($(pgrep -f "$DOMAIN_DIR/app.js"))
    if [ ${#APP_PIDS[@]} -gt 0 ]; then
        echo "Found ${#APP_PIDS[@]} app.js processes, killing them..."
        for pid in "${APP_PIDS[@]}"; do
            echo "Killing app.js process PID $pid"
            kill -TERM "$pid" 2>/dev/null
            sleep 2
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                echo "Force killing PID $pid"
                kill -KILL "$pid" 2>/dev/null
            fi
        done
    fi
    
    # Also kill any lsnode processes
    LSNODE_PIDS=($(pgrep "lsnode"))
    if [ ${#LSNODE_PIDS[@]} -gt 0 ]; then
        echo "Found ${#LSNODE_PIDS[@]} lsnode processes, killing them..."
        for pid in "${LSNODE_PIDS[@]}"; do
            echo "Killing lsnode process PID $pid"
            kill -TERM "$pid" 2>/dev/null
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null
            fi
        done
    fi
    
    # Wait a moment for processes to clean up
    sleep 3
    
    # Restart the application using CloudLinux Selector
    echo "Restarting Node.js application..."
    if [ -f "/home/$USER/cx" ]; then
        /home/$USER/cx restart --json --user=$(whoami) --app-root="$DOMAIN_DIR" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Application restarted successfully via CloudLinux Selector"
        else
            echo "Failed to restart via CloudLinux Selector, trying manual restart..."
            # Manual restart fallback
            cd "$DOMAIN_DIR"
            nohup /home/$USER/nodevenv/domains/YOUR_DOMAIN/public_html/22/bin/node app.js > /dev/null 2>&1 &
            echo "Manual restart attempted"
        fi
    else
        echo "CloudLinux Selector not found, trying manual restart..."
        cd "$DOMAIN_DIR"
        nohup /home/$USER/nodevenv/domains/YOUR_DOMAIN/public_html/22/bin/node app.js > /dev/null 2>&1 &
        echo "Manual restart attempted"
    fi
    
    # Wait for application to start
    sleep 5
}

# Enhanced health check with retry and restart logic
perform_health_check() {
    local max_retries=3
    local retry_count=0
    local health_check_url="https://YOUR_DOMAIN/hello"
    
    echo "$(date) -- Starting health check for $health_check_url"
    
    while [ $retry_count -lt $max_retries ]; do
        echo "Health check attempt $((retry_count + 1))/$max_retries"
        
        # Perform health check with timeout
        if curl -f -s --max-time 10 "$health_check_url" > /dev/null 2>&1; then
            echo "✅ Health check PASSED"
            return 0
        else
            echo "❌ Health check FAILED (attempt $((retry_count + 1)))"
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                echo "Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    
    echo "🚨 Health check failed after $max_retries attempts, triggering restart"
    return 1
}

# Perform health check
if ! perform_health_check; then
    restart_nodejs_app
    
    # Verify restart was successful
    echo "Waiting 15 seconds for application to fully start..."
    sleep 15
    
    echo "$(date) -- Verifying restart was successful"
    if curl -f -s --max-time 10 "https://YOUR_DOMAIN/hello" > /dev/null 2>&1; then
        echo "✅ Application restart SUCCESSFUL"
    else
        echo "❌ Application restart FAILED - manual intervention required"
        echo "🔧 Troubleshooting steps:"
        echo "   1. Check disk space: df -h"
        echo "   2. Check memory usage: free -m"
        echo "   3. Check application logs in $DOMAIN_DIR"
        echo "   4. Verify Node.js environment: /home/$USER/nodevenv/domains/YOUR_DOMAIN/public_html/22/bin/node --version"
    fi
fi

# Cleaning disk space
echo "$(date) -- Cleaning disk space"
rm -rf /home/$USER/Maildir/* 2>/dev/null

# Enhanced process cleaning with better logic
echo "$(date) -- Checking for duplicate processes"
PROCESS_NAME="lsnode"
PIDS=($(pgrep "$PROCESS_NAME"))

if [ ${#PIDS[@]} -eq 0 ]; then
    echo "No $PROCESS_NAME processes found"
elif [ ${#PIDS[@]} -eq 1 ]; then
    echo "Process count is ${#PIDS[@]}, optimal state"
else
    echo "Found ${#PIDS[@]} instances of $PROCESS_NAME, cleaning up duplicates"
    
    declare -A START_TIMES
    for pid in "${PIDS[@]}"; do
        if [ -f "/proc/$pid/stat" ]; then
            START_TICKS=$(awk '{print $22}' /proc/$pid/stat 2>/dev/null)
            if [ -n "$START_TICKS" ]; then
                HZ=$(getconf CLK_TCK)
                BOOT_TIME=$(awk '/btime/ {print $2}' /proc/stat)
                START_SECONDS=$((BOOT_TIME + START_TICKS / HZ))
                START_TIMES[$pid]=$START_SECONDS
            fi
        fi
    done
    
    if [ ${#START_TIMES[@]} -gt 1 ]; then
        SORTED_PIDS=($(for pid in "${!START_TIMES[@]}"; do
            echo "$pid ${START_TIMES[$pid]}"
        done | sort -k2n | awk '{print $1}'))
        
        # Kill all but the newest process
        for ((i=0; i<${#SORTED_PIDS[@]}-1; i++)); do
            OLD_PID=${SORTED_PIDS[$i]}
            echo "Killing old $PROCESS_NAME process PID $OLD_PID"
            kill -TERM "$OLD_PID" 2>/dev/null
            sleep 1
            # Force kill if still running
            if kill -0 "$OLD_PID" 2>/dev/null; then
                kill -KILL "$OLD_PID" 2>/dev/null
            fi
        done
        
        echo "Cleanup complete. Remaining PID: ${SORTED_PIDS[-1]}"
    fi
fi

echo "$(date) -- Cron job completed"
