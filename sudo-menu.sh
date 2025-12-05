#!/bin/bash
################################################################################
# Safeguard for SUDO 7.4 - Administrative Menu Script
################################################################################
# Description: Comprehensive menu-driven interface for managing One Identity
#              Safeguard for SUDO deployments including policy management,
#              server administration, plugin hosts, logging, and diagnostics.
#
# Author:      Richard Hosgood
# Repository:  https://github.com/nyrich/Safeguard_Sudo_Menu
# License:     GPL-3.0
#
# Copyright (C) 2025 Richard Hosgood
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# Requirements:
#   - Root privileges
#   - Safeguard for SUDO 7.4 installed
#   - Policy server or plugin host configuration
#
# Usage: sudo ./sudo-menu.sh
################################################################################

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
CHANGELOG_FILE="${SCRIPT_DIR}/CHANGELOG.md"

# Read version from VERSION file, or use default
if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_VERSION=$(cat "$VERSION_FILE")
else
    SCRIPT_VERSION="2.0.0"
fi

SCRIPT_NAME="Safeguard for SUDO Administration Menu"
SCRIPT_DATE="2024-12-05"

# Global Variables
QUEST_BIN="/opt/quest/sbin"
QUEST_CONFIG="/etc/opt/quest/qpm4u"
QUEST_VAR="/var/opt/quest/qpm4u"
POLICY_DIR="${QUEST_CONFIG}/policy"
TEMP_POLICY_DIR="/tmp/policydir"
LOG_DIR="${QUEST_VAR}"
SCRIPT_LOG="/var/log/sudo-menu.log"

# Color codes for better UI (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Function: log_message
# Description: Logs messages to script log file with timestamp
# Parameters: $1 - Message to log
################################################################################
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SCRIPT_LOG"
}

################################################################################
# Function: print_header
# Description: Prints formatted header
# Parameters: $1 - Header text
################################################################################
print_header() {
    echo ""
    echo "==========================================="
    echo "  $1"
    echo "==========================================="
}

################################################################################
# Function: print_error
# Description: Prints error message in red
# Parameters: $1 - Error message
################################################################################
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
    log_message "ERROR: $1"
}

################################################################################
# Function: print_success
# Description: Prints success message in green
# Parameters: $1 - Success message
################################################################################
print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    log_message "SUCCESS: $1"
}

################################################################################
# Function: print_warning
# Description: Prints warning message in yellow
# Parameters: $1 - Warning message
################################################################################
print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    log_message "WARNING: $1"
}

################################################################################
# Function: check_root
# Description: Verifies script is running as root
# Returns: 0 if root, exits otherwise
################################################################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

################################################################################
# Function: check_safeguard_installed
# Description: Verifies Safeguard for SUDO is installed
# Returns: 0 if installed, exits otherwise
################################################################################
check_safeguard_installed() {
    if [[ ! -d "$QUEST_BIN" ]]; then
        print_error "Safeguard for SUDO not found at $QUEST_BIN"
        echo "Please install Safeguard for SUDO before running this script."
        exit 1
    fi
    
    # Check for key commands
    local required_commands=("pmsrvinfo" "pmpolicy" "pmlicense")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if [[ ! -x "${QUEST_BIN}/${cmd}" ]]; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_warning "Some Safeguard commands not found: ${missing_commands[*]}"
        echo "This may be a plugin-only installation."
        echo ""
    fi
}

################################################################################
# Function: check_command_exists
# Description: Checks if a specific Safeguard command exists
# Parameters: $1 - Command name (without path)
# Returns: 0 if exists, 1 otherwise
################################################################################
check_command_exists() {
    local cmd="$1"
    if [[ -x "${QUEST_BIN}/${cmd}" ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Function: run_command
# Description: Executes a command with error handling
# Parameters: $1 - Command to execute
# Returns: Command exit status
################################################################################
run_command() {
    local cmd="$1"
    log_message "Executing: $cmd"
    
    eval "$cmd"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_message "Command completed successfully"
    else
        log_message "Command failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

################################################################################
# Function: pause
# Description: Pauses execution and waits for user input
################################################################################
pause() {
    echo ""
    echo -n "Press [ENTER] to continue..."
    read -r
}

################################################################################
# Function: display_version
# Description: Display version information
################################################################################
display_version() {
    clear
    echo "==========================================="
    echo "  $SCRIPT_NAME"
    echo "==========================================="
    echo "Version: $SCRIPT_VERSION"
    echo "Date: $SCRIPT_DATE"
    echo "Script Location: $SCRIPT_DIR"
    echo ""
    echo "Safeguard for SUDO: 7.4"
    echo "Supported Platforms: Linux, Unix, macOS"
    echo ""
    echo "==========================================="
    pause
}

################################################################################
# Function: display_changelog
# Description: Display recent changelog entries
################################################################################
display_changelog() {
    clear
    
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        print_error "Changelog file not found: $CHANGELOG_FILE"
        pause
        return
    fi
    
    echo "==========================================="
    echo "  Recent Changes"
    echo "==========================================="
    echo ""
    
    # Display the changelog using less if available, otherwise cat
    if command -v less &> /dev/null; then
        less "$CHANGELOG_FILE"
    else
        cat "$CHANGELOG_FILE"
        pause
    fi
}

################################################################################
# Function: get_user_input
# Description: Prompts user for input with validation
# Parameters: $1 - Prompt message
#             $2 - Variable name to store result
#             $3 - Optional: allow empty (yes/no, default: no)
#             $4 - Optional: allow cancel (yes/no, default: no)
# Returns: 0 if input provided, 1 if cancelled
################################################################################
get_user_input() {
    local prompt="$1"
    local var_name="$2"
    local allow_empty="${3:-no}"
    local allow_cancel="${4:-no}"
    local user_input
    
    while true; do
        if [[ "$allow_cancel" == "yes" ]]; then
            echo -n "$prompt (or '0' to cancel): "
        else
            echo -n "$prompt: "
        fi
        read -r user_input
        
        # Check for cancellation
        if [[ "$allow_cancel" == "yes" ]] && [[ "$user_input" == "0" ]]; then
            return 1
        fi
        
        if [[ -n "$user_input" ]] || [[ "$allow_empty" == "yes" ]]; then
            eval "$var_name='$user_input'"
            return 0
        else
            print_error "Input cannot be empty. Please try again."
        fi
    done
}

################################################################################
# Function: confirm_action
# Description: Asks user for confirmation before proceeding
# Parameters: $1 - Action description
# Returns: 0 if confirmed, 1 if cancelled
################################################################################
confirm_action() {
    local action="$1"
    local response
    
    echo ""
    echo -n "Are you sure you want to $action? (yes/no): "
    read -r response
    
    case "$response" in
        [Yy][Ee][Ss]|[Yy])
            return 0
            ;;
        *)
            print_warning "Action cancelled by user"
            return 1
            ;;
    esac
}

################################################################################
# MENU FUNCTIONS
################################################################################

################################################################################
# Function: menu_git_management
# Description: Git policy management sub-menu
################################################################################
menu_git_management() {
    while true; do
        clear
        print_header "Git Policy Management"
        echo "1)  pmgit status        - Show Git integration status"
        echo "2)  pmgit enable        - Enable Git policy management"
        echo "3)  pmgit disable       - Disable Git policy management"
        echo "4)  pmgit update        - Update policy from Git repository"
        echo "5)  pmgit set           - Configure Git settings"
        echo "6)  pmgit export        - Export policy to Git"
        echo "7)  pmgit import        - Import policy from Git"
        echo "8)  pmgit help          - Display Git integration help"
        echo ""
        echo "0)  Return to Main Menu"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) clear; run_command "${QUEST_BIN}/pmgit status"; pause ;;
            2) clear; 
               if confirm_action "enable Git policy management"; then
                   run_command "${QUEST_BIN}/pmgit enable"
               fi
               pause ;;
            3) clear;
               if confirm_action "disable Git policy management"; then
                   run_command "${QUEST_BIN}/pmgit disable"
               fi
               pause ;;
            4) clear; run_command "${QUEST_BIN}/pmgit update"; pause ;;
            5) clear; run_command "${QUEST_BIN}/pmgit set"; pause ;;
            6) clear; run_command "${QUEST_BIN}/pmgit export"; pause ;;
            7) clear; run_command "${QUEST_BIN}/pmgit import"; pause ;;
            8) clear; run_command "${QUEST_BIN}/pmgit help"; pause ;;
            0) break ;;
            *) print_error "Invalid selection"; sleep 1 ;;
        esac
    done
}

################################################################################
# Function: menu_policy_management
# Description: Policy management sub-menu
################################################################################
menu_policy_management() {
    while true; do
        clear
        print_header "Policy Management"
        echo "1)  Checkout Policy           - Checkout policy to temp directory"
        echo "2)  Edit Default Policy       - Edit main sudoers policy"
        echo "3)  Edit Custom Policies      - Select and edit custom policies"
        echo "4)  Create New Custom Policy  - Create a new custom policy"
        echo "5)  List All Policies         - Show all available policies"
        echo "6)  Add Policy to Server      - Add custom policy to repository"
        echo "7)  Validate Policy Syntax    - Run pmcheck on policy"
        echo "8)  Commit Policy Changes     - Commit changes to repository"
        echo "9)  View Policy Log           - Display policy revision history"
        echo "10) Compare Policy Versions   - Show differences between revisions"
        echo "11) Check Policy Status       - Check if production matches master"
        echo "12) Sync Policy               - Update production from master"
        echo "13) Clean Temp Directory      - Remove /tmp/policydir"
        echo ""
        echo "0)  Return to Main Menu"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) checkout_policy ;;
            2) edit_policy "sudoers" ;;
            3) edit_custom_policies ;;
            4) create_new_custom_policy ;;
            5) list_all_policies ;;
            6) add_policy_to_server ;;
            7) validate_policy ;;
            8) commit_policy ;;
            9) clear; run_command "${QUEST_BIN}/pmpolicy log"; pause ;;
            10) compare_policy_versions ;;
            11) clear; run_command "${QUEST_BIN}/pmpolicy masterstatus"; pause ;;
            12) sync_policy ;;
            13) clean_temp_directory ;;
            0) break ;;
            *) print_error "Invalid selection"; sleep 1 ;;
        esac
    done
}

################################################################################
# Function: checkout_policy
# Description: Checkout policy to temporary directory
################################################################################
checkout_policy() {
    clear
    
    if [[ -d "$TEMP_POLICY_DIR" ]]; then
        print_warning "Temporary policy directory already exists: $TEMP_POLICY_DIR"
        if ! confirm_action "overwrite existing directory"; then
            return
        fi
        rm -rf "$TEMP_POLICY_DIR"
    fi
    
    echo "Checking out policy to $TEMP_POLICY_DIR..."
    run_command "${QUEST_BIN}/pmpolicy checkout -d $TEMP_POLICY_DIR"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy checked out successfully"
        echo "You can now edit policies using menu options 1-4"
    else
        print_error "Failed to checkout policy"
    fi
    
    pause
}

################################################################################
# Function: edit_policy
# Description: Edit a specific policy file
# Parameters: $1 - Policy path relative to policy_sudo directory
################################################################################
edit_policy() {
    local policy_path="$1"
    local full_path="${TEMP_POLICY_DIR}/policy_sudo/${policy_path}"
    
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Please use option 5 to checkout policy first."
        pause
        return
    fi
    
    if [[ ! -f "$full_path" ]]; then
        print_warning "Policy file does not exist: $full_path"
        if confirm_action "create new policy file"; then
            mkdir -p "$(dirname "$full_path")"
            touch "$full_path"
        else
            pause
            return
        fi
    fi
    
    echo "Editing: $full_path"
    echo ""
    
    # Use vim if available, otherwise use vi
    if command -v vim &> /dev/null; then
        vim "$full_path"
    else
        vi "$full_path"
    fi
    
    print_success "Policy editing completed"
    echo "Remember to validate (option 6) and commit (option 7) your changes."
    pause
}

################################################################################
# Function: validate_policy
# Description: Validate policy syntax using pmcheck
################################################################################
validate_policy() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Please use option 5 to checkout policy first."
        pause
        return
    fi
    
    local sudoers_file="${TEMP_POLICY_DIR}/policy_sudo/sudoers"
    
    if [[ ! -f "$sudoers_file" ]]; then
        print_error "Sudoers file not found: $sudoers_file"
        pause
        return
    fi
    
    echo "Validating policy syntax..."
    echo ""
    run_command "${QUEST_BIN}/pmcheck -f $sudoers_file -o sudo"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy syntax is valid"
    else
        print_error "Policy syntax validation failed. Please review and fix errors."
    fi
    
    pause
}

################################################################################
# Function: commit_policy
# Description: Commit policy changes to repository
################################################################################
commit_policy() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Nothing to commit."
        pause
        return
    fi
    
    # Validate before committing
    echo "Validating policy before commit..."
    local sudoers_file="${TEMP_POLICY_DIR}/policy_sudo/sudoers"
    
    if [[ -f "$sudoers_file" ]]; then
        ${QUEST_BIN}/pmcheck -f "$sudoers_file" -o sudo > /dev/null 2>&1
        
        if [[ $? -ne 0 ]]; then
            print_error "Policy validation failed. Cannot commit invalid policy."
            echo "Please fix syntax errors before committing."
            pause
            return
        fi
    fi
    
    echo ""
    if ! confirm_action "commit policy changes to repository"; then
        return
    fi
    
    echo ""
    echo "Committing policy changes..."
    run_command "${QUEST_BIN}/pmpolicy commit -d $TEMP_POLICY_DIR"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy committed successfully"
    else
        print_error "Failed to commit policy"
    fi
    
    pause
}

################################################################################
# Function: compare_policy_versions
# Description: Compare two policy revisions
################################################################################
compare_policy_versions() {
    clear
    
    echo "First, let's view the policy revision history:"
    echo ""
    ${QUEST_BIN}/pmpolicy log
    echo ""
    
    local rev1 rev2
    if ! get_user_input "Enter first revision number" rev1 "no" "yes"; then
        print_warning "Comparison cancelled"
        pause
        return
    fi
    
    if ! get_user_input "Enter second revision number" rev2 "no" "yes"; then
        print_warning "Comparison cancelled"
        pause
        return
    fi
    
    echo ""
    echo "Comparing revision $rev1 to revision $rev2..."
    echo ""
    run_command "${QUEST_BIN}/pmpolicy diff -r:${rev1}:${rev2}"
    
    pause
}

################################################################################
# Function: sync_policy
# Description: Sync production policy with master
################################################################################
sync_policy() {
    clear
    
    if ! confirm_action "sync production policy from master repository"; then
        return
    fi
    
    echo ""
    echo "Synchronizing policy..."
    run_command "${QUEST_BIN}/pmpolicy sync"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy synchronized successfully"
    else
        print_error "Failed to synchronize policy"
    fi
    
    pause
}

################################################################################
# Function: clean_temp_directory
# Description: Remove temporary policy directory
################################################################################
clean_temp_directory() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_warning "Temporary directory does not exist: $TEMP_POLICY_DIR"
        pause
        return
    fi
    
    if ! confirm_action "delete temporary policy directory $TEMP_POLICY_DIR"; then
        return
    fi
    
    rm -rf "$TEMP_POLICY_DIR"
    
    if [[ $? -eq 0 ]]; then
        print_success "Temporary directory deleted: $TEMP_POLICY_DIR"
    else
        print_error "Failed to delete temporary directory"
    fi
    
    pause
}

################################################################################
# Function: list_all_policies
# Description: Discover and list all policies in checked-out directory
################################################################################
list_all_policies() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Please use option 1 to checkout policy first."
        pause
        return
    fi
    
    local policy_base="${TEMP_POLICY_DIR}/policy_sudo"
    
    if [[ ! -d "$policy_base" ]]; then
        print_error "Policy directory not found: $policy_base"
        pause
        return
    fi
    
    print_header "Available Policies"
    echo ""
    echo "Default Policy:"
    echo "  - sudoers (main default policy)"
    echo ""
    
    # Find all custom policy directories (exclude hidden directories like .svn)
    local custom_policies=()
    while IFS= read -r -d '' policy_dir; do
        local policy_name=$(basename "$policy_dir")
        if [[ "$policy_name" != "sudoers" && "$policy_name" != .* && -d "$policy_dir" ]]; then
            custom_policies+=("$policy_name")
        fi
    done < <(find "$policy_base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    if [[ ${#custom_policies[@]} -gt 0 ]]; then
        echo "Custom Policies:"
        for policy in "${custom_policies[@]}"; do
            echo "  - $policy"
            # Show sudoers file if it exists
            if [[ -f "$policy_base/$policy/sudoers" ]]; then
                echo "    (has sudoers file)"
            fi
        done
    else
        echo "Custom Policies:"
        echo "  (none found)"
    fi
    
    echo ""
    echo "Total policies: $((1 + ${#custom_policies[@]}))"
    
    pause
}

################################################################################
# Function: edit_custom_policies
# Description: Select and edit a custom policy from available policies
################################################################################
edit_custom_policies() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Please use option 1 to checkout policy first."
        pause
        return
    fi
    
    local policy_base="${TEMP_POLICY_DIR}/policy_sudo"
    
    # Discover custom policies (exclude hidden directories like .svn)
    local custom_policies=()
    while IFS= read -r -d '' policy_dir; do
        local policy_name=$(basename "$policy_dir")
        if [[ "$policy_name" != "sudoers" && "$policy_name" != .* && -d "$policy_dir" ]]; then
            custom_policies+=("$policy_name")
        fi
    done < <(find "$policy_base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    if [[ ${#custom_policies[@]} -eq 0 ]]; then
        print_warning "No custom policies found."
        echo "Use option 4 to create a new custom policy first."
        pause
        return
    fi
    
    # Display available policies
    print_header "Select Custom Policy to Edit"
    echo ""
    for i in "${!custom_policies[@]}"; do
        echo "$((i+1))) ${custom_policies[$i]}"
    done
    echo ""
    echo "0) Cancel"
    echo ""
    
    local selection
    echo -n "Enter your selection: "
    read -r selection
    
    if [[ "$selection" == "0" ]]; then
        return
    fi
    
    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#custom_policies[@]} ]]; then
        print_error "Invalid selection"
        pause
        return
    fi
    
    # Edit the selected policy
    local policy_name="${custom_policies[$((selection-1))]}"
    local policy_file="${policy_base}/${policy_name}/sudoers"
    
    if [[ ! -f "$policy_file" ]]; then
        print_warning "Sudoers file not found: $policy_file"
        if confirm_action "create sudoers file for policy ${policy_name}"; then
            touch "$policy_file"
        else
            pause
            return
        fi
    fi
    
    echo ""
    echo "Editing: $policy_file"
    echo ""
    
    # Use vim if available, otherwise use vi
    if command -v vim &> /dev/null; then
        vim "$policy_file"
    else
        vi "$policy_file"
    fi
    
    print_success "Policy editing completed for: $policy_name"
    echo "Remember to validate (option 7) and commit (option 8) your changes."
    pause
}

################################################################################
# Function: create_new_custom_policy
# Description: Create a new custom policy with user-specified name
################################################################################
create_new_custom_policy() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Please use option 1 to checkout policy first."
        pause
        return
    fi
    
    print_header "Create New Custom Policy"
    echo ""
    
    local policy_name
    get_user_input "Enter new policy name (e.g., webservers, dbservers)" policy_name
    
    # Validate policy name (alphanumeric, underscores, hyphens only)
    if ! [[ "$policy_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid policy name. Use only letters, numbers, underscores, and hyphens."
        pause
        return
    fi
    
    local policy_dir="${TEMP_POLICY_DIR}/policy_sudo/${policy_name}"
    
    # Check if policy already exists
    if [[ -d "$policy_dir" ]]; then
        print_error "Policy already exists: $policy_name"
        echo "Use option 3 to edit existing policies."
        pause
        return
    fi
    
    # Create policy directory
    echo ""
    echo "Creating policy directory: $policy_dir"
    mkdir -p "$policy_dir"
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create policy directory"
        pause
        return
    fi
    
    # Copy template from default sudoers
    local template_file="${TEMP_POLICY_DIR}/policy_sudo/sudoers"
    local new_policy_file="${policy_dir}/sudoers"
    
    if [[ -f "$template_file" ]]; then
        echo "Copying template from default sudoers..."
        cp "$template_file" "$new_policy_file"
    else
        echo "Creating empty sudoers file..."
        cat > "$new_policy_file" << 'EOF'
# Custom Policy: POLICY_NAME
# Created: DATE
#
# This is a custom sudo policy for Safeguard for SUDO.
# Edit this file according to sudoers syntax.
#
# Example:
# %admins ALL=(ALL) ALL
# user1 ALL=/usr/bin/systemctl restart httpd

Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Add your custom rules below:

EOF
        sed -i "s/POLICY_NAME/$policy_name/g" "$new_policy_file" 2>/dev/null || \
        sed -i '' "s/POLICY_NAME/$policy_name/g" "$new_policy_file" 2>/dev/null
        
        sed -i "s/DATE/$(date '+%Y-%m-%d %H:%M:%S')/g" "$new_policy_file" 2>/dev/null || \
        sed -i '' "s/DATE/$(date '+%Y-%m-%d %H:%M:%S')/g" "$new_policy_file" 2>/dev/null
    fi
    
    print_success "Policy created: $policy_name"
    echo ""
    
    if confirm_action "edit the new policy now"; then
        echo ""
        if command -v vim &> /dev/null; then
            vim "$new_policy_file"
        else
            vi "$new_policy_file"
        fi
    fi
    
    echo ""
    echo "Next steps:"
    echo "  1. Edit the policy if you haven't (option 3)"
    echo "  2. Validate the policy (option 7)"
    echo "  3. Add policy to server (option 6)"
    echo "  4. Commit changes (option 8)"
    
    pause
}

################################################################################
# Function: add_policy_to_server
# Description: Add a custom policy to the server repository
################################################################################
add_policy_to_server() {
    clear
    
    if [[ ! -d "$TEMP_POLICY_DIR" ]]; then
        print_error "Policy not checked out. Please use option 1 to checkout policy first."
        pause
        return
    fi
    
    local policy_base="${TEMP_POLICY_DIR}/policy_sudo"
    
    # Discover custom policies (exclude hidden directories like .svn)
    local custom_policies=()
    while IFS= read -r -d '' policy_dir; do
        local policy_name=$(basename "$policy_dir")
        if [[ "$policy_name" != "sudoers" && "$policy_name" != .* && -d "$policy_dir" ]]; then
            custom_policies+=("$policy_name")
        fi
    done < <(find "$policy_base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    if [[ ${#custom_policies[@]} -eq 0 ]]; then
        print_warning "No custom policies found."
        echo "Use option 4 to create a new custom policy first."
        pause
        return
    fi
    
    # Display available policies
    print_header "Add Policy to Server"
    echo ""
    echo "Available custom policies:"
    for i in "${!custom_policies[@]}"; do
        echo "$((i+1))) ${custom_policies[$i]}"
    done
    echo ""
    echo "0) Cancel"
    echo ""
    
    local selection
    echo -n "Enter policy number to add: "
    read -r selection
    
    if [[ "$selection" == "0" ]]; then
        return
    fi
    
    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#custom_policies[@]} ]]; then
        print_error "Invalid selection"
        pause
        return
    fi
    
    local policy_name="${custom_policies[$((selection-1))]}"
    local policy_file="${policy_name}/sudoers"
    
    # Validate policy file exists
    if [[ ! -f "${policy_base}/${policy_file}" ]]; then
        print_error "Policy file not found: ${policy_base}/${policy_file}"
        pause
        return
    fi
    
    # Get description
    echo ""
    local description
    get_user_input "Enter description for this policy" description
    
    # Validate the policy first
    echo ""
    echo "Validating policy before adding..."
    ${QUEST_BIN}/pmcheck -f "${policy_base}/${policy_file}" -o sudo > /dev/null 2>&1
    
    if [[ $? -ne 0 ]]; then
        print_error "Policy validation failed. Cannot add invalid policy."
        echo "Please edit and fix syntax errors first (option 3)."
        pause
        return
    fi
    
    print_success "Policy validation passed"
    
    # Confirm action
    echo ""
    if ! confirm_action "add policy '${policy_name}' to server repository"; then
        return
    fi
    
    # Add policy to server
    echo ""
    echo "Adding policy to server..."
    run_command "${QUEST_BIN}/pmpolicy add -d $TEMP_POLICY_DIR -p $policy_file -l \"$description\" -n"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy added to repository: $policy_name"
        echo ""
        echo "Next step: Commit changes (option 8) to make the policy active."
    else
        print_error "Failed to add policy to server"
    fi
    
    pause
}

################################################################################
# Function: menu_server_management
# Description: Server management sub-menu
################################################################################
menu_server_management() {
    while true; do
        clear
        print_header "Server Management"
        echo "1)  View Server Configuration    - Display pmsrvinfo"
        echo "2)  List Policy Assignments      - Show which policies clients use"
        echo "3)  Check Server Status          - Verify server is running"
        echo "4)  View License Information     - Display license status"
        echo "5)  Install License              - Install new license file"
        echo "6)  License Usage Report         - Detailed usage report"
        echo "7)  Check File Permissions       - Verify Safeguard file permissions"
        echo "8)  Fix File Permissions         - Repair permission issues"
        echo "9)  Edit pm.settings             - Edit main configuration file"
        echo "10) Backup Configuration         - Backup critical Safeguard directories"
        echo "11) Restore Configuration        - Restore from backup"
        echo ""
        echo "0)  Return to Main Menu"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) clear; run_command "${QUEST_BIN}/pmsrvinfo"; pause ;;
            2) clear; run_command "${QUEST_BIN}/pmsrvinfo -l"; pause ;;
            3) server_status_check ;;
            4) clear; run_command "${QUEST_BIN}/pmlicense"; pause ;;
            5) install_license ;;
            6) clear; run_command "${QUEST_BIN}/pmlicense -uf"; pause ;;
            7) clear; run_command "${QUEST_BIN}/pmcheckperms -v"; pause ;;
            8) fix_permissions ;;
            9) edit_pm_settings ;;
            10) backup_configuration ;;
            11) restore_configuration ;;
            0) break ;;
            *) print_error "Invalid selection"; sleep 1 ;;
        esac
    done
}

################################################################################
# Function: server_status_check
# Description: Check policy server status
################################################################################
server_status_check() {
    clear
    
    if ! check_command_exists "pmsrvcheck"; then
        print_error "pmsrvcheck command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    echo "Checking policy server status..."
    echo ""
    run_command "${QUEST_BIN}/pmsrvcheck"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy server is running properly"
    else
        print_error "Policy server check failed"
    fi
    
    pause
}

################################################################################
# Function: install_license
# Description: Install a new license file
################################################################################
install_license() {
    clear
    
    local license_file
    if ! get_user_input "Enter full path to license file (.dlv)" license_file "no" "yes"; then
        print_warning "License installation cancelled"
        pause
        return
    fi
    
    if [[ ! -f "$license_file" ]]; then
        print_error "License file not found: $license_file"
        pause
        return
    fi
    
    echo ""
    if ! confirm_action "install license from $license_file"; then
        return
    fi
    
    echo ""
    run_command "${QUEST_BIN}/pmlicense -l $license_file"
    
    if [[ $? -eq 0 ]]; then
        print_success "License installed successfully"
    else
        print_error "Failed to install license"
    fi
    
    pause
}

################################################################################
# Function: fix_permissions
# Description: Fix Safeguard file permissions
################################################################################
fix_permissions() {
    clear
    
    if ! confirm_action "fix file permissions for Safeguard directories"; then
        return
    fi
    
    echo ""
    echo "Fixing file permissions..."
    run_command "${QUEST_BIN}/pmcheckperms -f"
    
    if [[ $? -eq 0 ]]; then
        print_success "File permissions fixed successfully"
    else
        print_error "Failed to fix file permissions"
    fi
    
    pause
}

################################################################################
# Function: edit_pm_settings
# Description: Edit the main pm.settings configuration file
################################################################################
edit_pm_settings() {
    clear
    
    local settings_file="${QUEST_CONFIG}/pm.settings"
    
    if [[ ! -f "$settings_file" ]]; then
        print_error "Configuration file not found: $settings_file"
        pause
        return
    fi
    
    print_header "Edit pm.settings Configuration"
    echo ""
    echo "Configuration file: $settings_file"
    echo ""
    print_warning "WARNING: Incorrect settings can break Safeguard functionality!"
    echo "A backup will be created before editing."
    echo ""
    
    if ! confirm_action "edit pm.settings configuration file"; then
        return
    fi
    
    # Create backup
    local backup_file="${settings_file}.backup.$(date +%Y%m%d_%H%M%S)"
    echo ""
    echo "Creating backup: $backup_file"
    cp "$settings_file" "$backup_file"
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create backup"
        pause
        return
    fi
    
    print_success "Backup created successfully"
    
    # Edit the file
    echo ""
    echo "Opening editor..."
    sleep 1
    
    if command -v vim &> /dev/null; then
        vim "$settings_file"
    else
        vi "$settings_file"
    fi
    
    # Prompt to restart services
    echo ""
    print_warning "Changes to pm.settings require a service restart to take effect."
    
    if confirm_action "restart Safeguard services now"; then
        echo ""
        echo "Restarting services..."
        ${QUEST_BIN}/pmserviced restart
        
        if [[ $? -eq 0 ]]; then
            print_success "Services restarted successfully"
        else
            print_error "Failed to restart services"
            echo "You may need to restart manually."
        fi
    else
        echo ""
        echo "Remember to restart services with: pmserviced restart"
    fi
    
    pause
}

################################################################################
# Function: backup_configuration
# Description: Backup critical Safeguard directories
################################################################################
backup_configuration() {
    clear
    
    print_header "Backup Safeguard Configuration"
    echo ""
    
    local backup_dir
    if ! get_user_input "Enter backup directory path (default: /var/backups/safeguard)" backup_dir "yes" "yes"; then
        print_warning "Backup cancelled"
        pause
        return
    fi
    
    if [[ -z "$backup_dir" ]]; then
        backup_dir="/var/backups/safeguard"
    fi
    
    # Create timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${backup_dir}/safeguard_backup_${timestamp}"
    
    echo ""
    echo "Backup will be created at: $backup_path"
    echo ""
    echo "Directories to backup:"
    echo "  - /var/opt/quest/qpm4u (logs, repository, SSH keys)"
    echo "  - /etc/opt/quest/qpm4u (settings, production policy)"
    echo "  - /opt/quest/qpm4u/.license* (licenses)"
    echo ""
    
    if ! confirm_action "create backup"; then
        return
    fi
    
    # Create backup directory
    echo ""
    echo "Creating backup directory..."
    mkdir -p "$backup_path"
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create backup directory"
        pause
        return
    fi
    
    # Backup /var/opt/quest/qpm4u
    echo "Backing up /var/opt/quest/qpm4u..."
    tar -czf "${backup_path}/var_qpm4u.tar.gz" -C /var/opt/quest qpm4u 2>/dev/null
    
    # Backup /etc/opt/quest/qpm4u
    echo "Backing up /etc/opt/quest/qpm4u..."
    tar -czf "${backup_path}/etc_qpm4u.tar.gz" -C /etc/opt/quest qpm4u 2>/dev/null
    
    # Backup licenses
    echo "Backing up licenses..."
    mkdir -p "${backup_path}/licenses"
    cp /opt/quest/qpm4u/.license* "${backup_path}/licenses/" 2>/dev/null
    cp /opt/quest/qpm4u/license* "${backup_path}/licenses/" 2>/dev/null
    
    # Create backup manifest
    cat > "${backup_path}/BACKUP_INFO.txt" << EOF
Safeguard for SUDO Backup
=========================
Backup Date: $(date)
Hostname: $(hostname)
Script Version: $SCRIPT_VERSION

Backup Contents:
- var_qpm4u.tar.gz: /var/opt/quest/qpm4u
- etc_qpm4u.tar.gz: /etc/opt/quest/qpm4u
- licenses/: License files

Restore Instructions:
1. Stop Safeguard services: pmserviced stop
2. Extract backups:
   cd /var/opt/quest && tar -xzf $backup_path/var_qpm4u.tar.gz
   cd /etc/opt/quest && tar -xzf $backup_path/etc_qpm4u.tar.gz
3. Restore licenses: cp $backup_path/licenses/* /opt/quest/qpm4u/
4. Start services: pmserviced start
EOF
    
    # Calculate backup size
    local backup_size=$(du -sh "$backup_path" | cut -f1)
    
    print_success "Backup completed successfully"
    echo ""
    echo "Backup location: $backup_path"
    echo "Backup size: $backup_size"
    echo ""
    echo "Backup manifest: ${backup_path}/BACKUP_INFO.txt"
    
    pause
}

################################################################################
# Function: restore_configuration
# Description: Restore Safeguard configuration from backup
################################################################################
restore_configuration() {
    clear
    
    print_header "Restore Safeguard Configuration"
    echo ""
    
    print_warning "WARNING: This will overwrite current configuration!"
    echo "Make sure you have a recent backup before proceeding."
    echo ""
    
    local backup_path
    if ! get_user_input "Enter full path to backup directory" backup_path "no" "yes"; then
        print_warning "Restore cancelled"
        pause
        return
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup directory not found: $backup_path"
        pause
        return
    fi
    
    # Verify backup files exist
    if [[ ! -f "${backup_path}/var_qpm4u.tar.gz" ]] || [[ ! -f "${backup_path}/etc_qpm4u.tar.gz" ]]; then
        print_error "Backup files not found in directory"
        echo "Expected files: var_qpm4u.tar.gz, etc_qpm4u.tar.gz"
        pause
        return
    fi
    
    # Show backup info if available
    if [[ -f "${backup_path}/BACKUP_INFO.txt" ]]; then
        echo ""
        echo "Backup Information:"
        cat "${backup_path}/BACKUP_INFO.txt"
        echo ""
    fi
    
    if ! confirm_action "restore from backup (this will overwrite current configuration)"; then
        return
    fi
    
    # Stop services
    echo ""
    echo "Stopping Safeguard services..."
    ${QUEST_BIN}/pmserviced stop
    sleep 2
    
    # Restore /var/opt/quest/qpm4u
    echo "Restoring /var/opt/quest/qpm4u..."
    cd /var/opt/quest
    tar -xzf "${backup_path}/var_qpm4u.tar.gz"
    
    # Restore /etc/opt/quest/qpm4u
    echo "Restoring /etc/opt/quest/qpm4u..."
    cd /etc/opt/quest
    tar -xzf "${backup_path}/etc_qpm4u.tar.gz"
    
    # Restore licenses if they exist
    if [[ -d "${backup_path}/licenses" ]]; then
        echo "Restoring licenses..."
        cp "${backup_path}/licenses/"* /opt/quest/qpm4u/ 2>/dev/null
    fi
    
    # Fix permissions
    echo "Fixing file permissions..."
    ${QUEST_BIN}/pmcheckperms -f > /dev/null 2>&1
    
    # Start services
    echo "Starting Safeguard services..."
    ${QUEST_BIN}/pmserviced start
    sleep 2
    
    # Verify
    ${QUEST_BIN}/pmsrvcheck > /dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        print_success "Configuration restored successfully"
        echo "Services are running."
    else
        print_warning "Configuration restored, but services may need attention"
        echo "Check logs: /var/log/pmmasterd.log"
    fi
    
    pause
}

################################################################################
# Function: menu_plugin_management
# Description: Plugin host management sub-menu
################################################################################
menu_plugin_management() {
    while true; do
        clear
        print_header "Plugin Host Management"
        echo "1)  View Plugin Configuration    - Display pmplugininfo"
        echo "2)  Check Server Availability    - Check policy server status"
        echo "3)  Join Plugin to Server        - Join this host to policy server"
        echo "4)  Unjoin Plugin from Server    - Remove from policy group"
        echo "5)  Check Plugin Policy Status   - View cached policy status"
        echo "6)  Run Pre-flight Check         - Verify installation readiness"
        echo ""
        echo "0)  Return to Main Menu"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) clear; run_command "${QUEST_BIN}/pmplugininfo"; pause ;;
            2) clear; run_command "${QUEST_BIN}/pmpluginloadcheck -r"; pause ;;
            3) join_plugin_to_server ;;
            4) unjoin_plugin_from_server ;;
            5) clear; run_command "${QUEST_BIN}/pmpolicyplugin"; pause ;;
            6) run_preflight_check ;;
            0) break ;;
            *) print_error "Invalid selection"; sleep 1 ;;
        esac
    done
}

################################################################################
# Function: join_plugin_to_server
# Description: Join plugin host to policy server
################################################################################
join_plugin_to_server() {
    clear
    
    local policy_server
    if ! get_user_input "Enter policy server hostname or IP" policy_server "no" "yes"; then
        print_warning "Join operation cancelled"
        pause
        return
    fi
    
    echo ""
    if ! confirm_action "join this host to policy server $policy_server"; then
        return
    fi
    
    echo ""
    echo "Joining plugin to policy server..."
    run_command "${QUEST_BIN}/pmjoin_plugin -a $policy_server"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully joined to policy server"
    else
        print_error "Failed to join policy server"
    fi
    
    pause
}

################################################################################
# Function: unjoin_plugin_from_server
# Description: Unjoin plugin host from policy server
################################################################################
unjoin_plugin_from_server() {
    clear
    
    if ! confirm_action "unjoin this host from the policy server"; then
        return
    fi
    
    echo ""
    echo "Unjoining plugin from policy server..."
    run_command "${QUEST_BIN}/pmjoin_plugin -u"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully unjoined from policy server"
    else
        print_error "Failed to unjoin from policy server"
    fi
    
    pause
}

################################################################################
# Function: run_preflight_check
# Description: Run pre-installation readiness check
################################################################################
run_preflight_check() {
    clear
    
    local policy_server
    if ! get_user_input "Enter policy server hostname or IP" policy_server "yes" "yes"; then
        print_warning "Preflight check cancelled"
        pause
        return
    fi
    
    echo ""
    echo "Running pre-flight check..."
    
    if [[ -n "$policy_server" ]]; then
        run_command "sh /opt/quest/sbin/pmpreflight.sh --sudo --policyserver $policy_server"
    else
        run_command "sh /opt/quest/sbin/pmpreflight.sh --sudo"
    fi
    
    pause
}

################################################################################
# Function: menu_log_management
# Description: Log management and search sub-menu
################################################################################
menu_log_management() {
    while true; do
        clear
        print_header "Log Management & Search"
        echo "1)  View Event Logs              - Display recent event logs"
        echo "2)  Search Logs by User          - Search for specific user"
        echo "3)  Search Logs by Date Range    - Search with date filter"
        echo "4)  Search Logs (Custom)         - Custom pmlogsearch query"
        echo "5)  List I/O Logs                - Show available keystroke logs"
        echo "6)  Replay Keystroke Log         - Replay an I/O log session"
        echo "7)  View Log Statistics          - Display log summary"
        echo ""
        echo "0)  Return to Main Menu"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) view_event_logs ;;
            2) search_logs_by_user ;;
            3) search_logs_by_date ;;
            4) search_logs_custom ;;
            5) list_io_logs ;;
            6) replay_keystroke_log ;;
            7) view_log_statistics ;;
            0) break ;;
            *) print_error "Invalid selection"; sleep 1 ;;
        esac
    done
}

################################################################################
# Function: view_event_logs
# Description: View recent event logs
################################################################################
view_event_logs() {
    clear
    
    if ! check_command_exists "pmlog"; then
        print_error "pmlog command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    local num_entries
    if ! get_user_input "Enter number of log entries to display (default: 50)" num_entries "yes" "yes"; then
        print_warning "Operation cancelled"
        pause
        return
    fi
    
    if [[ -z "$num_entries" ]]; then
        num_entries=50
    fi
    
    echo ""
    echo "Displaying last $num_entries event log entries..."
    echo ""
    run_command "${QUEST_BIN}/pmlog -n $num_entries"
    
    pause
}

################################################################################
# Function: search_logs_by_user
# Description: Search event logs by username
################################################################################
search_logs_by_user() {
    clear
    
    if ! check_command_exists "pmlogsearch"; then
        print_error "pmlogsearch command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    local username
    if ! get_user_input "Enter username to search for" username "no" "yes"; then
        print_warning "Search cancelled"
        pause
        return
    fi
    
    # Get optional date filter
    local after_date
    echo ""
    echo "Optional: Filter by date"
    if ! get_user_input "Enter start date (YYYY/MM/DD) or press ENTER to skip" after_date "yes" "yes"; then
        print_warning "Search cancelled"
        pause
        return
    fi
    
    echo ""
    echo "Searching logs for user: $username"
    
    if [[ -n "$after_date" ]]; then
        run_command "${QUEST_BIN}/pmlogsearch --user $username --after \"$after_date 00:00:00\""
    else
        run_command "${QUEST_BIN}/pmlogsearch --user $username"
    fi
    
    pause
}

################################################################################
# Function: search_logs_by_date
# Description: Search event logs by date range
################################################################################
search_logs_by_date() {
    clear
    
    if ! check_command_exists "pmlogsearch"; then
        print_error "pmlogsearch command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    local after_date before_date
    
    if ! get_user_input "Enter start date (YYYY/MM/DD)" after_date "no" "yes"; then
        print_warning "Search cancelled"
        pause
        return
    fi
    
    if ! get_user_input "Enter end date (YYYY/MM/DD) or press ENTER for today" before_date "yes" "yes"; then
        print_warning "Search cancelled"
        pause
        return
    fi
    
    echo ""
    echo "Searching logs..."
    
    if [[ -n "$before_date" ]]; then
        run_command "${QUEST_BIN}/pmlogsearch --after \"$after_date 00:00:00\" --before \"$before_date 23:59:59\""
    else
        run_command "${QUEST_BIN}/pmlogsearch --after \"$after_date 00:00:00\""
    fi
    
    pause
}

################################################################################
# Function: search_logs_custom
# Description: Custom log search with user-provided parameters
################################################################################
search_logs_custom() {
    clear
    
    if ! check_command_exists "pmlogsearch"; then
        print_error "pmlogsearch command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    echo "Enter custom pmlogsearch parameters"
    echo "Examples:"
    echo "  --user username --command sudo"
    echo "  --host hostname --after \"2024/01/01 00:00:00\""
    echo "  --event accept --user root"
    echo ""
    
    local search_params
    if ! get_user_input "Enter pmlogsearch parameters" search_params "no" "yes"; then
        print_warning "Search cancelled"
        pause
        return
    fi
    
    echo ""
    echo "Searching logs with: $search_params"
    run_command "${QUEST_BIN}/pmlogsearch $search_params"
    
    pause
}

################################################################################
# Function: list_io_logs
# Description: List available I/O (keystroke) logs
################################################################################
list_io_logs() {
    clear
    
    if ! check_command_exists "pmlog"; then
        print_error "pmlog command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    echo "Listing available I/O (keystroke) logs..."
    echo ""
    run_command "${QUEST_BIN}/pmlog -i"
    
    pause
}

################################################################################
# Function: replay_keystroke_log
# Description: Replay a keystroke log session
################################################################################
replay_keystroke_log() {
    clear
    
    if ! check_command_exists "pmreplay"; then
        print_error "pmreplay command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    echo "Available I/O logs in ${LOG_DIR}/iolog:"
    echo ""
    
    # List available logs
    if [[ -d "${LOG_DIR}/iolog" ]]; then
        find "${LOG_DIR}/iolog" -type f -name "log" 2>/dev/null | head -20
        echo ""
    else
        print_warning "I/O log directory not found: ${LOG_DIR}/iolog"
        pause
        return
    fi
    
    local log_path
    if ! get_user_input "Enter full path to I/O log file" log_path "no" "yes"; then
        print_warning "Replay cancelled"
        pause
        return
    fi
    
    if [[ ! -f "$log_path" ]]; then
        print_error "Log file not found: $log_path"
        pause
        return
    fi
    
    echo ""
    echo "Replaying keystroke log: $log_path"
    echo "Use arrow keys to navigate, 'q' to quit"
    echo ""
    sleep 2
    
    run_command "${QUEST_BIN}/pmreplay $log_path"
    
    pause
}

################################################################################
# Function: view_log_statistics
# Description: Display log statistics and summary
################################################################################
view_log_statistics() {
    clear
    
    if ! check_command_exists "pmlog"; then
        print_error "pmlog command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    echo "Log Statistics and Summary"
    echo "==========================================="
    echo ""
    
    # Event log location
    if [[ -f "${LOG_DIR}/pmevents.db" ]]; then
        local db_size=$(du -h "${LOG_DIR}/pmevents.db" 2>/dev/null | cut -f1)
        echo "Event Log Database: ${LOG_DIR}/pmevents.db"
        echo "Database Size: $db_size"
    fi
    
    echo ""
    
    # I/O log location
    if [[ -d "${LOG_DIR}/iolog" ]]; then
        local iolog_count=$(find "${LOG_DIR}/iolog" -type f -name "log" 2>/dev/null | wc -l)
        local iolog_size=$(du -sh "${LOG_DIR}/iolog" 2>/dev/null | cut -f1)
        echo "I/O Log Directory: ${LOG_DIR}/iolog"
        echo "Number of I/O Logs: $iolog_count"
        echo "Total I/O Log Size: $iolog_size"
    fi
    
    echo ""
    
    # Recent event count
    echo "Recent Event Log Entries (last 10):"
    echo "==========================================="
    ${QUEST_BIN}/pmlog -n 10 2>/dev/null
    
    pause
}

################################################################################
# Function: menu_diagnostics
# Description: Diagnostics and troubleshooting sub-menu
################################################################################
menu_diagnostics() {
    while true; do
        clear
        print_header "Diagnostics & Troubleshooting"
        echo "1)  Verify Hostname Resolution   - Check hostname/IP resolution"
        echo "2)  Display System ID            - Show Safeguard system ID"
        echo "3)  Test Policy Syntax           - Validate policy file"
        echo "4)  Test Command Authorization   - Simulate sudo command"
        echo "5)  Enable Debug Logging         - Enable debug mode"
        echo "6)  Disable Debug Logging        - Disable debug mode"
        echo "7)  View Error Logs              - Display daemon error logs"
        echo "8)  Check Audit Server           - Verify audit server connectivity"
        echo ""
        echo "0)  Return to Main Menu"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) verify_hostname_resolution ;;
            2) clear; run_command "${QUEST_BIN}/pmsysid"; pause ;;
            3) test_policy_syntax ;;
            4) test_command_authorization ;;
            5) enable_debug_logging ;;
            6) disable_debug_logging ;;
            7) view_error_logs ;;
            8) check_audit_server ;;
            0) break ;;
            *) print_error "Invalid selection"; sleep 1 ;;
        esac
    done
}

################################################################################
# Function: verify_hostname_resolution
# Description: Verify hostname and IP resolution
################################################################################
verify_hostname_resolution() {
    clear
    
    if ! check_command_exists "pmresolvehost"; then
        print_error "pmresolvehost command not found."
        pause
        return
    fi
    
    local hostname
    if ! get_user_input "Enter hostname or IP to verify (or ENTER for local host)" hostname "yes" "yes"; then
        print_warning "Operation cancelled"
        pause
        return
    fi
    
    echo ""
    if [[ -n "$hostname" ]]; then
        echo "Verifying hostname: $hostname"
        run_command "${QUEST_BIN}/pmresolvehost $hostname"
    else
        echo "Verifying local host resolution..."
        run_command "${QUEST_BIN}/pmresolvehost"
    fi
    
    pause
}

################################################################################
# Function: test_policy_syntax
# Description: Test policy file syntax
################################################################################
test_policy_syntax() {
    clear
    
    if ! check_command_exists "pmcheck"; then
        print_error "pmcheck command not found."
        pause
        return
    fi
    
    local policy_file
    echo "Default policy file: ${POLICY_DIR}/sudoers"
    if ! get_user_input "Enter policy file path or ENTER for default" policy_file "yes" "yes"; then
        print_warning "Operation cancelled"
        pause
        return
    fi
    
    if [[ -z "$policy_file" ]]; then
        policy_file="${POLICY_DIR}/sudoers"
    fi
    
    if [[ ! -f "$policy_file" ]]; then
        print_error "Policy file not found: $policy_file"
        pause
        return
    fi
    
    echo ""
    echo "Testing policy syntax: $policy_file"
    run_command "${QUEST_BIN}/pmcheck -f $policy_file -o sudo"
    
    if [[ $? -eq 0 ]]; then
        print_success "Policy syntax is valid"
    else
        print_error "Policy syntax errors detected"
    fi
    
    pause
}

################################################################################
# Function: test_command_authorization
# Description: Test command authorization without executing
################################################################################
test_command_authorization() {
    clear
    
    if ! check_command_exists "pmcheck"; then
        print_error "pmcheck command not found."
        pause
        return
    fi
    
    echo "Test Command Authorization"
    echo "==========================================="
    echo ""
    
    local username groupname hostname command
    
    if ! get_user_input "Enter username" username "no" "yes"; then
        print_warning "Test cancelled"
        pause
        return
    fi
    
    if ! get_user_input "Enter group name" groupname "no" "yes"; then
        print_warning "Test cancelled"
        pause
        return
    fi
    
    if ! get_user_input "Enter hostname" hostname "no" "yes"; then
        print_warning "Test cancelled"
        pause
        return
    fi
    
    if ! get_user_input "Enter command to test" command "no" "yes"; then
        print_warning "Test cancelled"
        pause
        return
    fi
    
    echo ""
    echo "Testing authorization for:"
    echo "  User: $username"
    echo "  Group: $groupname"
    echo "  Host: $hostname"
    echo "  Command: $command"
    echo ""
    
    run_command "${QUEST_BIN}/pmcheck -u $username -g $groupname -h $hostname $command"
    
    local exit_code=$?
    echo ""
    
    case $exit_code in
        0)
            print_success "Command would be ACCEPTED"
            ;;
        11)
            print_warning "Command requires authentication (password prompt)"
            ;;
        12)
            print_error "Command would be REJECTED"
            ;;
        13)
            print_error "Syntax error encountered"
            ;;
        *)
            print_error "Unknown exit code: $exit_code"
            ;;
    esac
    
    pause
}

################################################################################
# Function: enable_debug_logging
# Description: Enable debug logging
################################################################################
enable_debug_logging() {
    clear
    
    if ! check_command_exists "pmcheck"; then
        print_error "pmcheck command not found."
        pause
        return
    fi
    
    if ! confirm_action "enable debug logging"; then
        return
    fi
    
    echo ""
    echo "Enabling debug logging..."
    run_command "${QUEST_BIN}/pmcheck -z on"
    
    if [[ $? -eq 0 ]]; then
        print_success "Debug logging enabled"
        echo "Note: Debug logs will be written to system logs"
        echo "Remember to disable debug logging when troubleshooting is complete"
    else
        print_error "Failed to enable debug logging"
    fi
    
    pause
}

################################################################################
# Function: disable_debug_logging
# Description: Disable debug logging
################################################################################
disable_debug_logging() {
    clear
    
    if ! check_command_exists "pmcheck"; then
        print_error "pmcheck command not found."
        pause
        return
    fi
    
    if ! confirm_action "disable debug logging"; then
        return
    fi
    
    echo ""
    echo "Disabling debug logging..."
    run_command "${QUEST_BIN}/pmcheck -z off"
    
    if [[ $? -eq 0 ]]; then
        print_success "Debug logging disabled"
    else
        print_error "Failed to disable debug logging"
    fi
    
    pause
}

################################################################################
# Function: view_error_logs
# Description: View Safeguard daemon error logs
################################################################################
view_error_logs() {
    clear
    
    echo "Safeguard Daemon Error Logs"
    echo "==========================================="
    echo ""
    echo "1) pmmasterd.log  - Policy server daemon"
    echo "2) pmserviced.log - Service daemon"
    echo "3) pmlocald.log   - Local daemon"
    echo "4) pmrun.log      - Client log"
    echo "5) All logs       - View all available logs"
    echo ""
    echo "0) Return"
    echo ""
    echo -n "Select log to view: "
    read -r log_selection
    
    local log_file=""
    
    case "$log_selection" in
        1) log_file="/var/log/pmmasterd.log" ;;
        2) log_file="/var/log/pmserviced.log" ;;
        3) log_file="/var/log/pmlocald.log" ;;
        4) log_file="/var/log/pmrun.log" ;;
        5) 
            echo ""
            for log in pmmasterd.log pmserviced.log pmlocald.log pmrun.log; do
                if [[ -f "/var/log/$log" ]]; then
                    echo "=== $log (last 20 lines) ==="
                    tail -20 "/var/log/$log"
                    echo ""
                fi
            done
            pause
            return
            ;;
        0) return ;;
        *) print_error "Invalid selection"; sleep 1; return ;;
    esac
    
    if [[ -f "$log_file" ]]; then
        echo ""
        echo "=== $log_file (last 50 lines) ==="
        tail -50 "$log_file"
    else
        print_error "Log file not found: $log_file"
    fi
    
    pause
}

################################################################################
# Function: check_audit_server
# Description: Check audit server connectivity
################################################################################
check_audit_server() {
    clear
    
    if ! check_command_exists "pmauditsrv"; then
        print_error "pmauditsrv command not found. This may be a plugin-only installation."
        pause
        return
    fi
    
    echo "Checking audit server connectivity..."
    echo ""
    run_command "${QUEST_BIN}/pmauditsrv check"
    
    if [[ $? -eq 0 ]]; then
        print_success "Audit server is accessible"
    else
        print_error "Audit server check failed"
    fi
    
    pause
}

################################################################################
# Function: display_about
# Description: Display about information and credits
################################################################################
display_about() {
    clear
    echo "==========================================="
    echo "  About This Script"
    echo "==========================================="
    echo ""
    echo "Script Name: $SCRIPT_NAME"
    echo "Version: $SCRIPT_VERSION"
    echo "Release Date: $SCRIPT_DATE"
    echo ""
    echo "Product: One Identity Safeguard for SUDO 7.4"
    echo "Documentation: https://support.oneidentity.com"
    echo ""
    echo "Features:"
    echo "  - Git-based policy management"
    echo "  - Centralized sudo policy control"
    echo "  - Server and plugin administration"
    echo "  - Comprehensive logging and auditing"
    echo "  - Policy validation and testing"
    echo "  - Diagnostic and troubleshooting tools"
    echo ""
    echo "Requirements:"
    echo "  - Root privileges"
    echo "  - Safeguard for SUDO 7.4 installed"
    echo "  - Policy server or plugin configuration"
    echo ""
    echo "Support:"
    echo "  - Script Log: $SCRIPT_LOG"
    echo "  - Changelog: $CHANGELOG_FILE"
    echo ""
    echo "==========================================="
    pause
}

################################################################################
# Function: main_menu
# Description: Main menu display and handling
################################################################################
main_menu() {
    while true; do
        clear
        echo "==========================================="
        echo "  Safeguard for SUDO 7.4"
        echo "  Administration Menu v${SCRIPT_VERSION}"
        echo "==========================================="
        echo ""
        echo "ADMINISTRATIVE FUNCTIONS:"
        echo "  1)  Git Policy Management"
        echo "  2)  Policy Management"
        echo "  3)  Server Management"
        echo "  4)  Plugin Host Management"
        echo "  5)  Log Management & Search"
        echo "  6)  Diagnostics & Troubleshooting"
        echo ""
        echo "INFORMATION:"
        echo "  v)  Version Information"
        echo "  c)  View Changelog"
        echo "  a)  About This Script"
        echo ""
        echo "  q)  Exit"
        echo ""
        echo -n "Enter your selection: "
        read -r selection
        
        case "$selection" in
            1) menu_git_management ;;
            2) menu_policy_management ;;
            3) menu_server_management ;;
            4) menu_plugin_management ;;
            5) menu_log_management ;;
            6) menu_diagnostics ;;
            v|V) display_version ;;
            c|C) display_changelog ;;
            a|A) display_about ;;
            q|Q) 
                echo ""
                echo "Exiting Safeguard Administration Menu..."
                log_message "Script exited by user"
                exit 0
                ;;
            *) 
                print_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# MAIN SCRIPT EXECUTION
################################################################################

# Perform prerequisite checks
check_root
check_safeguard_installed

# Log script start
log_message "=== Safeguard Administration Menu Started ==="
log_message "User: $(whoami)"
log_message "Hostname: $(hostname)"

# Display main menu
main_menu

# Script should never reach here due to exit in menu
exit 0
