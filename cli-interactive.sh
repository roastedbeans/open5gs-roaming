#!/bin/bash

# Open5GS Scripts CLI - Interactive Terminal UI
# Provides a menu-driven interface for Open5GS management

set -e

# ===============================
# Configuration & Constants
# ===============================

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Terminal control
readonly CLEAR='\033[2J'
readonly HOME='\033[H'
readonly HIDE_CURSOR='\033[?25l'
readonly SHOW_CURSOR='\033[?25h'
readonly SAVE_CURSOR='\033[s'
readonly RESTORE_CURSOR='\033[u'

# Menu configuration
readonly VERSION="2.0.0"
readonly CLI_SCRIPT="./cli.sh"

# Menu items - organized by category
declare -a MENU_CATEGORIES=(
    "📦 Installation & Setup"
    "🚀 Deployment"
    "📦 Image Management"
    "🔐 Certificates"
    "🌐 DNS Configuration"
    "🗄️ Database"
    "🔧 Management & Monitoring"
    "🌐 WebUI"
    "🧹 Cleanup"
    "ℹ️ Information"
)

declare -A MENU_ITEMS=(
    # Installation & Setup
    ["📦 Installation & Setup"]="install-dep:Install dependencies (Docker, Git, GTP5G)|setup-roaming:Complete automated k8s-roaming setup"
    
    # Deployment
    ["🚀 Deployment"]="deploy-hplmn:Deploy HPLMN components|deploy-vplmn:Deploy VPLMN components|deploy-roaming:Deploy both HPLMN and VPLMN|docker-deploy:Publish images to Docker Hub"
    
    # Image Management
    ["📦 Image Management"]="pull-images:Pull Open5GS images|import-images:Import to MicroK8s registry|update-configs:Update deployment configs"
    
    # Certificates
    ["🔐 Certificates"]="generate-certs:Generate TLS certificates|deploy-certs:Deploy certificates as K8s secrets"
    
    # DNS Configuration
    ["🌐 DNS Configuration"]="coredns-rewrite:Configure CoreDNS rewrite rules for 3GPP names"
    
    # Database
    ["🗄️ Database"]="mongodb-hplmn:Deploy MongoDB for HPLMN|mongodb-install:Install MongoDB 4.4 locally|mongodb-access:Manage MongoDB external access|subscribers:Manage subscriber database"
    
    # Management & Monitoring
    ["🔧 Management & Monitoring"]="restart-pods:Restart pods in Open5GS namespaces|get-status:Show status of Open5GS deployments|copy-pcap:Copy PCAP files from pods to local directory"
    
    # WebUI
    ["🌐 WebUI"]="deploy-webui:Deploy Open5GS WebUI (HPLMN only)|deploy-networkui:Deploy Open5GS NetworkUI"
    
    # Cleanup
    ["🧹 Cleanup"]="clean-k8s:Clean Kubernetes resources|clean-docker:Clean Docker resources"
    
    # Information
    ["ℹ️ Information"]="version:Show version information|help:Show detailed help"
)

# Global variables
current_category=0
current_item=0
total_categories=${#MENU_CATEGORIES[@]}

# ===============================
# Helper Functions
# ===============================

print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

cleanup_and_exit() {
    # Show cursor if supported
    tput cnorm 2>/dev/null || true
    clear
    exit 0
}

# Handle Ctrl+C
trap cleanup_and_exit SIGINT

# ===============================
# Terminal UI Functions
# ===============================

draw_header() {
    clear
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD}                 Open5GS Scripts CLI v${VERSION}                 ${NC}"
    echo -e "${CYAN}${BOLD}                  Interactive Menu System                   ${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD} ${WHITE}Use UP/DOWN arrows (or j/k) to navigate, Enter to execute${CYAN}     ${NC}"
    echo -e "${CYAN}${BOLD} ${WHITE}Use LEFT/RIGHT arrows (or w/l) for categories, 'q' quit, 'h' help${CYAN} ${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo
}

draw_categories() {
    echo -e "${YELLOW}${BOLD}Categories:${NC}"
    for i in "${!MENU_CATEGORIES[@]}"; do
        if [ $i -eq $current_category ]; then
            echo -e "  ${GREEN}${BOLD}▶ ${MENU_CATEGORIES[$i]}${NC}"
        else
            echo -e "  ${DIM}  ${MENU_CATEGORIES[$i]}${NC}"
        fi
    done
    echo
}

draw_items() {
    local category="${MENU_CATEGORIES[$current_category]}"
    local items="${MENU_ITEMS[$category]}"
    
    echo -e "${YELLOW}${BOLD}Commands:${NC}"
    
    if [ -z "$items" ]; then
        echo -e "  ${DIM}No commands available${NC}"
        return
    fi
    
    IFS='|' read -ra ITEMS <<< "$items"
    local item_count=0
    
    for item in "${ITEMS[@]}"; do
        IFS=':' read -ra ITEM_PARTS <<< "$item"
        local cmd="${ITEM_PARTS[0]}"
        local desc="${ITEM_PARTS[1]}"
        
        if [ $item_count -eq $current_item ]; then
            echo -e "  ${GREEN}${BOLD}▶ ${cmd}${NC}"
            echo -e "    ${WHITE}${desc}${NC}"
        else
            echo -e "  ${DIM}  ${cmd}${NC}"
            echo -e "    ${DIM}${desc}${NC}"
        fi
        echo
        ((item_count++))
    done
}

draw_footer() {
    echo
    echo -e "${CYAN}${BOLD}================================================================${NC}"
    echo -e "${CYAN}${BOLD} ${WHITE}Controls: UP/DOWN (j/k) Navigate | LEFT/RIGHT (w/l) Categories${CYAN}  ${NC}"
    echo -e "${CYAN}${BOLD} ${WHITE}Commands: Enter Execute | 'h' Help | 'q' Quit | 'r' Refresh    ${CYAN} ${NC}"
    echo -e "${CYAN}${BOLD}================================================================${NC}"
}

get_current_command() {
    local category="${MENU_CATEGORIES[$current_category]}"
    local items="${MENU_ITEMS[$category]}"
    
    if [ -z "$items" ]; then
        echo ""
        return
    fi
    
    IFS='|' read -ra ITEMS <<< "$items"
    local item_count=0
    
    for item in "${ITEMS[@]}"; do
        if [ $item_count -eq $current_item ]; then
            IFS=':' read -ra ITEM_PARTS <<< "$item"
            echo "${ITEM_PARTS[0]}"
            return
        fi
        ((item_count++))
    done
    
    echo ""
}

get_item_count() {
    local category="${MENU_CATEGORIES[$current_category]}"
    local items="${MENU_ITEMS[$category]}"
    
    if [ -z "$items" ]; then
        echo "0"
        return
    fi
    
    IFS='|' read -ra ITEMS <<< "$items"
    echo "${#ITEMS[@]}"
}

execute_command() {
    local cmd=$(get_current_command)
    
    if [ -z "$cmd" ]; then
        echo -e "${RED}No command to execute${NC}"
        return
    fi
    
    # Show cursor for command execution
    tput cnorm 2>/dev/null || true
    clear
    
    echo -e "${GREEN}${BOLD}Executing: $cmd${NC}"
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -n 1
    echo
    
    # Check if CLI script exists
    if [ ! -f "$CLI_SCRIPT" ]; then
        echo -e "${RED}Error: CLI script not found at $CLI_SCRIPT${NC}"
        echo -e "${YELLOW}Press Enter to return to menu...${NC}"
        read -n 1
        return
    fi
    
    # Execute the command
    if [ "$cmd" = "help" ]; then
        bash "$CLI_SCRIPT" --help
    elif [ "$cmd" = "version" ]; then
        bash "$CLI_SCRIPT" version
    else
        echo -e "${BLUE}You can now enter additional arguments for this command:${NC}"
        echo -e "${WHITE}$CLI_SCRIPT $cmd ${DIM}[your arguments here]${NC}"
        echo
        read -p "Arguments (press Enter for none): " args
        
        if [ -n "$args" ]; then
            bash "$CLI_SCRIPT" "$cmd" $args
        else
            bash "$CLI_SCRIPT" "$cmd"
        fi
    fi
    
    echo
    echo -e "${YELLOW}Press Enter to return to menu...${NC}"
    read -n 1
}

show_detailed_help() {
    local cmd=$(get_current_command)
    
    # Show cursor for help display
    tput cnorm 2>/dev/null || true
    clear
    
    if [ -n "$cmd" ] && [ "$cmd" != "help" ] && [ "$cmd" != "version" ]; then
        echo -e "${GREEN}${BOLD}Detailed help for: $cmd${NC}"
        echo
        bash "$CLI_SCRIPT" help "$cmd" 2>/dev/null || {
            echo -e "${YELLOW}No detailed help available for this command${NC}"
            echo -e "${BLUE}Try: $CLI_SCRIPT $cmd --help${NC}"
        }
    else
        echo -e "${GREEN}${BOLD}General CLI Help${NC}"
        echo
        bash "$CLI_SCRIPT" --help
    fi
    
    echo
    echo -e "${YELLOW}Press Enter to return to menu...${NC}"
    read -n 1
}

# ===============================
# Main Menu Loop
# ===============================

main_menu() {
    # Hide cursor if supported
    tput civis 2>/dev/null || true
    
    while true; do
        # Draw the interface
        draw_header
        draw_categories
        echo
        draw_items
        draw_footer
        
        # Read user input with better compatibility
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # Escape sequence
                read -rsn1 -t 0.1 key2
                if [ "$key2" = "[" ]; then
                    read -rsn1 -t 0.1 key3
                    case "$key3" in
                        'A') # Up arrow
                            if [ $current_item -gt 0 ]; then
                                ((current_item--))
                            fi
                            ;;
                        'B') # Down arrow
                            local max_items=$(get_item_count)
                            if [ $current_item -lt $((max_items - 1)) ]; then
                                ((current_item++))
                            fi
                            ;;
                        'C') # Right arrow
                            if [ $current_category -lt $((total_categories - 1)) ]; then
                                ((current_category++))
                                current_item=0
                            fi
                            ;;
                        'D') # Left arrow
                            if [ $current_category -gt 0 ]; then
                                ((current_category--))
                                current_item=0
                            fi
                            ;;
                    esac
                fi
                ;;
            '') # Enter key
                execute_command
                ;;
            'q'|'Q') # Quit
                cleanup_and_exit
                ;;
            'h'|'H') # Help
                show_detailed_help
                ;;
            'r'|'R') # Refresh
                # Just redraw the menu
                ;;
            'k'|'K') # Alternative up (vim-like)
                if [ $current_item -gt 0 ]; then
                    ((current_item--))
                fi
                ;;
            'j'|'J') # Alternative down (vim-like)
                local max_items=$(get_item_count)
                if [ $current_item -lt $((max_items - 1)) ]; then
                    ((current_item++))
                fi
                ;;
            'l'|'L') # Alternative right (vim-like)
                if [ $current_category -lt $((total_categories - 1)) ]; then
                    ((current_category++))
                    current_item=0
                fi
                ;;
            'w'|'W') # Alternative left (vim-like)
                if [ $current_category -gt 0 ]; then
                    ((current_category--))
                    current_item=0
                fi
                ;;
        esac
    done
}

# ===============================
# Entry point
# ===============================

# Check if CLI script exists
if [ ! -f "$CLI_SCRIPT" ]; then
    echo -e "${RED}Error: CLI script not found at $CLI_SCRIPT${NC}"
    echo -e "${YELLOW}Please make sure cli.sh is in the current directory${NC}"
    exit 1
fi

# Check terminal capabilities
if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo -e "${RED}Error: This script requires an interactive terminal${NC}"
    exit 1
fi

# Start the interactive menu
main_menu 