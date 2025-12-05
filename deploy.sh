#!/bin/bash
################################################################################
# Deploy Script - Copy files to remote host
################################################################################
# Description: Copies the Safeguard for SUDO menu script and related files
#              to a remote host for testing or deployment
# Usage: ./deploy.sh [user@]hostname [destination_path]
# Examples: 
#   ./deploy.sh admin@sudo.servername.com /home/admin/safeguard-menu
#   ./deploy.sh root@server.example.com /opt/admin/
#   ./deploy.sh sudo.servername.com /root/safeguard-menu
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==========================================="
echo "  Safeguard for SUDO Menu - Deployment"
echo "==========================================="
echo ""

# Get parameters
REMOTE_TARGET="${1}"
REMOTE_DEST="${2}"

# Prompt for default user if not already set
if [[ -z "$REMOTE_TARGET" ]]; then
    echo -e "${BLUE}Configure Default Settings:${NC}"
    echo -n "Enter default remote username: "
    read -r DEFAULT_USER
    
    echo -n "Enter default remote hostname: "
    read -r DEFAULT_HOST
    
    echo -n "Enter default destination path [/home/${DEFAULT_USER}/safeguard-menu]: "
    read -r dest_input
    DEFAULT_DEST="${dest_input:-/home/${DEFAULT_USER}/safeguard-menu}"
    
    REMOTE_USER="$DEFAULT_USER"
    REMOTE_HOST="$DEFAULT_HOST"
    REMOTE_DEST="$DEFAULT_DEST"
elif [[ "$REMOTE_TARGET" == *"@"* ]]; then
    # user@host format
    REMOTE_USER="${REMOTE_TARGET%%@*}"
    REMOTE_HOST="${REMOTE_TARGET##*@}"
    
    if [[ -z "$REMOTE_DEST" ]]; then
        echo -n "Enter destination path [/home/${REMOTE_USER}/safeguard-menu]: "
        read -r dest_input
        REMOTE_DEST="${dest_input:-/home/${REMOTE_USER}/safeguard-menu}"
    fi
else
    # Just hostname provided
    REMOTE_HOST="$REMOTE_TARGET"
    echo -n "Enter remote username: "
    read -r REMOTE_USER
    
    if [[ -z "$REMOTE_DEST" ]]; then
        echo -n "Enter destination path [/home/${REMOTE_USER}/safeguard-menu]: "
        read -r dest_input
        REMOTE_DEST="${dest_input:-/home/${REMOTE_USER}/safeguard-menu}"
    fi
fi

echo ""
echo -e "${BLUE}Deployment Configuration:${NC}"
echo "  Source:      $SCRIPT_DIR"
echo "  Target User: $REMOTE_USER"
echo "  Target Host: $REMOTE_HOST"
echo "  Target Path: $REMOTE_DEST"
echo ""

# Confirm deployment
echo -n "Proceed with deployment? (yes/no): "
read -r response

if [[ ! $response =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "Deploying files..."
echo ""

# Create destination directory on remote host
echo "Creating destination directory..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p $REMOTE_DEST" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Could not create directory on remote host${NC}"
    echo "Please ensure you have SSH access to ${REMOTE_USER}@${REMOTE_HOST}"
    echo ""
    echo "Try manually:"
    echo "  ssh ${REMOTE_USER}@${REMOTE_HOST}"
    exit 1
fi

# Copy files
echo "Copying files..."
scp -r "$SCRIPT_DIR"/* "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST}/"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: File copy failed${NC}"
    echo ""
    echo "Try manually:"
    echo "  scp -r \"$SCRIPT_DIR\"/* ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST}/"
    exit 1
fi

# Make scripts executable on remote host
echo "Setting permissions..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod +x $REMOTE_DEST/*.sh" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}Warning: Could not set execute permissions${NC}"
    echo "You may need to run: chmod +x $REMOTE_DEST/*.sh"
fi

echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Connecting to remote host..."
echo -e "${YELLOW}You are now in an SSH session on ${REMOTE_HOST}${NC}"
echo ""
echo "Quick start commands:"
echo "  cd $REMOTE_DEST          # Navigate to script directory"
echo "  ./quick-test.sh          # Run quick test"
echo "  sudo ./sudo-menu.sh      # Run the menu script"
echo ""
echo "Type 'exit' when done to return to your local machine."
echo ""
echo "==========================================="
echo ""

# Connect to SSH and stay in the session
ssh -t "${REMOTE_USER}@${REMOTE_HOST}" "cd $REMOTE_DEST && exec \$SHELL -l"

