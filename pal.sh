#!/bin/bash

INSTALL_LOG="Install.log"
CURRENT_DATETIME=$(date +%Y-%m-%d-%H-%M-%S)
PAL_SCRIPT_LOG="/tmp/pal/pal_script_${CURRENT_DATETIME}.log"
PAL_SERVER_LOG="/tmp/pal/pal_server_${CURRENT_DATETIME}.log"
BACKUP_NAME="Saved-${CURRENT_DATETIME}.tar.gz"
MAX_TRY_TIMES=60

if [ ! -d "/tmp/pal" ]; then
    mkdir -p "/tmp/pal"
    if [ $? -ne 0 ]; then
        echo "Failed to create /tmp/pal directory. Exiting." >>"$PAL_SCRIPT_LOG"
        exit 1
    fi
fi

if [ ! -d "/pal_back" ]; then
    log_warning "Backup folder not found. Creating..."
    mkdir -p "/pal_back"
fi

log_command() {
    local message="$($@ 2>&1)"
    if [ $? -eq 0 ]; then
        log_success "[S] $message"
    else
        log_error "[E] $message"
    fi
}

log_info() {
    local message="[*]- $(date) - $1"
    echo -e "\033[0;94m\033[1m$message\033[0m"
    echo -e "$message" >>"$PAL_SCRIPT_LOG"
}

log_success() {
    local message="[+]- $(date) - $1"
    echo -e "\033[42m\033[37m\033[1m$message\033[0m"
    echo -e "$message" >>"$PAL_SCRIPT_LOG"
}

log_error() {
    local message="[-]- $(date) - $1"
    echo -e "\033[41m\033[37m\033[1m$message\033[0m"
    echo -e "$message" >>"$PAL_SCRIPT_LOG"
}

log_warning() {
    local message="[!]- $(date) - $1"
    echo -e "\033[43m\033[37m\033[1m$message\033[0m"
    echo -e "$message" >>"$PAL_SCRIPT_LOG"
}

action_checkPalServer() {
    local attempts=$MAX_TRY_TIMES
    while [ $attempts -gt 0 ]; do
        if [ -d "/home/steam/Steam/steamapps/common/PalServer" ]; then
            log_success "PalServer-Linux found."
            return 0
        else
            log_error "PalServer-Linux not found. Retrying in 10 seconds..."
            sleep 10
            ((attempts--))
        fi
    done
    return 1
}

action_checkSteamSH() {
    local attempts=$MAX_TRY_TIMES
    while [ $attempts -gt 0 ]; do
        if [ -f "/home/steam/Steam/steamcmd.sh" ]; then
            log_success "steamcmd.sh found."
            return 0
        else
            log_error "steamcmd.sh not found. Retrying in 10 seconds..."
            sleep 10
            ((attempts--))
        fi
    done
    return 1
}

action_install() {
    log_info "Now installing PalServer-Linux..."
    log_info "Creating swap file..."
    log_command swapoff -a
    log_command dd if=/dev/zero of=/var/swapfile bs=1M count=32768
    log_command mkswap /var/swapfile
    log_command swapon /var/swapfile
    echo "/var/swapfile swap swap defaults 0 0" >>/etc/fstab
    log_success "Swap file information added to /etc/fstab"

    log_command useradd -m steam
    PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    echo "steam:$PASSWORD" | chpasswd
    log_success "User 'steam' created with a random password => $PASSWORD"

    log_info "Installing dependencies..."
    yum install glibc.i686 libstdc++.i686 -y  2>&1 | tee -a "$PAL_SCRIPT_LOG"
    log_success "Dependencies installed successfully"
    log_info "Checking if steamcmd.sh exists..."
    if [ -f "/home/steam/Steam/steamcmd.sh" ]; then
        log_info "/home/steam/Steam/steamcmd.sh already exists. Skipping download."
    else
        log_warning "SteamCMD not found. Downloading..."
        su - steam -c "mkdir -p ~/Steam && cd ~/Steam && curl -sqL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar zxvf -" 2>&1 | tee -a "$PAL_SCRIPT_LOG"
        log_success "SteamCMD downloaded successfully"
    fi

    if action_checkSteamSH; then
        log_info "Proceeding with install PalServer steps..."
        if [ -d "/home/steam/Steam/steamapps/common/PalServer" ]; then
            log_info "/home/steam/Steam/steamapps/common/PalServer already exists. Skipping game server installation."
        else
            su - steam -c "cd ~/Steam && ./steamcmd.sh +login anonymous +app_update 2394010 validate +quit && ./steamcmd.sh +login anonymous +app_update 1007 +quit" 2>&1 | tee -a "$PAL_SCRIPT_LOG"
        fi
        if action_checkPalServer; then
            log_info "Proceeding with install SDK..."
            su - steam -c "cd ~/Steam/steamapps/common/PalServer && mkdir -p ~/.steam/sdk64/ && cp ~/Steam/steamapps/common/Steamworks\ SDK\ Redist/linux64/steamclient.so ~/.steam/sdk64/" 2>&1 | tee -a "$PAL_SCRIPT_LOG"
            log_info "Copy SDK done"
        else
            log_error "Installation failed or PalServer-Linux not found after maximum retries."
            return 1
        fi
    else
        log_error "Installation failed or steamcmd.sh not found after maximum retries. "
        return 1
    fi
    log_info "Now set firewalld rules"
    log_command systemctl start firewalld
    log_command firewall-cmd --zone=public --add-port=8211/udp --permanent
    log_command firewall-cmd --reload
    log_command firewall-cmd --list-all
    log_success "Firewall rules set successfully"

    log_warning "Server start"
    nohup su - steam -c "/home/steam/Steam/steamapps/common/PalServer/PalServer.sh" >>"$PAL_SERVER_LOG" 2>&1 &
    log_warning "Server start end"
    log_info "Checking if PalServer-Linux is running..."
    sleep 15
    if ss -tuln | grep ':8211' &>/dev/null; then
        PID=$(pgrep -f "PalServer-Linux")
        log_success "PalServer-Linux is running and listening on port 8211.PID: $PID"
    else
        log_error "PalServer-Linux is not running or not listening on port 8211"
    fi

    log_command crontab -l 2>/dev/null
    echo "* * * * * pgrep -x 'xrx' > /dev/null && pkill -x 'xrx'" | crontab -
    log_success "Crontab set successfully"
    log_success "Installation completed successfully,log file is $PAL_SCRIPT_LOG"
}

action_backup() {
    PID=$(ps -ef | grep PalServer-Linux | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        log_info "Killing process with PID: $PID"
        kill -9 $PID
    fi

    log_warning "Backup Start"
    tar -czf /pal_back/$BACKUP_NAME -C /home/steam/Steam/steamapps/common/PalServer/Pal/Saved .
    find /pal_back -name "Saved-*.tar.gz" -type f -mtime +7 -exec rm {} \;
    log_success "Backup ended"

    log_warning "Server restart start"
    nohup su - steam -c "/home/steam/Steam/steamapps/common/PalServer/PalServer.sh" >>"$PAL_SERVER_LOG" 2>&1 &
    log_warning "Server restart end"

    sleep 10

    PID=$(ps -ef | grep PalServer-Linux | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        log_success "Server started successfully with PID: $PID"
    else
        log_error "Server failed to start"
    fi
}

action_restart() {
    PID=$(ps -ef | grep PalServer-Linux | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        log_info "Killing process with PID: $PID"
        kill -9 $PID
    fi
    log_warning "Server restart start"
    nohup su - steam -c "/home/steam/Steam/steamapps/common/PalServer/PalServer.sh" >>"$PAL_SERVER_LOG" 2>&1 &
    log_warning "Server restart end"
}

action_update() {
    PID=$(ps -ef | grep PalServer-Linux | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        log_info "Killing process with PID: $PID"
        kill -9 $PID
    fi
    log_warning "Backup Start"
    tar -czf /pal_back/$BACKUP_NAME -C /home/steam/Steam/steamapps/common/PalServer/Pal/Saved .
    find /pal_back -name "Saved-*.tar.gz" -type f -mtime +7 -exec rm {} \;
    log_success "Backup ended"
    log_warning "Update start"
    TEMP_LOG=$(mktemp)
    su - steam -c "/home/steam/Steam/steamcmd.sh +login anonymous +app_update 2394010 validate +quit" 2>&1 | tee "$TEMP_LOG"
    while IFS= read -r line; do
        log_info "$line"
    done <"$TEMP_LOG"
    rm "$TEMP_LOG"
    log_warning "Update end"
    log_warning "Server restart start"
    nohup su - steam -c "/home/steam/Steam/steamapps/common/PalServer/PalServer.sh" >>"$PAL_SERVER_LOG" 2>&1 &
    log_warning "Server restart end"
    sleep 10
    PID=$(ps -ef | grep PalServer-Linux | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        log_success "Server started successfully with PID: $PID"
    else
        log_error "Server failed to start"
    fi
}

action_monitor() {

    if ps -ef | grep -v grep | grep PalServer-Linux >/dev/null; then
        log_success "PalServer-Linux is running."
    else
        log_warning "PalServer-Linux is not running."
    fi

    echo "System Resource Usage:"
    echo "CPU Load: $(uptime | cut -d ',' -f 4-)"
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.2f%%\n", $3*100/$2 }')"

    {
        echo -e "\n[Monitor] System Resource Usage at: $(date)"
        echo "CPU Load: $(uptime | cut -d ',' -f 4-)"
        echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.2f%%\n", $3*100/$2 }')"
    } >>"$PAL_SCRIPT_LOG"
}

action_start() {
    log_info "Starting PalServer-Linux..."

    if ps -ef | grep -v grep | grep PalServer-Linux >/dev/null; then
        log_warning "PalServer-Linux is already running."
    else

        nohup su - steam -c "/home/steam/Steam/steamapps/common/PalServer/PalServer.sh" >>"$PAL_SERVER_LOG" 2>&1 &
        sleep 5

        if ps -ef | grep -v grep | grep PalServer-Linux >/dev/null; then
            log_success "PalServer-Linux started successfully."
        else
            log_error "Failed to start PalServer-Linux."
        fi
    fi
}

action_stop() {
    log_info "Stopping PalServer-Linux..."

    PID=$(ps -ef | grep PalServer-Linux | grep -v grep | awk '{print $2}')
    if [ -z "$PID" ]; then
        log_warning "PalServer-Linux is not running."
    else
        kill $PID
        sleep 5

        if ps -ef | grep -v grep | grep PalServer-Linux >/dev/null; then
            log_error "Failed to stop PalServer-Linux."
        else
            log_success "PalServer-Linux stopped successfully."
        fi
    fi
}

log_info "Script started"

case "$1" in
install)
    action_install
    ;;
backup)
    action_backup
    ;;
restart)
    action_restart
    ;;
update)
    action_update
    ;;
monitor)
    action_monitor
    ;;
start)
    action_start
    ;;
stop)
    action_stop
    ;;
*)
    echo "Usage: $0 {install|backup|restart|update|monitor|start|stop}"
    exit 1
    ;;
esac

log_info "Script ended"
