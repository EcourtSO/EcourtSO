#!/bin/bash
# =============================================================================
# Ubuntu System Setup Script for Court/Office Environments
# Version: 3.0
# Description: Automated installation and configuration tool
# Credit: S. N. Abdal, System Officer, District Court, Pune
# =============================================================================

set -euo pipefail  # Strict error handling
IFS=$'\n\t'

# === Global Configuration ===
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/setup"
readonly LOG_FILE="${LOG_DIR}/install_script_$(date +%Y%m%d_%H%M%S).log"
readonly TEMP_DIR="/tmp/setup_$$"
readonly FILES_DIR="${SCRIPT_DIR}/files"
readonly FILES_ZIP="${SCRIPT_DIR}/files.zip"

# === Configuration File Support ===
CONFIG_FILE="${SCRIPT_DIR}/setup.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Default configuration if not set in config file
HOTSPOT_NAME="${HOTSPOT_NAME:-Court}"
HOTSPOT_PASSWORD="${HOTSPOT_PASSWORD:-12344321}"
DEFAULT_BRIGHTNESS="${DEFAULT_BRIGHTNESS:-30}"
AUTO_UPDATE="${AUTO_UPDATE:-true}"
SECURE_SSH="${SECURE_SSH:-true}"
ENABLE_FIREWALL="${ENABLE_FIREWALL:-true}"
CLEANUP_LOGS="${CLEANUP_LOGS:-true}"
MAX_BACKUPS="${MAX_BACKUPS:-5}"
AUTO_MODE="${AUTO_MODE:-false}"
INSTALL_ALL="${INSTALL_ALL:-false}"

# === Hacker Style Colors & Formatting ===
readonly HACKER_GREEN='\e[0;32m'
readonly HACKER_BRIGHT_GREEN='\e[1;32m'
readonly HACKER_DARK_GREEN='\e[0;32m'
readonly HACKER_NEON_GREEN='\e[38;5;46m'
readonly HACKER_LIME='\e[38;5;82m'
readonly HACKER_MINT='\e[38;5;121m'

readonly RED='\e[0;31m'
readonly BRIGHT_RED='\e[1;31m'
readonly GREEN='\e[0;32m'
readonly BRIGHT_GREEN='\e[1;32m'
readonly YELLOW='\e[0;33m'
readonly BRIGHT_YELLOW='\e[1;33m'
readonly BLUE='\e[0;34m'
readonly BRIGHT_BLUE='\e[1;34m'
readonly CYAN='\e[0;36m'
readonly BRIGHT_CYAN='\e[1;36m'
readonly MAGENTA='\e[0;35m'
readonly BRIGHT_MAGENTA='\e[1;35m'
readonly WHITE='\e[1;37m'
readonly DARK_GRAY='\e[0;90m'
readonly LIGHT_GRAY='\e[0;37m'

readonly BLINK='\e[5m'
readonly BOLD='\e[1m'
readonly UNDERLINE='\e[4m'
readonly RESET='\e[0m'

readonly MATRIX_GREEN='\e[38;5;46m'
readonly HACKER_ORANGE='\e[38;5;214m'
readonly HACKER_PURPLE='\e[38;5;141m'
readonly HACKER_BLUE='\e[38;5;75m'
readonly HACKER_RED='\e[38;5;196m'

# === Global Configuration Array ===
declare -A CONFIG=(
    [HOTSPOT_NAME]="$HOTSPOT_NAME"
    [HOTSPOT_PASSWORD]="$HOTSPOT_PASSWORD"
    [DEFAULT_BRIGHTNESS]="$DEFAULT_BRIGHTNESS"
    [REBOOT_REQUIRED]=false
    [DOWNLOAD_TIMEOUT]=30
    [MAX_RETRIES]=3
)

declare -a INSTALLED_PACKAGES=()
declare -a FAILED_TASKS=()
REBOOT_REQUIRED=false

# =============================================================================
# Hacker ASCII Art Functions
# =============================================================================

show_matrix() {
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo " ███████╗ ██████╗ ██████╗ ██╗   ██╗██████╗ ████████╗███████╗ ██████╗ "
    echo " ██╔════╝██╔════╝██╔═══██╗██║   ██║██╔══██╗╚══██╔══╝██╔════╝██╔═══██╗"
    echo " █████╗  ██║     ██║   ██║██║   ██║██████╔╝   ██║   ███████╗██║   ██║"
    echo " ██╔══╝  ██║     ██║   ██║██║   ██║██╔══██╗   ██║   ╚════██║██║   ██║"
    echo " ███████╗╚██████╗╚██████╔╝╚██████╔╝██║  ██║   ██║   ███████║╚██████╔╝"
    echo " ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝ "
    echo -e "${RESET}"
}

show_header() {
    clear
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║           Ubuntu System Setup Tool v3.0                  ║"
    echo "  ║           Court/Office Environment                       ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${HACKER_ORANGE}  [*] System: ${WHITE}$(lsb_release -ds 2>/dev/null || echo "Ubuntu")${RESET}"
    echo -e "${HACKER_ORANGE}  [*] Log: ${WHITE}$LOG_FILE${RESET}"
    echo -e "${HACKER_PURPLE}  [==] Developed by: S. N. Abdal, System Officer, District Court, Pune${RESET}"
    echo -e "${HACKER_MINT}${BOLD}  ════════════════════════════════════════════════════════════${RESET}"
    echo
}

# =============================================================================
# Command Line Argument Parsing
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --help, -h     Show this help"
                echo "  --auto         Run in automatic mode (no prompts)"
                echo "  --install-all  Install all packages"
                echo "  --fix-pdf      Fix PDF Signer only"
                echo "  --install-digisigner Install DIGISigner/NewSigner from files"
                echo "  --cleanup      Run system cleanup"
                echo "  --backup       Backup configuration"
                echo "  --restore      Restore configuration"
                echo "  --info         Show system information"
                echo "  --security     Apply security hardening"
                exit 0
                ;;
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --install-all)
                INSTALL_ALL=true
                shift
                ;;
            --fix-pdf)
                fix_pdf_signer
                exit 0
                ;;
            --install-digisigner)
                install_digisigner_unified
                exit 0
                ;;
            --cleanup)
                system_cleanup
                exit 0
                ;;
            --backup)
                backup_config
                exit 0
                ;;
            --restore)
                restore_config
                exit 0
                ;;
            --info)
                show_system_info
                exit 0
                ;;
            --security)
                security_hardening
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Hacker Style Logging Functions
# =============================================================================

log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${level}] ${message}"
    
    [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
    
    echo "$log_entry" >> "$LOG_FILE"
    
    case "$level" in
        ERROR)   echo -e "${BRIGHT_RED}  [!] ${message}${RESET}" >&2 ;;
        WARNING) echo -e "${BRIGHT_YELLOW}  [⚠] ${message}${RESET}" ;;
        SUCCESS) echo -e "${BRIGHT_GREEN}  [✓] ${message}${RESET}" ;;
        INFO)    echo -e "${HACKER_BLUE}  [*] ${message}${RESET}" ;;
        HACKER)  echo -e "${HACKER_NEON_GREEN}  [+] ${message}${RESET}" ;;
        *)       echo "$message" ;;
    esac
}

log_section() {
    local message="$1"
    echo
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ═══════════════════════════════════════════════════════════"
    echo "  [*] ${message}"
    echo "  ═══════════════════════════════════════════════════════════"
    echo -e "${RESET}"
    log "HACKER" "SECTION: $message"
}

# =============================================================================
# Hacker Style Utility Functions
# =============================================================================

matrix_effect() {
    echo -e "${HACKER_DARK_GREEN}"
    for i in {1..20}; do
        echo -ne "\r  ["
        for j in {1..48}; do
            if [[ $((RANDOM % 3)) -eq 0 ]]; then
                echo -ne "${HACKER_NEON_GREEN}█"
            else
                echo -ne "${HACKER_DARK_GREEN}█"
            fi
        done
        echo -ne "]"
        sleep 0.02
    done
    echo -e "${RESET}"
}

hacker_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"
    local width=48
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    echo -ne "\r  ${HACKER_NEON_GREEN}${BOLD}[${RESET}"
    for ((i=0; i<filled; i++)); do
        echo -ne "${HACKER_NEON_GREEN}█${RESET}"
    done
    for ((i=0; i<empty; i++)); do
        echo -ne "${HACKER_DARK_GREEN}░${RESET}"
    done
    echo -ne "${HACKER_NEON_GREEN}${BOLD}]${RESET} ${HACKER_ORANGE}${percent}%${RESET} ${HACKER_MINT}${message}${RESET}"
}

# =============================================================================
# Core Utility Functions
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${BRIGHT_RED}${BOLD}"
        echo "  ╔═══════════════════════════════════════════════════════════╗"
        echo "  ║  [!] ERROR: ACCESS DENIED - Root privileges required    ║"
        echo "  ║  [!] Use: sudo ./${SCRIPT_NAME}                         ║"
        echo "  ╚═══════════════════════════════════════════════════════════╝"
        echo -e "${RESET}"
        exit 1
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

package_installed() {
    dpkg -s "$1" &> /dev/null
}

get_real_user() {
    echo "${SUDO_USER:-$USER}"
}

get_real_home() {
    local user="$(get_real_user)"
    eval echo "~$user"
}

check_internet() {
    local timeout="${CONFIG[DOWNLOAD_TIMEOUT]}"
    echo -e "${HACKER_BLUE}  [*] Checking internet connection...${RESET}"
    if ping -c 1 -W "$timeout" 8.8.8.8 &> /dev/null; then
        echo -e "${BRIGHT_GREEN}  [✓] Internet connection established${RESET}"
        return 0
    else
        log "WARNING" "No internet connection detected"
        echo -e "${BRIGHT_YELLOW}  [⚠] No internet connection${RESET}"
        return 1
    fi
}

retry_command() {
    local max_retries="${CONFIG[MAX_RETRIES]}"
    local delay=2
    local attempt=1
    
    while [[ $attempt -le $max_retries ]]; do
        if "$@"; then
            return 0
        fi
        echo -e "${BRIGHT_YELLOW}  [⚠] Command failed (attempt $attempt/$max_retries): $*${RESET}"
        sleep $delay
        ((attempt++))
        ((delay*=2))
    done
    
    log "ERROR" "Command failed after $max_retries attempts: $*"
    return 1
}

confirm() {
    [[ "$AUTO_MODE" == "true" ]] && return 0
    
    local message="${1:-Are you sure you want to proceed?}"
    local default="${2:-N}"
    local timeout="${3:-30}"
    
    local prompt="[y/N]"
    [[ "$default" == "Y" ]] && prompt="[Y/n]"
    
    echo -ne "${HACKER_NEON_GREEN}  [?] ${message} ${prompt} ${RESET}"
    read -t "$timeout" response || {
        echo -e "\n${BRIGHT_YELLOW}  [⚠] Timed out. Assuming default: ${default}${RESET}"
        [[ "$default" == "Y" ]] && return 0 || return 1
    }
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log "HACKER" "Cleaned up temporary directory"
    fi
}

trap cleanup EXIT

# =============================================================================
# Package Management
# =============================================================================

apt_update() {
    echo -e "${HACKER_BLUE}  [*] Updating package lists...${RESET}"
    if retry_command apt-get update -qq; then
        echo -e "${BRIGHT_GREEN}  [✓] Package lists updated${RESET}"
        return 0
    else
        log "ERROR" "Failed to update package lists"
        return 1
    fi
}

install_packages() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! package_installed "$pkg"; then
            to_install+=("$pkg")
        else
            log "INFO" "Package already installed: $pkg"
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo -e "${BRIGHT_GREEN}  [✓] All packages are already installed${RESET}"
        return 0
    fi
    
    echo -e "${HACKER_NEON_GREEN}  [+] Installing packages: ${to_install[*]}${RESET}"
    
    if retry_command apt-get install -y --no-install-recommends "${to_install[@]}"; then
        INSTALLED_PACKAGES+=("${to_install[@]}")
        echo -e "${BRIGHT_GREEN}  [✓] Packages installed successfully: ${to_install[*]}${RESET}"
        return 0
    else
        log "ERROR" "Failed to install packages: ${to_install[*]}"
        return 1
    fi
}

add_repository() {
    local repo_url="$1"
    local repo_name="$2"
    local key_url="$3"
    local key_path="/etc/apt/keyrings/${repo_name}.gpg"
    local sources_file="/etc/apt/sources.list.d/${repo_name}.list"
    
    mkdir -p /etc/apt/keyrings
    
    if [[ ! -f "$key_path" ]]; then
        echo -e "${HACKER_NEON_GREEN}  [+] Adding GPG key for $repo_name...${RESET}"
        if retry_command curl -fsSL "$key_url" | gpg --dearmor -o "$key_path"; then
            echo -e "${BRIGHT_GREEN}  [✓] GPG key added for $repo_name${RESET}"
        else
            log "ERROR" "Failed to add GPG key for $repo_name"
            return 1
        fi
    fi
    
    if [[ ! -f "$sources_file" ]]; then
        echo -e "${HACKER_NEON_GREEN}  [+] Adding repository: $repo_name${RESET}"
        echo "deb [signed-by=$key_path] $repo_url" > "$sources_file"
        apt_update || return 1
        echo -e "${BRIGHT_GREEN}  [✓] Repository added: $repo_name${RESET}"
    else
        echo -e "${HACKER_BLUE}  [*] Repository already exists: $repo_name${RESET}"
    fi
    
    return 0
}

# =============================================================================
# File Operations
# =============================================================================

setup_files() {
    log_section "Setting up support files"
    
    if [[ -d "$FILES_DIR" ]]; then
        echo -e "${BRIGHT_GREEN}  [✓] Files directory already exists, using existing files${RESET}"
        return 0
    fi
    
    if [[ -f "$FILES_ZIP" ]]; then
        echo -e "${HACKER_NEON_GREEN}  [+] Extracting files.zip...${RESET}"
        if unzip -q "$FILES_ZIP" -d "$SCRIPT_DIR"; then
            echo -e "${BRIGHT_GREEN}  [✓] Files extracted from local zip${RESET}"
            return 0
        else
            log "ERROR" "Failed to extract files.zip"
            return 1
        fi
    fi
    
    if check_internet; then
        echo -e "${HACKER_NEON_GREEN}  [+] Downloading files.zip from repository...${RESET}"
        local temp_zip="${TEMP_DIR}/files.zip"
        mkdir -p "$TEMP_DIR"
        
        if retry_command wget -q --timeout="${CONFIG[DOWNLOAD_TIMEOUT]}" \
            -O "$temp_zip" \
            "https://raw.githubusercontent.com/EcourtSO/EcourtSO/main/files.zip"; then
            
            if unzip -q "$temp_zip" -d "$SCRIPT_DIR"; then
                echo -e "${BRIGHT_GREEN}  [✓] Files downloaded and extracted${RESET}"
                return 0
            else
                log "ERROR" "Failed to extract downloaded files.zip"
                return 1
            fi
        else
            log "ERROR" "Failed to download files.zip"
            return 1
        fi
    else
        log "ERROR" "No internet connection and files directory not found"
        return 1
    fi
}

install_deb() {
    local deb_path="$1"
    local package_name="${2:-$(basename "$deb_path" .deb)}"
    
    if [[ ! -f "$deb_path" ]]; then
        log "ERROR" "Debian package not found: $deb_path"
        return 1
    fi
    
    echo -e "${HACKER_NEON_GREEN}  [+] Installing $package_name from $deb_path...${RESET}"
    
    if dpkg -i "$deb_path" 2>/dev/null; then
        apt-get -f install -y --no-install-recommends
        echo -e "${BRIGHT_GREEN}  [✓] $package_name installed successfully${RESET}"
        return 0
    else
        log "ERROR" "Failed to install $package_name"
        return 1
    fi
}

# =============================================================================
# Unified Digital Signature Application Installation
# =============================================================================

install_digisigner_unified() {
    log_section "Digital Signature Application Installation"
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║        📄 Digital Signature Applications                 ║"
    echo "  ║        Unified Installer                                 ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    if ! confirm "Install Digital Signature Applications?"; then
        log "INFO" "Installation skipped"
        return 0
    fi
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║      Select Digital Signature Application to Install     ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo
    echo "  1. Install DIGISigner (from .deb file in ./files/)"
    echo "  2. Install NewSigner (from .deb file in ./files/)"
    echo "  3. Install DigiSigner JAR (download from GitHub)"
    echo "  4. Install All (DIGISigner + NewSigner + DigiSigner JAR)"
    echo "  5. Return to Main Menu"
    echo
    echo -ne "${HACKER_NEON_GREEN}${BOLD}  [?] Choose option [1-5]: ${RESET}"
    read choice
    
    case "$choice" in
        1)
            install_digisigner_deb
            ;;
        2)
            install_newsigner_deb
            ;;
        3)
            install_digisigner_jar
            ;;
        4)
            install_digisigner_deb
            install_newsigner_deb
            install_digisigner_jar
            ;;
        5)
            log "INFO" "Returning to main menu"
            return 0
            ;;
        *)
            echo -e "${BRIGHT_RED}  [!] Invalid option${RESET}"
            sleep 1
            ;;
    esac
    
    return 0
}

# =============================================================================
# DIGISigner .deb Installation
# =============================================================================

install_digisigner_deb() {
    log_section "DIGISigner Installation"
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║        📄 DIGISigner Installation                        ║"
    echo "  ║        Digital Signature Application                     ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    # Setup files
    setup_files || return 1
    
    # Check for DIGISigner .deb file
    echo -e "${HACKER_BLUE}  [*] Checking for DIGISigner .deb file...${RESET}"
    
    # Look for various possible names
    local digisigner_deb=""
    local possible_names=(
        "*DIGISigner*.deb"
        "*digisigner*.deb"
        "*DIGI*.deb"
        "*DigiSigner*.deb"
        "*NICDSign*.deb"
    )
    
    for pattern in "${possible_names[@]}"; do
        digisigner_deb="$(find "$FILES_DIR" -maxdepth 1 -name "$pattern" 2>/dev/null | head -1)"
        if [[ -n "$digisigner_deb" ]]; then
            break
        fi
    done
    
    if [[ -z "$digisigner_deb" ]]; then
        log "ERROR" "DIGISigner .deb file not found in files directory"
        echo -e "${BRIGHT_YELLOW}  [⚠] Please place DIGISigner.deb in ./files/${RESET}"
        echo -e "  ${BRIGHT_YELLOW}Looking for: ${WHITE}DIGISigner.deb, digisigner.deb, or NICDSign.deb${RESET}"
        FAILED_TASKS+=("DIGISigner Install")
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}  [✓] Found DIGISigner: ${WHITE}$(basename "$digisigner_deb")${RESET}"
    
    # Check if Java is installed
    echo -e "${HACKER_BLUE}  [*] Checking Java installation...${RESET}"
    if ! command_exists java; then
        log "WARNING" "Java is not installed"
        echo -e "${BRIGHT_YELLOW}  [⚠] Java is required for DIGISigner.${RESET}"
        if confirm "Install OpenJDK 8 JRE now?"; then
            apt_update || return 1
            install_packages "openjdk-8-jre" || return 1
        else
            FAILED_TASKS+=("DIGISigner Install")
            return 1
        fi
    fi
    
    JAVA_PATH=$(readlink -f "$(which java)")
    echo -e "${BRIGHT_GREEN}  [✓] Detected Java: ${WHITE}$JAVA_PATH${RESET}"
    
    # Install DIGISigner
    if install_deb "$digisigner_deb" "DIGISigner"; then
        log "SUCCESS" "DIGISigner installed successfully"
        
        # Create desktop shortcut
        create_digisigner_desktop_shortcut
        
        # Fix Java path if needed
        fix_digisigner_java_path
        
        echo -e "${BRIGHT_GREEN}${BOLD}  [✓] DIGISigner installation completed successfully!${RESET}"
        echo -e "${HACKER_ORANGE}  [*] You can find DIGISigner in your applications menu or on the desktop${RESET}"
        
        return 0
    else
        log "ERROR" "DIGISigner installation failed"
        FAILED_TASKS+=("DIGISigner Install")
        return 1
    fi
}

# Create desktop shortcut for DIGISigner
create_digisigner_desktop_shortcut() {
    local real_user="$(get_real_user)"
    local real_home="$(get_real_home)"
    local desktop_dir="${real_home}/Desktop"
    local applications_dir="${real_home}/.local/share/applications"
    
    # Create directories if they don't exist
    mkdir -p "$desktop_dir" "$applications_dir"
    
    local desktop_file="${applications_dir}/digisigner.desktop"
    
    # Find DIGISigner executable
    local digisigner_bin=$(which digisigner 2>/dev/null || find /usr -name "digisigner" -type f 2>/dev/null | head -1)
    
    if [[ -z "$digisigner_bin" ]]; then
        log "WARNING" "DIGISigner executable not found, skipping desktop shortcut"
        return 0
    fi
    
    # Create desktop entry
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=DIGISigner
Comment=Digital Signature Application
Exec=$digisigner_bin
Icon=digisigner
Terminal=false
Categories=Office;Utility;
StartupNotify=true
EOF
    
    chown "$real_user":"$real_user" "$desktop_file" 2>/dev/null || true
    chmod +x "$desktop_file"
    
    # Copy to desktop
    cp "$desktop_file" "$desktop_dir/" 2>/dev/null || true
    chown "$real_user":"$real_user" "$desktop_dir/digisigner.desktop" 2>/dev/null || true
    chmod +x "$desktop_dir/digisigner.desktop" 2>/dev/null || true
    
    # Trust the desktop file
    if command_exists gio; then
        gio set "$desktop_file" metadata::trusted true 2>/dev/null || true
        gio set "$desktop_dir/digisigner.desktop" metadata::trusted true 2>/dev/null || true
    fi
    
    log "SUCCESS" "DIGISigner desktop shortcut created"
}

# Fix DIGISigner Java path
fix_digisigner_java_path() {
    log "INFO" "Fixing DIGISigner Java path..."
    
    local app_dirs=(
        "/opt/apps/com.digisigner.pdfsigner/files"
        "/opt/digisigner"
        "/usr/share/digisigner"
        "/usr/lib/digisigner"
    )
    
    for app_dir in "${app_dirs[@]}"; do
        local start_script="${app_dir}/start.sh"
        if [[ -f "$start_script" ]]; then
            echo -e "${HACKER_BLUE}  [*] Found start.sh at: ${WHITE}$start_script${RESET}"
            
            # Create backup
            BACKUP="$start_script.$(date +%Y%m%d_%H%M%S).bak"
            cp "$start_script" "$BACKUP"
            echo -e "${BRIGHT_GREEN}  [✓] Backup created: ${WHITE}$BACKUP${RESET}"
            
            # Update Java path
            sed -i 's|/usr/local/jdk1.8.0_181/bin/java|/usr/bin/java|g' "$start_script"
            sed -i 's|^export PATH=.*|export PATH=$PATH:/usr/bin|g' "$start_script"
            
            chmod +x "$start_script"
            echo -e "${BRIGHT_GREEN}  [✓] Java path fixed in $start_script${RESET}"
            break
        fi
    done
}

# =============================================================================
# NewSigner .deb Installation
# =============================================================================

install_newsigner_deb() {
    log_section "NewSigner Installation"
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║        📄 NewSigner Installation                         ║"
    echo "  ║        Digital Signature Application                     ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    # Setup files
    setup_files || return 1
    
    # Check for NewSigner .deb file
    echo -e "${HACKER_BLUE}  [*] Checking for NewSigner .deb file...${RESET}"
    local newsigner_deb="$(find "$FILES_DIR" -name '*NewSigner*.deb' 2>/dev/null | head -1)"
    
    if [[ -z "$newsigner_deb" ]]; then
        log "ERROR" "NewSigner .deb file not found in files directory"
        echo -e "${BRIGHT_YELLOW}  [⚠] Please place NewSigner.deb in ./files/${RESET}"
        echo -e "  ${BRIGHT_YELLOW}Looking for: ${WHITE}*NewSigner*.deb${RESET}"
        FAILED_TASKS+=("NewSigner Install")
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}  [✓] Found NewSigner: ${WHITE}$(basename "$newsigner_deb")${RESET}"
    
    # Check for dependencies
    echo -e "${HACKER_BLUE}  [*] Checking dependencies...${RESET}"
    local deps=(
        "libqt5core5a"
        "libqt5gui5"
        "libqt5widgets5"
        "libqt5network5"
        "libqt5webkit5"
        "libssl1.1"
        "libc6"
        "libstdc++6"
        "libx11-6"
        "libxcb1"
        "libxext6"
        "libxrender1"
        "libxcb-icccm4"
        "libxcb-image0"
        "libxcb-keysyms1"
        "libxcb-randr0"
        "libxcb-render-util0"
        "libxcb-shape0"
        "libxcb-shm0"
        "libxcb-sync1"
        "libxcb-xfixes0"
        "libxcb-xinerama0"
        "libxcb-xkb1"
        "libxkbcommon-x11-0"
        "libxkbcommon0"
    )
    
    apt_update || return 1
    install_packages "${deps[@]}" || {
        log "WARNING" "Some dependencies may have failed, but continuing..."
    }
    
    # Install NewSigner
    if install_deb "$newsigner_deb" "NewSigner"; then
        log "SUCCESS" "NewSigner installed successfully"
        
        # Create desktop shortcut
        create_newsigner_desktop_shortcut
        
        # Configure NewSigner
        configure_newsigner
        
        echo -e "${BRIGHT_GREEN}${BOLD}  [✓] NewSigner installation completed successfully!${RESET}"
        echo -e "${HACKER_ORANGE}  [*] You can find NewSigner in your applications menu or on the desktop${RESET}"
        
        return 0
    else
        log "ERROR" "NewSigner installation failed"
        FAILED_TASKS+=("NewSigner Install")
        return 1
    fi
}

# Create desktop shortcut for NewSigner
create_newsigner_desktop_shortcut() {
    local real_user="$(get_real_user)"
    local real_home="$(get_real_home)"
    local desktop_dir="${real_home}/Desktop"
    local applications_dir="${real_home}/.local/share/applications"
    
    # Create directories if they don't exist
    mkdir -p "$desktop_dir" "$applications_dir"
    
    local desktop_file="${applications_dir}/newsigner.desktop"
    
    # Find NewSigner executable
    local newsigner_bin=$(which newsigner 2>/dev/null || find /usr -name "newsigner" -type f 2>/dev/null | head -1)
    
    if [[ -z "$newsigner_bin" ]]; then
        log "WARNING" "NewSigner executable not found, skipping desktop shortcut"
        return 0
    fi
    
    # Create desktop entry
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=NewSigner
Comment=Digital Signature Application
Exec=$newsigner_bin
Icon=newsigner
Terminal=false
Categories=Office;Utility;
StartupNotify=true
EOF
    
    chown "$real_user":"$real_user" "$desktop_file" 2>/dev/null || true
    chmod +x "$desktop_file"
    
    # Copy to desktop
    cp "$desktop_file" "$desktop_dir/" 2>/dev/null || true
    chown "$real_user":"$real_user" "$desktop_dir/newsigner.desktop" 2>/dev/null || true
    chmod +x "$desktop_dir/newsigner.desktop" 2>/dev/null || true
    
    # Trust the desktop file
    if command_exists gio; then
        gio set "$desktop_file" metadata::trusted true 2>/dev/null || true
        gio set "$desktop_dir/newsigner.desktop" metadata::trusted true 2>/dev/null || true
    fi
    
    log "SUCCESS" "NewSigner desktop shortcut created"
}

# Configure NewSigner
configure_newsigner() {
    log "INFO" "Configuring NewSigner..."
    
    local real_user="$(get_real_user)"
    local real_home="$(get_real_home)"
    local config_dir="${real_home}/.config/newsigner"
    
    mkdir -p "$config_dir"
    
    # Create default configuration
    local config_file="${config_dir}/config.ini"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" <<EOF
[General]
Language=en
Theme=default
LogLevel=info

[Security]
VerifySignature=true
TrustStore=/etc/ssl/certs

[Network]
ProxyEnabled=false
ProxyHost=
ProxyPort=

[Paths]
Documents=${real_home}/Documents
Downloads=${real_home}/Downloads
EOF
        chown -R "$real_user":"$real_user" "$config_dir" 2>/dev/null || true
        log "SUCCESS" "NewSigner configured with default settings"
    else
        log "INFO" "NewSigner configuration already exists"
    fi
}

# =============================================================================
# DigiSigner JAR Installation
# =============================================================================

install_digisigner_jar() {
    log_section "DigiSigner JAR Installation"
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║        📄 DigiSigner JAR Installation                    ║"
    echo "  ║        Digital Signature Application                     ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    # Check internet connection
    if ! check_internet; then
        log "ERROR" "Internet connection required for DigiSigner installation"
        return 1
    fi
    
    # Check Java
    echo -e "${HACKER_BLUE}  [*] Checking Java installation...${RESET}"
    if ! command_exists java; then
        log "WARNING" "Java is not installed"
        echo -e "${BRIGHT_YELLOW}  [⚠] Java is required for DigiSigner.${RESET}"
        if confirm "Install OpenJDK JRE now?"; then
            apt_update || return 1
            install_packages "default-jre" || return 1
        else
            FAILED_TASKS+=("DigiSigner JAR")
            return 1
        fi
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | head -1)
    echo -e "${BRIGHT_GREEN}  [✓] Detected Java: ${WHITE}$JAVA_VERSION${RESET}"
    
    # Setup installation directory
    local real_user="$(get_real_user)"
    local real_home="$(get_real_home)"
    local INSTALL_DIR="${real_home}/DigiSigner"
    local DESKTOP_FILE="${real_home}/Desktop/DigiSigner.desktop"
    local JAR_URL="https://raw.githubusercontent.com/EcourtSO/EcourtSO/main/DigiSigner-4.0/DigiSigner.jar"
    
    echo -e "${HACKER_BLUE}  [*] Creating installation directory...${RESET}"
    mkdir -p "$INSTALL_DIR"
    echo -e "${BRIGHT_GREEN}  [✓] Directory created: ${WHITE}$INSTALL_DIR${RESET}"
    
    # Download DigiSigner JAR
    echo -e "${HACKER_BLUE}  [*] Downloading DigiSigner from GitHub...${RESET}"
    echo -e "${HACKER_ORANGE}  [*] URL: ${WHITE}$JAR_URL${RESET}"
    
    if wget -q --show-progress -O "$INSTALL_DIR/DigiSigner.jar" "$JAR_URL" 2>&1; then
        echo -e "${BRIGHT_GREEN}  [✓] DigiSigner downloaded successfully${RESET}"
    else
        log "ERROR" "Failed to download DigiSigner JAR"
        echo -e "${BRIGHT_RED}  [!] Download failed. Please check your internet connection.${RESET}"
        FAILED_TASKS+=("DigiSigner JAR")
        return 1
    fi
    
    # Set permissions
    chown -R "$real_user":"$real_user" "$INSTALL_DIR" 2>/dev/null || true
    
    # Create desktop shortcut
    echo -e "${HACKER_BLUE}  [*] Creating desktop shortcut...${RESET}"
    
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=DigiSigner
Comment=Launch DigiSigner
Exec=java -jar $INSTALL_DIR/DigiSigner.jar
Icon=application-x-java-archive
Terminal=false
Categories=Office;Utility;
EOF
    
    chown "$real_user":"$real_user" "$DESKTOP_FILE" 2>/dev/null || true
    chmod +x "$DESKTOP_FILE"
    
    # Trust launcher on GNOME
    if command_exists gio; then
        sudo -u "$real_user" gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true
        echo -e "${BRIGHT_GREEN}  [✓] Desktop file trusted${RESET}"
    fi
    
    echo
    echo -e "${BRIGHT_GREEN}${BOLD}  ═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BRIGHT_GREEN}${BOLD}  [✓] DigiSigner installed successfully!${RESET}"
    echo -e "${HACKER_ORANGE}  [*] JAR Location : ${WHITE}$INSTALL_DIR/DigiSigner.jar${RESET}"
    echo -e "${HACKER_ORANGE}  [*] Desktop Icon : ${WHITE}$DESKTOP_FILE${RESET}"
    echo -e "${BRIGHT_YELLOW}  [⚠] If the icon doesn't launch immediately, right-click it and select 'Allow Launching'.${RESET}"
    echo -e "${BRIGHT_GREEN}${BOLD}  ═══════════════════════════════════════════════════════════${RESET}"
    
    # Ask to launch
    if confirm "Launch DigiSigner now?"; then
        echo -e "${HACKER_BLUE}  [*] Launching DigiSigner...${RESET}"
        sudo -u "$real_user" java -jar "$INSTALL_DIR/DigiSigner.jar" &
        echo -e "${BRIGHT_GREEN}  [✓] DigiSigner launched${RESET}"
    fi
    
    log "SUCCESS" "DigiSigner JAR installed successfully"
    return 0
}

# =============================================================================
# PDF Signer Java Path Fix Function
# =============================================================================

fix_pdf_signer() {
    log_section "PDF Signer Java Path Fix"
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║        🔧 PDF Signer Java Path Fix                       ║"
    echo "  ║        Author: Sopan Abdal                               ║"
    echo "  ║        Purpose: Fix PDF Signer Java path on Ubuntu       ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    if ! confirm "Fix PDF Signer Java path?"; then
        log "INFO" "PDF Signer fix skipped"
        return 0
    fi
    
    local APP_DIR="/opt/apps/com.digisigner.pdfsigner/files"
    local SCRIPT="$APP_DIR/start.sh"
    
    echo -e "${HACKER_BLUE}  [*] Checking Java installation...${RESET}"
    if ! command_exists java; then
        log "ERROR" "Java is not installed"
        echo -e "${BRIGHT_YELLOW}  [⚠] Java is not installed.${RESET}"
        echo -e "  Install it using:"
        echo -e "  ${HACKER_NEON_GREEN}sudo apt update${RESET}"
        echo -e "  ${HACKER_NEON_GREEN}sudo apt install openjdk-8-jre${RESET}"
        echo
        if confirm "Install OpenJDK 8 JRE now?"; then
            apt_update || return 1
            install_packages "openjdk-8-jre" || return 1
        else
            FAILED_TASKS+=("PDF Signer Fix")
            return 1
        fi
    fi
    
    JAVA_PATH=$(readlink -f "$(which java)")
    echo -e "${BRIGHT_GREEN}  [✓] Detected Java: ${WHITE}$JAVA_PATH${RESET}"
    
    echo -e "${HACKER_BLUE}  [*] Checking PDF Signer installation...${RESET}"
    if [[ ! -f "$SCRIPT" ]]; then
        log "ERROR" "PDF Signer not found at: $SCRIPT"
        echo -e "${BRIGHT_RED}  [!] ERROR: $SCRIPT not found.${RESET}"
        echo -e "  ${BRIGHT_YELLOW}[⚠] Please make sure PDF Signer is installed.${RESET}"
        FAILED_TASKS+=("PDF Signer Fix")
        return 1
    fi
    echo -e "${BRIGHT_GREEN}  [✓] Found start.sh at: ${WHITE}$SCRIPT${RESET}"
    
    BACKUP="$SCRIPT.$(date +%Y%m%d_%H%M%S).bak"
    cp "$SCRIPT" "$BACKUP"
    echo -e "${BRIGHT_GREEN}  [✓] Backup created: ${WHITE}$BACKUP${RESET}"
    
    echo -e "${HACKER_BLUE}  [*] Updating Java path in start.sh...${RESET}"
    sed -i 's|/usr/local/jdk1.8.0_181/bin/java|/usr/bin/java|g' "$SCRIPT"
    sed -i 's|^export PATH=.*|export PATH=$PATH:/usr/bin|g' "$SCRIPT"
    
    chmod +x "$SCRIPT"
    echo -e "${BRIGHT_GREEN}  [✓] start.sh updated and made executable${RESET}"
    
    echo
    echo -e "${HACKER_NEON_GREEN}  ═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${HACKER_ORANGE}  [*] Updated start.sh content:${RESET}"
    echo -e "${HACKER_NEON_GREEN}  ═══════════════════════════════════════════════════════════${RESET}"
    cat "$SCRIPT" | sed 's/^/  /'
    echo -e "${HACKER_NEON_GREEN}  ═══════════════════════════════════════════════════════════${RESET}"
    echo
    
    echo -e "${HACKER_BLUE}  [*] Testing Java...${RESET}"
    if /usr/bin/java -version 2>&1 | head -1; then
        echo -e "${BRIGHT_GREEN}  [✓] Java is working correctly${RESET}"
    else
        log "ERROR" "Java test failed"
        echo -e "${BRIGHT_RED}  [!] Java test failed${RESET}"
        FAILED_TASKS+=("PDF Signer Fix")
        return 1
    fi
    
    echo
    echo -e "${BRIGHT_GREEN}${BOLD}  [✓] Fix completed successfully!${RESET}"
    echo -e "${HACKER_ORANGE}  [*] Backup saved at: $BACKUP${RESET}"
    
    echo
    if confirm "Launch PDF Signer now?"; then
        echo -e "${HACKER_BLUE}  [*] Launching PDF Signer...${RESET}"
        if command_exists gtk-launch; then
            gtk-launch "PDF Signer" 2>/dev/null || "$SCRIPT"
        else
            "$SCRIPT"
        fi
        echo -e "${BRIGHT_GREEN}  [✓] PDF Signer launched${RESET}"
    fi
    
    log "SUCCESS" "PDF Signer Java path fixed"
    return 0
}

# =============================================================================
# Printer Driver Installation Functions
# =============================================================================

install_naps() {
    log_section "Installing NAPS Scanner"
    
    if ! confirm "Install NAPS2 scanner application?"; then
        log "INFO" "NAPS2 installation skipped"
        return 0
    fi
    
    if add_repository \
        "https://downloads.naps2.com ./" \
        "naps2" \
        "https://www.naps2.com/naps2-public.pgp"; then
        
        if install_packages "naps2"; then
            log "SUCCESS" "NAPS2 installed successfully"
            return 0
        fi
    fi
    
    log "ERROR" "NAPS2 installation failed"
    FAILED_TASKS+=("NAPS2")
    return 1
}

install_epson() {
    log_section "Installing Epson Drivers"
    
    if ! confirm "Install Epson printer and scanner drivers?"; then
        log "INFO" "Epson driver installation skipped"
        return 0
    fi
    
    apt_update || return 1
    install_packages "lsb" "lsb-core" || return 1
    
    setup_files || return 1
    
    local printer_deb="$(find "$FILES_DIR" -name 'epson-inkjet-printer-escpr2_*.deb' 2>/dev/null | head -1)"
    if [[ -n "$printer_deb" ]]; then
        install_deb "$printer_deb" "Epson Printer Driver"
    else
        log "WARNING" "Epson printer driver not found"
    fi
    
    local scanner_script="$(find "$FILES_DIR" -name 'epsonscan2-bundle-*.deb/install.sh' 2>/dev/null | head -1)"
    if [[ -n "$scanner_script" ]] && [[ -f "$scanner_script" ]]; then
        log "INFO" "Installing Epson scanner driver..."
        if (cd "$(dirname "$scanner_script")" && ./install.sh); then
            log "SUCCESS" "Epson scanner driver installed"
        else
            log "ERROR" "Failed to install Epson scanner driver"
        fi
    else
        log "WARNING" "Epson scanner driver not found"
    fi
    
    if package_installed "ipp-usb"; then
        log "INFO" "Removing conflicting package: ipp-usb"
        apt-get purge -y ipp-usb
    fi
    
    log "SUCCESS" "Epson drivers installation completed"
    return 0
}

install_fujitsu() {
    log_section "Installing Fujitsu Scanner Driver"
    
    if ! confirm "Install Fujitsu scanner driver?"; then
        log "INFO" "Fujitsu driver installation skipped"
        return 0
    fi
    
    setup_files || return 1
    
    local driver_deb="$(find "$FILES_DIR" -name 'pfufs-ubuntu_*.deb' 2>/dev/null | head -1)"
    if [[ -n "$driver_deb" ]]; then
        install_deb "$driver_deb" "Fujitsu Scanner Driver"
    else
        log "ERROR" "Fujitsu driver package not found"
        FAILED_TASKS+=("Fujitsu Driver")
        return 1
    fi
}

install_hp() {
    log_section "Installing HP Printer Drivers"
    
    if ! confirm "Install HP printer drivers (HPLIP)?"; then
        log "INFO" "HP driver installation skipped"
        return 0
    fi
    
    apt_update || return 1
    install_packages "hplip" "hplip-gui" || return 1
    
    if command_exists hp-plugin; then
        hp-plugin -i 2>/dev/null || true
    fi
    
    log "SUCCESS" "HP drivers installed"
    return 0
}

install_canon_common() {
    local model="$1"
    local driver_file="$2"
    
    log_section "Installing Canon $model Driver"
    
    if ! confirm "Install Canon $model printer driver?"; then
        log "INFO" "Canon $model installation skipped"
        return 0
    fi
    
    setup_files || return 1
    
    local driver_path="${FILES_DIR}/$driver_file"
    if [[ -f "$driver_path" ]]; then
        install_deb "$driver_path" "Canon $model"
    else
        log "ERROR" "Canon $model driver not found: $driver_file"
        FAILED_TASKS+=("Canon $model")
        return 1
    fi
}

install_canon_246() {
    install_canon_common "246" "Canon_246.deb"
}

install_canon_465() {
    install_canon_common "465" "Canon_465.deb"
}

install_canon_auto() {
    log_section "Auto-detecting Canon Printer"
    
    if ! confirm "Auto-detect and install Canon printer driver?"; then
        log "INFO" "Canon auto-detection skipped"
        return 0
    fi
    
    local canon_usb=$(lsusb | grep -i "Canon" | head -1)
    
    if [[ -z "$canon_usb" ]]; then
        log "WARNING" "No Canon printer detected via USB"
        echo -e "${BRIGHT_YELLOW}  [⚠] Please connect your Canon printer via USB and try again${RESET}"
        return 0
    fi
    
    log "INFO" "Detected: $canon_usb"
    
    local product_id=$(echo "$canon_usb" | sed -n 's/.*04a9:\([0-9a-fA-F]\{4\}\).*/\1/p')
    
    if [[ -z "$product_id" ]]; then
        log "ERROR" "Failed to extract Canon product ID"
        return 1
    fi
    
    log "INFO" "Product ID: $product_id"
    
    local driver_file=""
    local model=""
    
    case "$product_id" in
        27b6|27b7|27b8)
            driver_file="Canon_246.deb"
            model="Canon 246 series"
            ;;
        2821|2822|2823)
            driver_file="Canon_465.deb"
            model="Canon 465 series"
            ;;
        *)
            log "WARNING" "Unknown Canon product ID: $product_id"
            echo -e "${BRIGHT_YELLOW}  [⚠] No driver mapped for this Canon model${RESET}"
            return 0
            ;;
    esac
    
    if [[ -n "$driver_file" ]]; then
        log "INFO" "Installing driver for: $model"
        setup_files || return 1
        
        local driver_path="${FILES_DIR}/$driver_file"
        if [[ -f "$driver_path" ]]; then
            install_deb "$driver_path" "$model"
        else
            log "ERROR" "Driver file not found: $driver_file"
            FAILED_TASKS+=("Canon $model")
            return 1
        fi
    fi
}

# =============================================================================
# System Tools Installation Functions
# =============================================================================

install_apps() {
    log_section "Installing Basic Applications"
    
    if ! confirm "Install basic system applications?"; then
        log "INFO" "Basic applications installation skipped"
        return 0
    fi
    
    apt_update || return 1
    
    local apps=(
        openssh-server net-tools curl wget gnupg ca-certificates
        software-properties-common
        zip unzip p7zip-full rar unrar
        nano vim htop tree neofetch
        dolphin diodon goldendict goldendict-wordnet gparted vlc
        cups cups-client printer-driver-all
    )
    
    if install_packages "${apps[@]}"; then
        if command_exists cups; then
            systemctl enable cups || true
            systemctl start cups || true
            log "SUCCESS" "CUPS enabled and started"
        fi
        return 0
    else
        FAILED_TASKS+=("Basic Apps")
        return 1
    fi
}

install_proxykey() {
    log_section "Installing Proxykey"
    
    if ! confirm "Install or update Proxykey?"; then
        log "INFO" "Proxykey installation skipped"
        return 0
    fi
    
    setup_files || return 1
    
    local proxykey_deb="$(find "$FILES_DIR" -name 'proxkey_ubantu.deb' 2>/dev/null | head -1)"
    if [[ -n "$proxykey_deb" ]]; then
        install_deb "$proxykey_deb" "Proxykey"
    else
        log "ERROR" "Proxykey package not found"
        FAILED_TASKS+=("Proxykey")
        return 1
    fi
}

repair_anydesk() {
    log_section "Repairing AnyDesk"
    
    if ! confirm "Repair AnyDesk (remove corrupted config)?"; then
        log "INFO" "AnyDesk repair skipped"
        return 0
    fi
    
    add_repository \
        "http://deb.anydesk.com/ all main" \
        "anydesk" \
        "https://keys.anydesk.com/repos/DEB-GPG-KEY" || return 1
    
    if ! command_exists anydesk; then
        install_packages "anydesk" || return 1
    else
        apt_update && install_packages "anydesk"
    fi
    
    systemctl stop anydesk 2>/dev/null || true
    
    local anydesk_dirs=("/etc/anydesk" "/root/.anydesk")
    local user_home="$(get_real_home)"
    [[ -d "$user_home/.anydesk" ]] && anydesk_dirs+=("$user_home/.anydesk")
    
    for dir in "${anydesk_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log "INFO" "Removing: $dir"
            rm -rf "$dir"
        fi
    done
    
    systemctl daemon-reload
    systemctl enable anydesk
    systemctl start anydesk
    
    sleep 3
    
    if systemctl is-active --quiet anydesk; then
        log "SUCCESS" "AnyDesk repaired successfully"
        REBOOT_REQUIRED=true
        return 0
    else
        log "ERROR" "AnyDesk service failed to start"
        log "INFO" "Check logs: journalctl -u anydesk --no-pager | tail -50"
        FAILED_TASKS+=("AnyDesk Repair")
        return 1
    fi
}

setup_hotspot() {
    log_section "Setting up Wi-Fi Hotspot"
    
    if ! confirm "Setup Wi-Fi hotspot with auto-start?"; then
        log "INFO" "Hotspot setup skipped"
        return 0
    fi
    
    if ! command_exists nmcli; then
        install_packages "network-manager" || return 1
    fi
    
    local wifi_interface=$(nmcli -t -f TYPE,DEVICE device status | grep -E '^wifi' | cut -d: -f2 | head -1)
    
    if [[ -z "$wifi_interface" ]]; then
        log "ERROR" "No Wi-Fi interface found"
        FAILED_TASKS+=("Hotspot")
        return 1
    fi
    
    log "INFO" "Using Wi-Fi interface: $wifi_interface"
    
    nmcli radio wifi on
    
    if ! nmcli connection show "Hotspot" &> /dev/null; then
        log "INFO" "Creating new hotspot connection"
        nmcli connection add type wifi ifname "$wifi_interface" \
            con-name "Hotspot" \
            autoconnect yes \
            ssid "${CONFIG[HOTSPOT_NAME]}"
        
        nmcli connection modify "Hotspot" \
            802-11-wireless.mode ap \
            ipv4.method shared \
            wifi-sec.key-mgmt wpa-psk \
            wifi-sec.psk "${CONFIG[HOTSPOT_PASSWORD]}"
        
        local config_file=$(find /etc/NetworkManager/system-connections/ -name '*Hotspot*' 2>/dev/null | head -1)
        [[ -f "$config_file" ]] && chmod 600 "$config_file"
    fi
    
    systemctl restart NetworkManager
    
    local service_file="/etc/systemd/system/wifi-hotspot.service"
    cat > "$service_file" <<EOF
[Unit]
Description=Start WiFi Hotspot
After=NetworkManager.service
Requires=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/bin/nmcli connection up Hotspot
Restart=on-failure
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable wifi-hotspot.service
    systemctl start wifi-hotspot.service
    
    log "SUCCESS" "Hotspot setup completed"
    log "INFO" "SSID: ${CONFIG[HOTSPOT_NAME]}, Password: ${CONFIG[HOTSPOT_PASSWORD]}"
    REBOOT_REQUIRED=true
    return 0
}

reset_cups() {
    log_section "Resetting CUPS"
    
    if ! confirm "Reset CUPS configuration and restart service?"; then
        log "INFO" "CUPS reset skipped"
        return 0
    fi
    
    if [[ -f "/etc/cups/cupsd.conf" ]]; then
        local backup="/etc/cups/cupsd.conf.backup.$(date +%Y%m%d_%H%M%S)"
        cp "/etc/cups/cupsd.conf" "$backup"
        log "INFO" "CUPS config backed up to: $backup"
    fi
    
    if [[ -f "/usr/share/cups/cupsd.conf.default" ]]; then
        cp "/usr/share/cups/cupsd.conf.default" "/etc/cups/cupsd.conf"
        log "SUCCESS" "CUPS config restored to default"
    else
        log "ERROR" "Default CUPS config not found"
        return 1
    fi
    
    systemctl restart cups
    
    if systemctl is-active --quiet cups; then
        log "SUCCESS" "CUPS service restarted successfully"
        return 0
    else
        log "ERROR" "CUPS service failed to restart"
        FAILED_TASKS+=("CUPS Reset")
        return 1
    fi
}

# =============================================================================
# Brightness Control Functions
# =============================================================================

check_ddc_support() {
    log "INFO" "Checking DDC/CI support..."
    
    if ! command_exists ddcutil; then
        log "WARNING" "ddcutil not installed"
        return 1
    fi
    
    local displays=$(ddcutil detect 2>/dev/null | grep -c "Display" || echo "0")
    
    if [[ "$displays" -eq 0 ]]; then
        log "WARNING" "No DDC/CI capable displays detected"
        return 1
    fi
    
    if ! ddcutil getvcp 10 2>/dev/null | grep -q "current value"; then
        log "WARNING" "Cannot read brightness via DDC/CI"
        return 1
    fi
    
    return 0
}

install_brightness_deps() {
    log "INFO" "Installing brightness control dependencies..."
    
    apt_update || return 1
    install_packages "ddcutil" "i2c-tools" || return 1
    
    local real_user="$(get_real_user)"
    if [[ "$real_user" != "root" ]]; then
        usermod -aG i2c "$real_user" 2>/dev/null || true
        log "INFO" "User $real_user added to i2c group (reboot required for this to take effect)"
    fi
    
    if ! lsmod | grep -q i2c_dev; then
        modprobe i2c_dev 2>/dev/null || true
        echo "i2c_dev" >> /etc/modules 2>/dev/null || true
        log "INFO" "i2c_dev kernel module loaded"
    fi
    
    if [[ -e "/dev/i2c-0" ]]; then
        chmod 666 /dev/i2c-* 2>/dev/null || true
    fi
    
    REBOOT_REQUIRED=true
    log "SUCCESS" "Brightness dependencies installed"
    return 0
}

get_current_brightness() {
    local brightness="Unknown"
    
    if command_exists ddcutil; then
        local output=$(ddcutil getvcp 10 2>/dev/null)
        
        if [[ -n "$output" ]]; then
            brightness=$(echo "$output" | grep -oP '(?<=current value = )\d+' | head -1)
            
            if [[ -z "$brightness" ]]; then
                brightness=$(echo "$output" | grep -oP 'current value\s*=\s*\d+' | grep -oP '\d+' | head -1)
            fi
            
            if [[ -z "$brightness" ]]; then
                brightness=$(echo "$output" | grep -oP '\d+(?=%)' | head -1)
            fi
        fi
    fi
    
    if [[ "$brightness" == "Unknown" ]] || [[ -z "$brightness" ]]; then
        if command_exists xrandr; then
            local xrandr_out=$(xrandr --verbose 2>/dev/null | grep -i "brightness" | head -1)
            if [[ -n "$xrandr_out" ]]; then
                brightness=$(echo "$xrandr_out" | grep -oP '\d+\.\d+' | head -1)
                brightness=$(echo "$brightness * 100" | bc 2>/dev/null | cut -d. -f1)
            fi
        fi
    fi
    
    echo "${brightness:-Unknown}"
}

set_brightness() {
    local value="$1"
    
    if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 0 ]] || [[ "$value" -gt 100 ]]; then
        log "ERROR" "Invalid brightness value: $value (must be 0-100)"
        return 1
    fi
    
    log "INFO" "Setting brightness to $value%"
    
    if command_exists ddcutil; then
        if ddcutil setvcp 10 "$value" 2>/dev/null; then
            log "SUCCESS" "Brightness set to $value% via DDC/CI"
            return 0
        fi
    fi
    
    if command_exists xrandr; then
        local display=$(xrandr 2>/dev/null | grep " connected" | head -1 | cut -d' ' -f1)
        if [[ -n "$display" ]]; then
            local brightness=$(echo "scale=2; $value / 100" | bc 2>/dev/null)
            if xrandr --output "$display" --brightness "$brightness" 2>/dev/null; then
                log "SUCCESS" "Brightness set to $value% via xrandr"
                return 0
            fi
        fi
    fi
    
    if [[ -d "/sys/class/backlight" ]]; then
        local backlight_dir=$(find /sys/class/backlight -maxdepth 1 -type d ! -path /sys/class/backlight | head -1)
        if [[ -n "$backlight_dir" ]]; then
            local max_brightness=$(cat "${backlight_dir}/max_brightness" 2>/dev/null)
            if [[ -n "$max_brightness" ]] && [[ "$max_brightness" -gt 0 ]]; then
                local new_value=$((value * max_brightness / 100))
                echo "$new_value" > "${backlight_dir}/brightness" 2>/dev/null && {
                    log "SUCCESS" "Brightness set to $value% via backlight interface"
                    return 0
                }
            fi
        fi
    fi
    
    log "ERROR" "Failed to set brightness"
    return 1
}

brightness_control() {
    log_section "Brightness Control"
    
    if ! check_ddc_support; then
        echo -e "${BRIGHT_YELLOW}  [⚠] DDC/CI not available or not configured${RESET}"
        echo
        
        if confirm "Install brightness control dependencies?"; then
            if install_brightness_deps; then
                echo -e "${BRIGHT_GREEN}  [✓] Dependencies installed. Please reboot and try again.${RESET}"
                echo -e "${BRIGHT_YELLOW}  [⚠] Note: After reboot, you may need to:${RESET}"
                echo "    1. Run: sudo ddcutil detect"
                echo "    2. Check if your monitor supports DDC/CI"
                return 0
            else
                echo -e "${BRIGHT_RED}  [!] Failed to install dependencies${RESET}"
                return 1
            fi
        else
            log "INFO" "Brightness control setup skipped"
            return 0
        fi
    fi
    
    while true; do
        clear
        show_header
        echo -e "${HACKER_NEON_GREEN}${BOLD}"
        echo "  ╔═══════════════════════════════════════════════════════════╗"
        echo "  ║              💡 BRIGHTNESS CONTROL                       ║"
        echo "  ╚═══════════════════════════════════════════════════════════╝"
        echo -e "${RESET}"
        
        local current=$(get_current_brightness)
        echo -e "  ${HACKER_ORANGE}Current Brightness: ${HACKER_NEON_GREEN}${current}%${RESET}"
        
        if [[ "$current" != "Unknown" ]] && [[ "$current" =~ ^[0-9]+$ ]]; then
            local bar_length=48
            local filled=$((current * bar_length / 100))
            local empty=$((bar_length - filled))
            echo -n "  ["
            for ((i=0; i<filled; i++)); do
                echo -ne "${HACKER_NEON_GREEN}█${RESET}"
            done
            for ((i=0; i<empty; i++)); do
                echo -ne "${HACKER_DARK_GREEN}░${RESET}"
            done
            echo "] ${current}%"
        fi
        
        echo
        echo -e "  ${HACKER_NEON_GREEN}1.${RESET} Increase Brightness (+10)"
        echo -e "  ${HACKER_NEON_GREEN}2.${RESET} Decrease Brightness (-10)"
        echo -e "  ${HACKER_NEON_GREEN}3.${RESET} Set Custom Value (0-100)"
        echo -e "  ${HACKER_NEON_GREEN}4.${RESET} Set to 50% (Recommended)"
        echo -e "  ${HACKER_NEON_GREEN}5.${RESET} Set to 30% (Low)"
        echo -e "  ${HACKER_NEON_GREEN}6.${RESET} Set to 80% (High)"
        echo -e "  ${HACKER_NEON_GREEN}7.${RESET} Detect Displays"
        echo -e "  ${HACKER_NEON_GREEN}8.${RESET} Return to Main Menu"
        echo
        echo -ne "${HACKER_NEON_GREEN}${BOLD}  [?] Choose option: ${RESET}"
        read opt
        
        case "$opt" in
            1)
                if [[ "$current" != "Unknown" ]] && [[ "$current" =~ ^[0-9]+$ ]]; then
                    local new=$((current + 10))
                    [[ $new -gt 100 ]] && new=100
                    set_brightness "$new" || echo -e "${BRIGHT_RED}  [!] Failed to set brightness${RESET}"
                else
                    echo -e "${BRIGHT_YELLOW}  [⚠] Cannot determine current brightness${RESET}"
                fi
                sleep 1
                ;;
            2)
                if [[ "$current" != "Unknown" ]] && [[ "$current" =~ ^[0-9]+$ ]]; then
                    local new=$((current - 10))
                    [[ $new -lt 0 ]] && new=0
                    set_brightness "$new" || echo -e "${BRIGHT_RED}  [!] Failed to set brightness${RESET}"
                else
                    echo -e "${BRIGHT_YELLOW}  [⚠] Cannot determine current brightness${RESET}"
                fi
                sleep 1
                ;;
            3)
                echo -ne "${HACKER_NEON_GREEN}  [?] Enter brightness value (0-100): ${RESET}"
                read custom
                if [[ "$custom" =~ ^[0-9]+$ ]] && [[ $custom -ge 0 ]] && [[ $custom -le 100 ]]; then
                    set_brightness "$custom" || echo -e "${BRIGHT_RED}  [!] Failed to set brightness${RESET}"
                else
                    echo -e "${BRIGHT_RED}  [!] Invalid value. Please enter a number between 0 and 100${RESET}"
                fi
                sleep 1
                ;;
            4)
                set_brightness 50 || echo -e "${BRIGHT_RED}  [!] Failed to set brightness${RESET}"
                sleep 1
                ;;
            5)
                set_brightness 30 || echo -e "${BRIGHT_RED}  [!] Failed to set brightness${RESET}"
                sleep 1
                ;;
            6)
                set_brightness 80 || echo -e "${BRIGHT_RED}  [!] Failed to set brightness${RESET}"
                sleep 1
                ;;
            7)
                echo -e "${HACKER_BLUE}  [*] Detecting displays...${RESET}"
                ddcutil detect 2>/dev/null || echo -e "${BRIGHT_YELLOW}  [⚠] No DDC/CI displays found${RESET}"
                echo
                read -p "  Press Enter to continue..."
                ;;
            8)
                log "INFO" "Exiting brightness control"
                return 0
                ;;
            *)
                echo -e "${BRIGHT_RED}  [!] Invalid option${RESET}"
                sleep 1
                ;;
        esac
    done
}

brightness_control_simple() {
    log_section "Simple Brightness Control"
    
    if ! command_exists brightnessctl; then
        if confirm "Install brightnessctl for laptop brightness control?"; then
            install_packages "brightnessctl" || return 1
        else
            return 0
        fi
    fi
    
    local current=$(brightnessctl get 2>/dev/null)
    local max=$(brightnessctl max 2>/dev/null)
    
    if [[ -z "$current" ]] || [[ -z "$max" ]]; then
        log "ERROR" "Failed to read brightness"
        return 1
    fi
    
    local current_percent=$((current * 100 / max))
    
    while true; do
        clear
        show_header
        echo -e "${HACKER_NEON_GREEN}${BOLD}"
        echo "  ╔═══════════════════════════════════════════════════════════╗"
        echo "  ║              💡 LAPTOP BRIGHTNESS                       ║"
        echo "  ╚═══════════════════════════════════════════════════════════╝"
        echo -e "${RESET}"
        echo -e "  ${HACKER_ORANGE}Current: ${HACKER_NEON_GREEN}${current_percent}%${RESET}"
        echo
        echo -e "  ${HACKER_NEON_GREEN}1.${RESET} Increase (+10%)"
        echo -e "  ${HACKER_NEON_GREEN}2.${RESET} Decrease (-10%)"
        echo -e "  ${HACKER_NEON_GREEN}3.${RESET} Set custom value"
        echo -e "  ${HACKER_NEON_GREEN}4.${RESET} Return to menu"
        echo
        echo -ne "${HACKER_NEON_GREEN}${BOLD}  [?] Choose option: ${RESET}"
        read opt
        
        case "$opt" in
            1)
                brightnessctl set +10% 2>/dev/null
                current_percent=$((current_percent + 10))
                [[ $current_percent -gt 100 ]] && current_percent=100
                ;;
            2)
                brightnessctl set 10%- 2>/dev/null
                current_percent=$((current_percent - 10))
                [[ $current_percent -lt 0 ]] && current_percent=0
                ;;
            3)
                echo -ne "${HACKER_NEON_GREEN}  [?] Enter value (0-100): ${RESET}"
                read val
                if [[ "$val" =~ ^[0-9]+$ ]] && [[ $val -ge 0 ]] && [[ $val -le 100 ]]; then
                    brightnessctl set "$val%" 2>/dev/null
                    current_percent=$val
                fi
                ;;
            4)
                return 0
                ;;
            *)
                echo -e "${BRIGHT_RED}  [!] Invalid option${RESET}"
                sleep 1
                ;;
        esac
    done
}

brightness_control_main() {
    log_section "Brightness Control Setup"
    
    if [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
        log "WARNING" "No display environment detected"
        echo -e "${BRIGHT_YELLOW}  [⚠] Brightness control works best in GUI environment${RESET}"
        echo -e "  For headless systems, use external monitor controls"
        
        if ! confirm "Continue anyway?"; then
            return 0
        fi
    fi
    
    if [[ -d "/sys/class/backlight" ]] && command_exists brightnessctl; then
        log "INFO" "Using laptop backlight interface"
        brightness_control_simple
        return $?
    fi
    
    if command_exists ddcutil; then
        log "INFO" "Using DDC/CI interface"
        brightness_control
        return $?
    fi
    
    echo -e "${BRIGHT_YELLOW}  [⚠] No brightness control method detected${RESET}"
    echo
    echo "  Options:"
    echo "  1. Install DDC/CI (for external monitors)"
    echo "  2. Install brightnessctl (for laptops)"
    echo "  3. Skip brightness control"
    echo
    echo -ne "${HACKER_NEON_GREEN}  [?] Choose option [1-3]: ${RESET}"
    read choice
    
    case "$choice" in
        1)
            if install_brightness_deps; then
                echo -e "${BRIGHT_GREEN}  [✓] Installed DDC/CI tools${RESET}"
                echo -e "${BRIGHT_YELLOW}  [⚠] Please reboot and try again${RESET}"
                REBOOT_REQUIRED=true
            fi
            ;;
        2)
            install_packages "brightnessctl" || return 1
            brightness_control_simple
            ;;
        *)
            log "INFO" "Brightness control skipped"
            return 0
            ;;
    esac
    
    return 0
}

# =============================================================================
# System Maintenance Functions
# =============================================================================

system_cleanup() {
    log_section "System Cleanup & Optimization"
    
    if ! confirm "Perform system cleanup and optimization?"; then
        log "INFO" "Cleanup skipped"
        return 0
    fi
    
    echo -e "${HACKER_BLUE}  [*] Cleaning package cache...${RESET}"
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y
    
    echo -e "${HACKER_BLUE}  [*] Clearing temporary files...${RESET}"
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
    
    echo -e "${HACKER_BLUE}  [*] Clearing system logs...${RESET}"
    journalctl --rotate 2>/dev/null || true
    journalctl --vacuum-time=3d 2>/dev/null || true
    
    echo -e "${HACKER_BLUE}  [*] Clearing thumbnail cache...${RESET}"
    local real_user="$(get_real_user)"
    local real_home="$(get_real_home)"
    rm -rf "$real_home/.cache/thumbnails/*" 2>/dev/null || true
    
    log "SUCCESS" "System cleanup completed"
    return 0
}

backup_config() {
    log_section "Backup Configuration"
    
    if ! confirm "Backup system configuration?"; then
        log "INFO" "Backup skipped"
        return 0
    fi
    
    local backup_dir="${SCRIPT_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    local configs=(
        "/etc/cups"
        "/etc/NetworkManager"
        "/etc/default/grub"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/fstab"
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d"
    )
    
    for config in "${configs[@]}"; do
        if [[ -e "$config" ]]; then
            cp -r "$config" "$backup_dir/" 2>/dev/null || true
            echo -e "${BRIGHT_GREEN}  [✓] Backed up: $config${RESET}"
        fi
    done
    
    echo -e "${BRIGHT_GREEN}  [✓] Backup saved to: $backup_dir${RESET}"
    log "SUCCESS" "Configuration backup completed"
    return 0
}

restore_config() {
    log_section "Restore Configuration"
    
    if ! confirm "Restore configuration from backup?"; then
        log "INFO" "Restore skipped"
        return 0
    fi
    
    local latest_backup=$(find "$SCRIPT_DIR" -maxdepth 1 -type d -name "backup_*" 2>/dev/null | sort -r | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        echo -e "${BRIGHT_RED}  [!] No backup found${RESET}"
        return 1
    fi
    
    echo -e "${HACKER_ORANGE}  [*] Found backup: $latest_backup${RESET}"
    if confirm "Restore from this backup?"; then
        cp -r "$latest_backup"/* / 2>/dev/null || true
        echo -e "${BRIGHT_GREEN}  [✓] Configuration restored${RESET}"
        REBOOT_REQUIRED=true
    fi
    
    return 0
}

# =============================================================================
# Security Hardening Functions
# =============================================================================

security_hardening() {
    log_section "Security Hardening"
    
    if ! confirm "Apply security hardening measures?"; then
        log "INFO" "Security hardening skipped"
        return 0
    fi
    
    echo -e "${HACKER_BLUE}  [*] Applying security hardening...${RESET}"
    
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null || true
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null || true
        systemctl restart sshd
        echo -e "${BRIGHT_GREEN}  [✓] Disabled root SSH login${RESET}"
    fi
    
    echo "umask 027" >> /etc/profile 2>/dev/null || true
    echo -e "${BRIGHT_GREEN}  [✓] Set secure umask${RESET}"
    
    if ! package_installed ufw; then
        install_packages "ufw" || true
    fi
    ufw default deny incoming 2>/dev/null || true
    ufw default allow outgoing 2>/dev/null || true
    echo -e "${BRIGHT_GREEN}  [✓] Configured firewall (UFW)${RESET}"
    
    log "SUCCESS" "Security hardening applied"
    return 0
}

# =============================================================================
# System Information Functions
# =============================================================================

show_system_info() {
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║              📊 SYSTEM INFORMATION                       ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    echo -e "  ${HACKER_ORANGE}CPU:${RESET}       $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
    echo -e "  ${HACKER_ORANGE}CPU Cores:${RESET} $(nproc)"
    echo -e "  ${HACKER_ORANGE}RAM:${RESET}       $(free -h | awk '/Mem:/ {print $2}')"
    echo -e "  ${HACKER_ORANGE}RAM Used:${RESET}  $(free -h | awk '/Mem:/ {print $3}')"
    echo -e "  ${HACKER_ORANGE}Disk:${RESET}      $(df -h / | awk 'NR==2 {print $2}')"
    echo -e "  ${HACKER_ORANGE}Disk Used:${RESET} $(df -h / | awk 'NR==2 {print $3}')"
    echo -e "  ${HACKER_ORANGE}GPU:${RESET}       $(lspci | grep -i vga | cut -d: -f3 | xargs)"
    echo -e "  ${HACKER_ORANGE}OS:${RESET}        $(lsb_release -ds 2>/dev/null)"
    echo -e "  ${HACKER_ORANGE}Kernel:${RESET}    $(uname -r)"
    echo -e "  ${HACKER_ORANGE}Uptime:${RESET}    $(uptime -p)"
    echo -e "  ${HACKER_ORANGE}Shell:${RESET}     $SHELL"
    echo -e "  ${HACKER_ORANGE}Terminal:${RESET}  $TERM"
    echo -e "  ${HACKER_ORANGE}User:${RESET}      $(whoami)"
    echo -e "  ${HACKER_ORANGE}Host:${RESET}      $(hostname)"
    
    echo
    echo -ne "${HACKER_NEON_GREEN}  [?] Press Enter to continue...${RESET}"
    read
}

# =============================================================================
# Health Summary Function
# =============================================================================

health_summary() {
    log_section "System Health Summary"
    
    {
        echo "  ╔═══════════════════════════════════════════════════════════╗"
        echo "  ║              🩺 SYSTEM HEALTH SUMMARY                    ║"
        echo "  ╚═══════════════════════════════════════════════════════════╝"
        echo "  ─────────────────────────────────────────────────────────────"
        echo "  [*] Date        : $(date)"
        echo "  [*] Hostname    : $(hostname)"
        echo "  [*] OS          : $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
        echo "  [*] Kernel      : $(uname -r)"
        echo "  [*] Uptime      : $(uptime -p | sed 's/up //')"
        echo "  ─────────────────────────────────────────────────────────────"
        
        echo "  [*] CPU Load    : $(uptime | awk -F'load average:' '{ print $2 }' | xargs)"
        echo "  [*] RAM Usage   : $(free -h | awk '/Mem:/ {printf "%s/%s (%.1f%%)", $3, $2, ($3/$2)*100}')"
        
        echo "  [*] Disk Usage  :"
        df -h / | awk 'NR==2 {printf "     Used: %s, Free: %s, Usage: %s\n", $3, $4, $5}'
        
        if nmcli -t -f STATE general status 2>/dev/null | grep -q connected; then
            echo "  [*] Network     : Connected"
        else
            echo "  [*] Network     : Disconnected"
        fi
        
        for service in cups anydesk NetworkManager; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "  [*] $service : Running"
            else
                echo "  [*] $service : NOT running ⚠️"
            fi
        done
        
        if lsusb | grep -qi "printer\|canon\|epson"; then
            echo "  [*] USB Dev     : Printer detected"
        else
            echo "  [*] USB Dev     : No printer detected"
        fi
        
        local failed_count=$(systemctl --failed --no-legend 2>/dev/null | wc -l || echo "0")
        if [[ $failed_count -eq 0 ]]; then
            echo "  [*] Services    : No failed services"
        else
            echo "  [*] Services    : $failed_count failed ⚠️"
            systemctl --failed --no-legend 2>/dev/null | head -5
        fi
        
        echo "  ─────────────────────────────────────────────────────────────"
        echo "  [*] Log File    : $LOG_FILE"
        echo "  [*] Packages    : $(dpkg -l | grep -c '^ii') installed"
        
        echo "  ╚═══════════════════════════════════════════════════════════╝"
    } | tee -a "$LOG_FILE"
    
    echo -e "\n${BRIGHT_GREEN}  [✓] Health summary displayed above${RESET}"
    echo -ne "${HACKER_NEON_GREEN}  [?] Press Enter to continue...${RESET}"
    read
}

# =============================================================================
# LibreWriter Extension Function
# =============================================================================

install_librewriter_roznama() {
    log_section "Installing LibreWriter Roznama Extension"
    
    if ! confirm "Install LibreWriter Roznama extension?"; then
        log "INFO" "Roznama extension installation skipped"
        return 0
    fi
    
    if ! command_exists libreoffice; then
        if confirm "LibreOffice not found. Install it now?"; then
            install_packages "libreoffice-writer" || return 1
        else
            log "ERROR" "LibreOffice required for extension installation"
            return 1
        fi
    fi
    
    setup_files || return 1
    
    local ext_file="${FILES_DIR}/librewriter_roznama_extension.oxt"
    if [[ ! -f "$ext_file" ]]; then
        log "ERROR" "Roznama extension file not found"
        return 1
    fi
    
    local real_user="$(get_real_user)"
    local real_home="$(get_real_home)"
    
    log "INFO" "Installing for user: $real_user"
    
    if command_exists unopkg; then
        if sudo -u "$real_user" env HOME="$real_home" unopkg add --force "$ext_file" 2>/dev/null; then
            log "SUCCESS" "Roznama extension installed via unopkg"
            return 0
        fi
    fi
    
    if sudo -u "$real_user" env HOME="$real_home" libreoffice \
        --headless --nologo --nodefault --norestore \
        --install-extension "$ext_file" 2>/dev/null; then
        log "SUCCESS" "Roznama extension installed via libreoffice CLI"
        return 0
    fi
    
    log "ERROR" "Failed to install Roznama extension"
    FAILED_TASKS+=("Roznama Extension")
    return 1
}

# =============================================================================
# Main Menu System
# =============================================================================

show_menu() {
    clear
    show_header
    
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║           ⚡ AVAILABLE OPERATIONS ⚡                      ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    echo -e "  ${HACKER_ORANGE}${BOLD}─── Printer Drivers ───${RESET}"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "1." "Install NAPS Scanner" \
        "8." "Install Canon 246 Driver"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "2." "Install Epson Drivers" \
        "9." "Install Canon 465 Driver"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "3." "Install Fujitsu Scanner" \
        "10." "Auto-detect Canon Printer"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "4." "Install HP Printer Drivers"
    
    echo
    echo -e "  ${HACKER_ORANGE}${BOLD}─── System Tools ───${RESET}"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "5." "Install Basic Applications" \
        "12." "Setup Wi-Fi Hotspot"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "6." "Install/Update Proxykey" \
        "13." "Brightness Control"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "7." "Repair AnyDesk" \
        "14." "Reset CUPS"
    
    echo
    echo -e "  ${HACKER_ORANGE}${BOLD}─── Digital Signature Apps ───${RESET}"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "11." "Install Digital Signature Apps" \
        "15." "Fix PDF Signer Java Path"
    
    echo
    echo -e "  ${HACKER_ORANGE}${BOLD}─── Maintenance ───${RESET}"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "16." "System Health Summary" \
        "17." "Install LibreWriter Extension"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "18." "System Cleanup" \
        "19." "Backup Configuration"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "20." "Restore Configuration"
    
    echo
    echo -e "  ${HACKER_ORANGE}${BOLD}─── Advanced ───${RESET}"
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${WHITE}%-28s${RESET}\n" \
        "21." "Security Hardening"
    
    echo
    printf "  ${HACKER_NEON_GREEN}${BOLD}%2s${RESET} ${BRIGHT_RED}%-28s${RESET}\n" \
        "22." "Exit"
    
    echo
    echo -e "${HACKER_MINT}${BOLD}  ════════════════════════════════════════════════════════════${RESET}"
    echo -e "${HACKER_ORANGE}  [*] Developed by: ${WHITE}S. N. Abdal, System Officer, District Court, Pune${RESET}"
    echo -e "${HACKER_MINT}${BOLD}  ════════════════════════════════════════════════════════════${RESET}"
    echo
    
    echo -ne "${HACKER_NEON_GREEN}${BOLD}  [?] Enter target option: ${RESET}"
    read REPLY
    
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [[ "$REPLY" -ge 1 ]] && [[ "$REPLY" -le 22 ]]; then
        if [[ "$REPLY" -eq 22 ]]; then
            echo -e "${BRIGHT_GREEN}${BOLD}  [+] System shutting down...${RESET}"
            exit 0
        fi
        execute_task "$REPLY"
    else
        echo -e "${BRIGHT_RED}  [!] Invalid target${RESET}"
        sleep 1
    fi
}

execute_task() {
    local task_num="$1"
    
    case "$task_num" in
        1) install_naps ;;
        2) install_epson ;;
        3) install_fujitsu ;;
        4) install_hp ;;
        5) install_apps ;;
        6) install_proxykey ;;
        7) repair_anydesk ;;
        8) install_canon_246 ;;
        9) install_canon_465 ;;
        10) install_canon_auto ;;
        11) install_digisigner_unified ;;
        12) setup_hotspot ;;
        13) brightness_control_main ;;
        14) reset_cups ;;
        15) fix_pdf_signer ;;
        16) health_summary ;;
        17) install_librewriter_roznama ;;
        18) system_cleanup ;;
        19) backup_config ;;
        20) restore_config ;;
        21) security_hardening ;;
    esac
    
    echo
    echo -e "${HACKER_MINT}${BOLD}  ───────────────────────────────────────────────────────${RESET}"
    echo -ne "${HACKER_NEON_GREEN}  [?] Press Enter to return to main menu...${RESET}"
    read
}

# =============================================================================
# Initialize Script
# =============================================================================

initialize() {
    check_root
    show_matrix
    
    mkdir -p "$LOG_DIR"
    mkdir -p "$TEMP_DIR"
    
    local required_commands=("curl" "wget" "unzip")
    local missing=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${BRIGHT_YELLOW}  [⚠] Installing missing dependencies: ${missing[*]}${RESET}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
    fi
    
    log "HACKER" "Script initialized by user: $(whoami)"
    log "HACKER" "Log file: $LOG_FILE"
    
    matrix_effect
    echo
}

# =============================================================================
# Summary Report
# =============================================================================

show_summary() {
    echo
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║              📊 INSTALLATION SUMMARY                     ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}  [✓] Successfully installed:${RESET}"
        printf "    %s\n" "${INSTALLED_PACKAGES[@]}" | sort -u
    fi
    
    if [[ ${#FAILED_TASKS[@]} -gt 0 ]]; then
        echo -e "${BRIGHT_RED}  [!] Failed tasks:${RESET}"
        printf "    %s\n" "${FAILED_TASKS[@]}"
    fi
    
    if [[ "$REBOOT_REQUIRED" == true ]]; then
        echo -e "${BRIGHT_YELLOW}  [⚠] A system reboot is recommended to complete setup${RESET}"
    fi
    
    echo
    echo -e "${HACKER_BLUE}  [*] Log file: $LOG_FILE${RESET}"
    echo -e "${HACKER_NEON_GREEN}${BOLD}"
    echo "  ════════════════════════════════════════════════════════════"
    echo -e "  ${HACKER_ORANGE}[==] Script developed by: ${WHITE}S. N. Abdal, System Officer, District Court, Pune${RESET}"
    echo -e "${HACKER_NEON_GREEN}${BOLD}  ════════════════════════════════════════════════════════════${RESET}"
    echo
}

# =============================================================================
# Main Program
# =============================================================================

main() {
    parse_arguments "$@"
    
    initialize
    
    if [[ "$INSTALL_ALL" == "true" ]]; then
        log_section "Installing All Packages"
        install_naps
        install_epson
        install_fujitsu
        install_hp
        install_apps
        install_proxykey
        repair_anydesk
        install_canon_246
        install_canon_465
        install_digisigner_unified
        setup_hotspot
        install_librewriter_roznama
        system_cleanup
        security_hardening
        show_summary
        exit 0
    fi
    
    log_section "Starting Setup Tool"
    
    while true; do
        show_menu
    done
    
    show_summary
    cleanup
    
    log "HACKER" "Script completed"
}

main "$@"