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
        wget -q https://github.com/rathodmanojkumar/Storage_Files/raw/main/files.zip
        unzip -q files.zip
    fi
}

# === Task Functions ===
install_naps() {
    echo "Installing NAPS Scanner..."
    if confirm; then
        local keyring_path="/etc/apt/keyrings/naps2.gpg"
        [ ! -f "$keyring_path" ] && curl -fsSL https://www.naps2.com/naps2-public.pgp | sudo gpg --dearmor -o "$keyring_path"
        grep -q "^deb .*naps2" /etc/apt/sources.list.d/naps2.list 2>/dev/null ||         echo "deb [signed-by=$keyring_path] https://downloads.naps2.com ./" | sudo tee /etc/apt/sources.list.d/naps2.list >/dev/null
        sudo apt update && sudo apt install -y naps2 && log "NAPS2 installed successfully" true || { log "Failed to install NAPS2" true; exit 1; }
    fi
}

install_epson() {
    echo "Installing Epson Drivers..."
    if confirm; then
        sudo apt update && sudo apt install -y lsb lsb-core
        zip_files
        sudo dpkg -i ./files/epson-inkjet-printer-escpr2_1.2.3-1_amd64.deb
        sudo sh ./files/epsonscan2-bundle-6.7.61.0.x86_64.deb/install.sh
        sudo apt purge ipp-usb -y
        log "Epson drivers installed successfully" true
    fi
}

install_fijustu() {
    echo "Installing Fujitsu Driver..."
    if confirm; then
        zip_files
        sudo dpkg -i ./files/pfufs-ubuntu_2.8.0_amd64.deb && log "Fujitsu driver installed" true
    fi
}

install_apps() {
    echo "Installing additional apps..."
    if confirm; then
        sudo apt update && sudo apt install -y diodon goldendict goldendict-wordnet openssh-server net-tools dolphin
        log "Apps installed successfully" true
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
    echo "Repairing Anydesk..."
    if confirm; then
        sudo echo "Hello" && log "Anydesk repair simulated" true
    fi
}

setup_hotspot() {
    echo "Setting up Wi-Fi Hotspot..."
    HOTSPOT_NAME="Court"
    HOTSPOT_PASSWORD="12344321"
    WIFI_INTERFACE=$(nmcli device status | grep wifi | awk '{print $1}')
    SERVICE_FILE="/etc/systemd/system/wifi-hotspot.service"

    if [ -z "$WIFI_INTERFACE" ]; then
        echo "No Wi-Fi interface found. Exiting."
        return
    fi

    nmcli radio wifi on

    if ! nmcli connection show Hotspot &> /dev/null; then
        sudo nmcli connection add type wifi ifname "$WIFI_INTERFACE" con-name "Hotspot" autoconnect yes ssid "$HOTSPOT_NAME"
        sudo nmcli connection modify "Hotspot" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
        sudo nmcli connection modify "Hotspot" wifi-sec.key-mgmt wpa-psk
        sudo nmcli connection modify "Hotspot" wifi-sec.psk "$HOTSPOT_PASSWORD"
        CONFIG_FILE=$(find /etc/NetworkManager/system-connections/ -name '*Hotspot*' | head -n1)
        [ -f "$CONFIG_FILE" ] && sudo chmod 600 "$CONFIG_FILE"
    else
        echo "Hotspot already exists."
    fi

    sudo systemctl restart NetworkManager

    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Start WiFi Hotspot
After=network.target

[Service]
ExecStart=/usr/bin/nmcli connection up Hotspot
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable wifi-hotspot.service

    echo -e "${bold_green}Hotspot setup complete. Reboot to apply.${reset}"
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
        *) echo "Invalid entry." ;;
    esac
}

# === Main ===
check_dependency "curl" "wget" "unzip"
echo -e "${bold_red}This script is intended for Ubuntu 22.04 on Dell/HP systems.${reset}"
PS3="Select an option: "

select option in "${tasks[@]}" "Exit"; do
    if [[ $REPLY -le ${#tasks[@]} ]]; then
        execute_task $REPLY
    elif [[ $REPLY == $(( ${#tasks[@]} + 1 )) ]]; then
        echo "Exiting..."
        break
    else
        echo "Invalid entry. Try again."
    fi
done