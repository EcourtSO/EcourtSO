if [ "$EUID" -ne 0 ]; then
    echo -e "\e[31mPlease run this script as root (sudo ./script.sh)\e[0m"
    exit 1
fi


#!/bin/bash

# === Global Setup ===
curdt=$(date +%d-%m-%Y)
bold_red="\e[1m\e[31m"
bold_green="\e[1m\e[32m"
reset="\e[0m"
log_file="install_script_${curdt}.log"

log() {
    local message="$1"
    local print_to_shell="$2"
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') - $message"
    echo "$log_entry" >> "$log_file"
    if [ "$print_to_shell" == "true" ]; then
        echo "$log_entry"
    fi
}


# === Dependency Check ===
check_dependency() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${bold_red}${cmd}${reset} could not be found, please install it."
            exit 1
        fi
    done
}

# === Confirmation ===
confirm() {
    read -p "Are you sure you want to proceed? [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) true ;;
        *) false ;;
    esac
}

# === Unzip Support Files ===
zip_files() {
    if [ -d "./files" ]; then
        echo "Files already extracted. Using existing files."
    elif [ -f "files.zip" ]; then
        echo "Extracting files.zip..."
        unzip -q files.zip
    else
        echo "Downloading offline files.zip..."
        wget -q https://raw.githubusercontent.com/EcourtSO/EcourtSO/main/files.zip
        unzip -q files.zip
    fi
}

# === Task Functions ===
install_naps() {
    echo "Installing NAPS Scanner..."
    if confirm; then
        local keyring_path="/etc/apt/keyrings/naps2.gpg"
        [ ! -f "$keyring_path" ] && curl -fsSL https://www.naps2.com/naps2-public.pgp | sudo gpg --dearmor -o "$keyring_path"
        grep -q "^deb .*naps2" /etc/apt/sources.list.d/naps2.list 2>/dev/null || \
        echo "deb [signed-by=$keyring_path] https://downloads.naps2.com ./" | sudo tee /etc/apt/sources.list.d/naps2.list >/dev/null
        sudo apt update && sudo apt install -y naps2 && log "NAPS2 installed successfully" true || { log "Failed to install NAPS2" true; exit 1; }
    fi
}

install_epson() {
    echo "Installing Epson Drivers..."
    if confirm; then
        sudo apt update && sudo apt install -y lsb lsb-core
        zip_files
        sudo dpkg -i ./files/epson-inkjet-printer-escpr2_*.deb
        sudo sh ./files/epsonscan2-bundle-*.deb/install.sh
        sudo apt purge ipp-usb -y
        log "Epson drivers installed successfully" true
    fi
}

install_fijustu() {
    echo "Installing Fujitsu Driver..."
    if confirm; then
        zip_files
        sudo dpkg -i ./files/pfufs-ubuntu_*.deb && log "Fujitsu driver installed" true
    fi
}

install_apps() {
    echo "📦 Installing basic required applications..."

    if ! confirm; then
        log "User cancelled basic app installation" true
        return 0
    fi

    log "Starting basic app installation" true

    if ! sudo apt update; then
        log "apt update failed" true
        echo "❌ Failed to update package list"
        return 1
    fi

    APPS=(
        # System & networking
        openssh-server
        net-tools
        curl
        wget
        gnupg
        ca-certificates
        software-properties-common

        # Archive tools
        zip
        unzip
        p7zip-full
        rar
        unrar

        # Editors & utilities
        nano
        vim
        htop
        tree
        neofetch

        # Desktop essentials
        dolphin
        diodon
        goldendict
        goldendict-wordnet
        gparted
        vlc

        # Printing
        cups
        cups-client
        printer-driver-all
    )

    if sudo apt install -y "${APPS[@]}"; then
        log "Basic applications installed successfully" true
        echo "✅ Basic system applications installed successfully"
    else
        log "Basic application installation failed" true
        echo "❌ Some applications failed to install"
        return 1
    fi
}

install_proxykey() {
    echo "Installing/Updating Proxykey..."
    if confirm; then
        zip_files
        sudo dpkg -i ./files/proxkey_ubantu.deb && log "Proxykey installed" true
    fi
}

repair_anydesk() {

    if confirm; then
        log "Starting AnyDesk repair" true

        # Ensure AnyDesk repo & key exist
        mkdir -p /etc/apt/keyrings

        if [ ! -f /etc/apt/keyrings/anydesk.gpg ]; then
            curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY \
            | gpg --dearmor -o /etc/apt/keyrings/anydesk.gpg
            log "AnyDesk GPG key added" true
        fi

        if [ ! -f /etc/apt/sources.list.d/anydesk.list ]; then
            echo "deb [signed-by=/etc/apt/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" \
            > /etc/apt/sources.list.d/anydesk.list
            log "AnyDesk repository added" true
        fi

        # Install AnyDesk if not installed
        if ! command -v anydesk >/dev/null 2>&1; then
            apt update
            apt install -y anydesk
            log "AnyDesk installed" true
        fi

        # Stop service if running
        systemctl stop anydesk 2>/dev/null || true

        # Remove corrupted identity/config
        rm -rf /etc/anydesk/ ~/.anydesk/
        log "Removed AnyDesk identity and config files" true

        # Reload systemd (reload is sufficient)
        systemctl daemon-reload

        # Enable and start service
        systemctl enable anydesk
        systemctl start anydesk

        sleep 3

        # Verify service status
        if systemctl is-active --quiet anydesk; then
            log "AnyDesk service started successfully" true
            echo -e "${bold_green}AnyDesk repaired successfully. Reboot recommended.${reset}"
        else
            log "AnyDesk service failed to start" true
            echo -e "${bold_red}AnyDesk repair failed. Check logs:${reset}"
            echo "journalctl -u anydesk --no-pager | tail -50"
        fi
    fi
}



setup_hotspot() {
    echo "Setting up Wi-Fi Hotspot..."
    HOTSPOT_NAME="Court"
    HOTSPOT_PASSWORD="12344321"
    WIFI_INTERFACE=$(nmcli device status | grep wifi | awk '{print $1}')
    SERVICE_FILE="/etc/systemd/system/wifi-hotspot.service"

    [ -z "$WIFI_INTERFACE" ] && echo "No Wi-Fi interface found." && return

    nmcli radio wifi on

    if ! nmcli connection show Hotspot &> /dev/null; then
        sudo nmcli connection add type wifi ifname "$WIFI_INTERFACE" con-name "Hotspot" autoconnect yes ssid "$HOTSPOT_NAME"
        sudo nmcli connection modify "Hotspot" 802-11-wireless.mode ap ipv4.method shared
        sudo nmcli connection modify "Hotspot" wifi-sec.key-mgmt wpa-psk
        sudo nmcli connection modify "Hotspot" wifi-sec.psk "$HOTSPOT_PASSWORD"
        CONFIG_FILE=$(find /etc/NetworkManager/system-connections/ -name '*Hotspot*' | head -n1)
        [ -f "$CONFIG_FILE" ] && sudo chmod 600 "$CONFIG_FILE"
    fi

    sudo systemctl restart NetworkManager

    sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Start WiFi Hotspot
After=NetworkManager.service
Requires=NetworkManager.service

[Service]
ExecStart=/usr/bin/nmcli connection up Hotspot
Restart=on-failure

[Install]
WantedBy=multi-user.target 
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable wifi-hotspot.service
    echo -e "${bold_green}Hotspot setup complete. Reboot recommended.${reset}"
}

# --- Brightness Controller GUI ---
install_brightness_controller_gui() { 
    if dpkg -l | grep -q brightness-controller; then
        echo -e "${bold_green}Brightness Controller (GUI) already installed.${reset}"
        return
    fi

    if confirm; then
        sudo add-apt-repository -y ppa:apandada1/brightness-controller
        sudo apt update
        sudo apt install -y brightness-controller
        echo -e "${bold_green}Brightness Controller GUI installed successfully.${reset}"
    fi
}

# --- Brightness Control via DDC/CI ---
brightness_control_ddc() {
    if ! command -v ddcutil &>/dev/null; then
        echo "Installing ddcutil..."
        sudo apt install -y ddcutil
        sudo usermod -aG i2c $USER
        echo "Reboot required after first install."
        read -p "Press Enter to continue..."
    fi

    DEFAULT_BRIGHTNESS=30
    sudo ddcutil setvcp 10 $DEFAULT_BRIGHTNESS >/dev/null 2>&1

    while true; do
        clear
        current=$(ddcutil getvcp 10 | grep -oP '(?<=current value = )\d+')
        echo "========= 💡 DDC/CI Brightness ========="
        echo "Current Brightness: ${current}%"
        echo "1. Increase (+10)"
        echo "2. Decrease (-10)"
        echo "3. Set Custom (0–100)"
        echo "4. Back to Main Menu"
        echo "======================================="
        read -p "Choose option: " opt

        case $opt in
            1) sudo ddcutil setvcp 10 $((current+10)) ;;
            2) sudo ddcutil setvcp 10 $((current-10)) ;;
            3) read -p "Enter value: " v; sudo ddcutil setvcp 10 $v ;;
            4) break ;;
            *) echo "Invalid"; sleep 1 ;;
        esac
    done
}


# ----------------------------
# Install Canon 246 Driver (Offline)
# ----------------------------
install_canon_246() {
    echo "Installing Canon 246 Printer Driver (Offline)..."

    if confirm; then
        zip_files

        if [ ! -f "./files/Canon_246.deb" ]; then
            log "Canon_246.deb not found" true
            echo -e "${bold_red}Canon_246.deb missing in files.zip${reset}"
            return
        fi

        sudo dpkg -i ./files/Canon_246.deb \
        && sudo apt -f install -y \
        && log "Canon 246 driver installed successfully" true \
        || {
            log "Canon 246 driver installation failed" true
            echo -e "${bold_red}Canon 246 installation failed${reset}"
            return
        }

        echo -e "${bold_green}Canon 246 driver installed successfully.${reset}"
    fi
}

# ----------------------------
# Install Canon 465 Driver (Offline)
# ----------------------------
install_canon_465() {
    echo "Installing Canon 465 Printer Driver (Offline)..."

    if confirm; then
        zip_files

        if [ ! -f "./files/Canon_465.deb" ]; then
            log "Canon_465.deb not found" true
            echo -e "${bold_red}Canon_465.deb missing in files.zip${reset}"
            return
        fi

        sudo dpkg -i ./files/Canon_465.deb \
        && sudo apt -f install -y \
        && log "Canon 465 driver installed successfully" true \
        || {
            log "Canon 465 driver installation failed" true
            echo -e "${bold_red}Canon 465 installation failed${reset}"
            return
        }

        echo -e "${bold_green}Canon 465 driver installed successfully.${reset}"
    fi
}

# ----------------------------
# Auto-detect Canon Printer via USB and Install Driver
# ----------------------------
install_canon_auto() {
    echo "Auto-detecting Canon printer via USB..."

    if confirm; then
        zip_files

        # Detect Canon USB device
        CANON_USB=$(lsusb | grep -i "Canon")

        if [ -z "$CANON_USB" ]; then
            log "No Canon USB printer detected" true
            echo -e "${bold_red}No Canon printer detected via USB.${reset}"
            return
        fi

        log "Detected Canon USB device: $CANON_USB" true
        echo "Detected: $CANON_USB"

        # Extract Product ID (after 04a9:)
        PRODUCT_ID=$(echo "$CANON_USB" | sed -n 's/.*04a9:\([0-9a-fA-F]\{4\}\).*/\1/p')

        if [ -z "$PRODUCT_ID" ]; then
            log "Failed to extract Canon product ID" true
            echo -e "${bold_red}Unable to identify Canon model.${reset}"
            return
        fi

        log "Canon USB Product ID: $PRODUCT_ID" true

        case "$PRODUCT_ID" in
            # ---- Canon 246 series ----
            27b6|27b7|27b8)
                DRIVER="./files/Canon_246.deb"
                MODEL="Canon 246 series"
                ;;

            # ---- Canon 465 series ----
            2821|2822|2823)
                DRIVER="./files/Canon_465.deb"
                MODEL="Canon 465 series"
                ;;

            *)
                log "Unknown Canon product ID: $PRODUCT_ID" true
                echo -e "${bold_red}Detected Canon printer is not mapped to a driver.${reset}"
                echo "Product ID: $PRODUCT_ID"
                return
                ;;
        esac

        if [ ! -f "$DRIVER" ]; then
            log "Required Canon driver not found: $DRIVER" true
            echo -e "${bold_red}Required driver missing in files.zip${reset}"
            return
        fi

        echo "Installing driver for $MODEL..."
        sudo dpkg -i "$DRIVER" \
        && sudo apt -f install -y \
        && log "Installed driver for $MODEL" true \
        || {
            log "Driver installation failed for $MODEL" true
            echo -e "${bold_red}Canon driver installation failed${reset}"
            return
        }

        echo -e "${bold_green}$MODEL driver installed successfully.${reset}"
    fi
}


reset_cups() {
    sudo cp /usr/share/cups/cupsd.conf.default /etc/cups/cupsd.conf || {
        echo -e "${bold_red}Failed to restore CUPS config${reset}"
        log "CUPS config restore failed" true
        return 1
    }

    sudo service cups restart
    log "CUPS configuration reset and service restarted" true
    echo -e "${bold_green}CUPS configuration reset and service restarted${reset}"
}

health_summary() {
    clear
    echo "================== 🩺 SYSTEM HEALTH SUMMARY =================="
    echo "Date        : $(date)"
    echo "Hostname    : $(hostname)"
    echo "OS          : $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    echo "Kernel      : $(uname -r)"
    echo "---------------------------------------------------------------"

    # CPU Load
    echo "🧠 CPU Load : $(uptime | awk -F'load average:' '{ print $2 }')"

    # Memory Usage
    free_mem=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
    echo "💾 RAM Usage: $free_mem"

    # Disk Usage
    echo "📦 Disk Usage:"
    df -h / | awk 'NR==2 {print "   Used:", $3, "Free:", $4, "Usage:", $5}'

    # Network
    if nmcli -t -f STATE general status | grep -q connected; then
        echo "🌐 Network  : Connected"
    else
        echo "🌐 Network  : Disconnected"
    fi

    # CUPS Service
    if systemctl is-active --quiet cups; then
        echo "🖨️ CUPS     : Running"
    else
        echo "🖨️ CUPS     : NOT running ⚠️"
    fi

    # USB Printer Detection
    if lsusb | grep -qi "printer\|canon\|epson"; then
        echo "🔌 USB Dev  : Printer detected"
    else
        echo "🔌 USB Dev  : No printer detected"
    fi

    # Failed Services
    failed_count=$(systemctl --failed --no-legend | wc -l)
    if [ "$failed_count" -eq 0 ]; then
        echo "🔥 Services : No failed services"
    else
        echo "🔥 Services : $failed_count failed ⚠️"
        systemctl --failed --no-legend
    fi

    echo "---------------------------------------------------------------"
    echo "📄 Log File : $log_file"
    echo "==============================================================="

    log "Health summary viewed" true
    read -p "Press Enter to return to menu..."
}


# ----------------------------
# Install LibreWriter Roznama Extension (.oxt)
# ----------------------------
install_librewriter_roznama_extension() {
    echo "Installing LibreWriter Roznama Extension..."

    if ! confirm; then
        log "User cancelled LibreWriter Roznama Extension installation" true
        return
    fi

    zip_files

    EXT_FILE="./files/librewriter_roznama_extension.oxt"

    if [ ! -f "$EXT_FILE" ]; then
        log "LibreWriter Roznama Extension not found" true
        echo -e "${bold_red}Roznama extension file not found: $EXT_FILE${reset}"
        return
    fi

    REAL_USER=${SUDO_USER:-$USER}
    REAL_HOME=$(eval echo "~$REAL_USER")

    log "Installing LibreWriter Roznama Extension for user: $REAL_USER" true

    # Ensure LibreOffice exists
    if ! command -v libreoffice >/dev/null 2>&1; then
        echo "LibreOffice not found. Installing LibreOffice Writer..."
        apt install -y libreoffice-writer
    fi

    # ----------------------------
    # Method 1: unopkg (Preferred)
    # ----------------------------
    if command -v unopkg >/dev/null 2>&1; then
        sudo -u "$REAL_USER" \
            env HOME="$REAL_HOME" \
            unopkg add --force "$EXT_FILE" \
            && {
                log "Roznama Extension installed via unopkg" true
                echo -e "${bold_green}Roznama Extension installed successfully (unopkg).${reset}"
                return
            }
    fi

    # ----------------------------
    # Method 2: LibreOffice CLI (Fallback)
    # ----------------------------
    sudo -u "$REAL_USER" \
        env HOME="$REAL_HOME" \
        libreoffice \
        --headless \
        --nologo \
        --nodefault \
        --norestore \
        --install-extension "$EXT_FILE" \
        && {
            log "Roznama Extension installed via libreoffice CLI" true
            echo -e "${bold_green}Roznama Extension installed successfully (CLI fallback).${reset}"
            return
        }

    # If both methods fail
    log "LibreWriter Roznama Extension installation failed (all methods)" true
    echo -e "${bold_red}Failed to install LibreWriter Roznama Extension using all methods${reset}"
}











# === Task Menu ===
tasks=(
    "Install Naps Scanner"
    "Install Only Epson Driver and Epson Scanner"
    "Install Fijustu Scanner Driver"
    "Install other Ubuntu Apps (e.g.-Dictionary)"
    "Install/Update Proxykey for ubuntu"
    "Repair the Anydesk issue"
    "Setup Wi-Fi Hotspot (Auto-start)"
    "Brightness Control (DDC/CI)"
    "Install Canon 246 Printer Driver (Offline)"
    "Install Canon 465 Printer Driver (Offline)"
    "Auto-detect Canon Printer (USB)"
    "Reset CUPS (Fix printing service)"
    "System Health Summary Report"
    "Install LibreWriter Roznama Extension"
)



execute_task() {
    case $1 in
        1) install_naps ;;
        2) install_epson ;;
        3) install_fijustu ;;
        4) install_apps ;;
        5) install_proxykey ;;
        6) repair_anydesk ;;
        7) setup_hotspot ;;
        8) brightness_control_ddc ;;
        9) install_canon_246 ;;
        10) install_canon_465 ;;
        11) install_canon_auto ;;
        12) reset_cups ;;
        13) health_summary ;;
        14) install_librewriter_roznama_extension ;;
        15) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid entry." ;;
    esac

    # 🔹 UNIVERSAL PAUSE AFTER EVERY TASK
    echo
    read -p "Press Enter to return to menu..."
    clear
}


# === Main ===
check_dependency "curl" "wget" "unzip" "whiptail"
echo -e "${bold_red}This script is intended for Ubuntu 22.04 on Dell/HP systems.${reset}"
PS3="Select an option: "

select option in "${tasks[@]}" "Exit"; do
    if [[ $REPLY -le ${#tasks[@]} ]]; then
        execute_task $REPLY
    else
        echo "Exiting..."
        break
    fi
done
