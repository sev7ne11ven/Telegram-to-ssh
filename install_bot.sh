#!/bin/bash

# ==============================================================================
# Telegram SSH Bot Auto-Installer (v3)
# ==============================================================================
# This script automates the setup of a Python-based Telegram bot on an
# Ubuntu server. The bot allows you to execute predefined SSH commands,
# monitor server status, and perform health checks.
#
# What it does:
# 1. Prompts for Telegram Bot Token, authorized User ID, and server location.
# 2. Installs necessary packages (python3, pip, psutil, smartmontools, etc.).
# 3. Creates the Python bot script file with proper configuration.
# 4. Creates a systemd service file to run the bot on startup.
# 5. Enables and starts the systemd service.
# ==============================================================================

# --- Color Definitions ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Get the original user who ran sudo ---
if [ -n "$SUDO_USER" ]; then
    ORIGINAL_USER=$SUDO_USER
else
    ORIGINAL_USER=$USER
fi

echo -e "${GREEN}--- Telegram SSH Bot Installer ---${NC}"
echo "This script will guide you through the setup process."
echo

# --- Pre-run Cleanup ---
# Stop the service if it's already running to prevent issues
if systemctl is-active --quiet telegram-ssh-bot.service; then
    echo -e "${YELLOW}Stopping existing bot service...${NC}"
    sudo systemctl stop telegram-ssh-bot.service
fi

# --- Step 1: Gather User Input ---
echo -e "${YELLOW}Please provide the following information:${NC}"

read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Enter your Telegram User ID (this is the only user who can use the bot): " TELEGRAM_USER_ID
read -p "Enter a name/location for this server (e.g., 'Home Server'): " SERVER_LOCATION

# --- Input Validation ---
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_USER_ID" ] || [ -z "$SERVER_LOCATION" ]; then
    echo -e "${RED}Error: All fields are required. Please run the script again.${NC}"
    exit 1
fi

echo
echo -e "${GREEN}--- Configuration Summary ---${NC}"
echo "Bot Token: [CENSORED]"
echo "User ID: $TELEGRAM_USER_ID"
echo "Server Location: $SERVER_LOCATION"
echo "Bot will be installed in: /opt/telegram_ssh_bot"
echo "Bot will run as user: $ORIGINAL_USER"
echo

read -p "Is this correct? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Installation cancelled."
    exit 1
fi

# --- Step 2: Install Dependencies ---
echo
echo -e "${GREEN}--- Installing System Dependencies ---${NC}"
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv smartmontools lm-sensors sysstat

# --- Step 3: Create Application Directory and Virtual Environment ---
echo
echo -e "${GREEN}--- Setting up Application Environment ---${NC}"
BOT_DIR="/opt/telegram_ssh_bot"
sudo rm -rf $BOT_DIR # Clean up previous installations
sudo mkdir -p $BOT_DIR
sudo chown $ORIGINAL_USER:$ORIGINAL_USER $BOT_DIR

# Create Python virtual environment as the target user
sudo -u $ORIGINAL_USER python3 -m venv $BOT_DIR/venv

# Activate venv to install packages
source $BOT_DIR/venv/bin/activate

echo "Installing Python packages (requests, psutil)..."
pip install requests psutil

# Deactivate venv
deactivate

# --- Step 4: Create the Python Bot Script ---
echo
echo -e "${GREEN}--- Creating Python Bot Script ---${NC}"

# Use a heredoc to write the file directly, with variables expanded by the shell.
# This is a much more reliable method than find-and-replace.
sudo tee "$BOT_DIR/bot.py" > /dev/null << EOF
import os
import sys
import json
import time
import subprocess
import requests
import psutil
import logging
from datetime import datetime

# --- Configuration ---
# These values are set by the installer script.
BOT_TOKEN = "$TELEGRAM_BOT_TOKEN"
ALLOWED_USER_ID = $TELEGRAM_USER_ID
SERVER_LOCATION = "$SERVER_LOCATION"

# --- Logging Setup ---
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# --- Helper Functions ---
def send_telegram_message(chat_id, text, reply_markup=None):
    """Sends a message to a given Telegram chat ID."""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': 'Markdown'
    }
    if reply_markup:
        payload['reply_markup'] = json.dumps(reply_markup)

    try:
        response = requests.post(url, json=payload, timeout=10)
        response.raise_for_status()
        logger.info(f"Message sent to {chat_id}")
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send message: {e}")

def run_command(command):
    """Executes a shell command and returns its output."""
    try:
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error executing command:\n{e.stderr}"

def create_bar_chart(value, max_value=100, length=15):
    """Creates a simple text-based bar chart."""
    if not isinstance(value, (int, float)) or value < 0:
        return "[ N/A ]"
    percentage = (value / max_value) * 100
    filled_length = int(length * value // max_value)
    bar = '█' * filled_length + '░' * (length - filled_length)
    return f"[{bar}] {percentage:.1f}%"

# --- Command Functions ---
def get_help_text():
    return (
        f"*Welcome to the {SERVER_LOCATION} Bot!* 🤖\n\n"
        "Here are the available commands:\n\n"
        "*/status* - Show current server status.\n"
        "*/health* - Perform a detailed health check.\n"
        "*/reboot* - Reboot the server (requires confirmation).\n"
        "*/shutdown* - Shut down the server (requires confirmation).\n"
        "*/suspend* - Suspend the server (requires confirmation).\n"
        "*/top* - Show top 5 memory-consuming processes.\n"
        "*/uptime* - Show server uptime.\n"
        "*/help* - Show this help message."
    )

def get_status_report():
    """Generates a full system status report."""
    # CPU
    cpu_percent = psutil.cpu_percent(interval=1)
    cpu_bar = create_bar_chart(cpu_percent)

    # RAM
    mem = psutil.virtual_memory()
    mem_bar = create_bar_chart(mem.percent)

    # Disk
    disk = psutil.disk_usage('/')
    disk_bar = create_bar_chart(disk.percent)

    # Temperature
    temp_text = "N/A"
    try:
        temps = psutil.sensors_temperatures()
        # Look for 'coretemp' or 'k10temp' for CPU temps
        for sensor in ['coretemp', 'k10temp']:
            if sensor in temps:
                core_temps = [temp.current for temp in temps[sensor]]
                if core_temps:
                    avg_temp = sum(core_temps) / len(core_temps)
                    temp_text = f"{avg_temp:.1f}°C"
                    break # Found a sensor, no need to continue
        if temp_text == "N/A": # Fallback for other systems
            for name, entries in temps.items():
                if entries:
                    temp_text = f"{entries[0].current}°C"
                    break
    except (AttributeError, KeyError):
        temp_text = "N/A (install `lm-sensors`)"


    # Network
    net_io = psutil.net_io_counters()
    net_text = f"Sent: {net_io.bytes_sent / (1024*1024):.2f} MB, Recv: {net_io.bytes_recv / (1024*1024):.2f} MB"

    report = (
        f"*📊 Server Status: {SERVER_LOCATION}*\n"
        f"\`{'─'*25}\`\n"
        f"\`CPU Usage :\` {cpu_bar}\n"
        f"\`RAM Usage :\` {mem_bar}\n"
        f"\`Disk Usage:\` {disk_bar}\n"
        f"\`CPU Temp  :\` {temp_text}\n"
        f"\`Network   :\` {net_text}\n"
        f"\`{'─'*25}\`\n"
        f"_Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_"
    )
    return report

def get_health_check():
    """Performs a disk health check using smartctl."""
    report = "*🩺 Server Health Check*\n"
    report += f"\`{'─'*25}\`\n"

    # Filesystem check
    df_output = run_command("df -h /")
    report += f"*Filesystem Usage:*\n\`\`\`\n{df_output}\n\`\`\`\n"

    # SMART health check
    try:
        # Find all block devices
        lsblk_out = run_command("lsblk -d -n -o NAME,TYPE | grep 'disk' | awk '{print \$1}'")
        drives = [f"/dev/{d}" for d in lsblk_out.split('\n') if d]
        report += "*Disk S.M.A.R.T. Status:*\n"
        found_drive = False
        if not drives:
             report += "\`No physical drives found to check.\`\n"
        else:
            for drive in drives:
                # Check if it's a physical drive that supports SMART
                smart_check = run_command(f"sudo smartctl -i {drive} | grep 'SMART support is:'")
                if "Available" in smart_check and "Enabled" in smart_check:
                    found_drive = True
                    health_status = run_command(f"sudo smartctl -H {drive} | grep 'test result'")
                    report += f"\`{drive}:\` {health_status}\n"
            if not found_drive:
                 report += "\`No SMART-enabled drives found.\`\n"

    except Exception as e:
        report += f"\`Could not perform SMART check. Ensure 'smartmontools' is installed and bot has sudo rights.\`\n\`Error: {e}\`\n"

    return report

def get_top_processes():
    """Gets top 5 processes by memory usage."""
    procs = sorted(psutil.process_iter(['pid', 'name', 'memory_info']),
                   key=lambda p: p.info['memory_info'].rss,
                   reverse=True)
    report = "*Top 5 Memory-Intensive Processes*\n"
    report += "\`PID   | RSS    | Name\`\n"
    report += f"\`{'─'*30}\`\n"
    for p in procs[:5]:
        rss = f"{p.info['memory_info'].rss / (1024*1024):.1f}M"
        report += f"\`{p.info['pid']:<5} | {rss:<6} | {p.info['name']}\`\n"
    return report

def get_uptime():
    """Gets server uptime."""
    return run_command("uptime -p")

# --- Main Bot Logic ---
def handle_update(update):
    """Processes incoming Telegram updates."""
    if 'message' in update:
        message = update['message']
        chat_id = message['chat']['id']
        user_id = message['from']['id']
        text = message.get('text', '')
    elif 'callback_query' in update:
        callback_query = update['callback_query']
        chat_id = callback_query['message']['chat']['id']
        user_id = callback_query['from']['id']
        text = callback_query['data']
        # Answer callback query to remove the "loading" state on the button
        try:
            requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/answerCallbackQuery", json={'callback_query_id': callback_query['id']}, timeout=5)
        except requests.exceptions.RequestException:
            logger.warning("Could not answer callback query.")
    else:
        return

    # --- Security Check ---
    if user_id != ALLOWED_USER_ID:
        logger.warning(f"Unauthorized access attempt by user ID: {user_id}")
        send_telegram_message(chat_id, "🚫 You are not authorized to use this bot.")
        return

    logger.info(f"Received command '{text}' from user {user_id}")

    # --- Command Routing ---
    if text == '/start' or text == '/help':
        send_telegram_message(chat_id, get_help_text(), get_main_keyboard())
    elif text == '/status':
        send_telegram_message(chat_id, get_status_report(), get_main_keyboard())
    elif text == '/health':
        send_telegram_message(chat_id, get_health_check(), get_main_keyboard())
    elif text == '/top':
        send_telegram_message(chat_id, get_top_processes(), get_main_keyboard())
    elif text == '/uptime':
        send_telegram_message(chat_id, f"Server uptime: \`{get_uptime()}\`", get_main_keyboard())
    elif text.startswith('/reboot'):
        handle_confirmation(chat_id, 'reboot')
    elif text.startswith('/shutdown'):
        handle_confirmation(chat_id, 'shutdown')
    elif text.startswith('/suspend'):
        handle_confirmation(chat_id, 'suspend')
    elif text.startswith('confirm_'):
        action = text.split('_')[1]
        execute_action(chat_id, action)

def get_main_keyboard():
    """Returns the main inline keyboard."""
    keyboard = {
        "inline_keyboard": [
            [
                {"text": "📊 Status", "callback_data": "/status"},
                {"text": "🩺 Health", "callback_data": "/health"},
                {"text": "📈 Top Processes", "callback_data": "/top"}
            ],
            [
                {"text": "🚨 Reboot", "callback_data": "/reboot"},
                {"text": "🚫 Shutdown", "callback_data": "/shutdown"},
                {"text": "💤 Suspend", "callback_data": "/suspend"}
            ]
        ]
    }
    return keyboard

def handle_confirmation(chat_id, action):
    """Sends a confirmation message for critical actions."""
    keyboard = {
        "inline_keyboard": [
            [
                {"text": f"✅ Yes, {action.capitalize()}", "callback_data": f"confirm_{action}"},
                {"text": "❌ No, Cancel", "callback_data": "/help"}
            ]
        ]
    }
    send_telegram_message(chat_id, f"⚠️ *Are you sure you want to {action} the server?*", reply_markup=keyboard)

def execute_action(chat_id, action):
    """Executes the confirmed critical action."""
    send_telegram_message(chat_id, f"✅ Command received. Executing *{action}* now...")
    time.sleep(1) # Give Telegram time to send the message
    if action == 'reboot':
        run_command("sudo /sbin/reboot")
    elif action == 'shutdown':
        run_command("sudo /sbin/shutdown now")
    elif action == 'suspend':
        run_command("sudo systemctl suspend")

def main():
    """Main function to start the bot."""
    # Simple check to see if config looks valid before starting
    if " " in BOT_TOKEN or len(BOT_TOKEN) < 20:
        logger.error("FATAL: Bot token appears to be invalid.")
        sys.exit(1)
    if not isinstance(ALLOWED_USER_ID, int):
        logger.error("FATAL: User ID appears to be invalid.")
        sys.exit(1)
        
    logger.info("Bot started!")
    send_telegram_message(ALLOWED_USER_ID, f"🤖 Bot is online on *{SERVER_LOCATION}*.\nPerforming startup health check...")
    # Send initial health check on startup
    send_telegram_message(ALLOWED_USER_ID, get_health_check(), get_main_keyboard())

    last_update_id = 0
    while True:
        try:
            url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates?offset={last_update_id + 1}&timeout=30"
            response = requests.get(url, timeout=35)
            response.raise_for_status()
            updates = response.json().get('result', [])

            for update in updates:
                last_update_id = update['update_id']
                handle_update(update)

        except requests.exceptions.RequestException as e:
            logger.error(f"Network error: {e}. Retrying in 15 seconds...")
            time.sleep(15)
        except Exception as e:
            logger.error(f"An unexpected error occurred: {e}", exc_info=True)
            time.sleep(15)

if __name__ == '__main__':
    main()
EOF

# Set correct ownership for the script
sudo chown $ORIGINAL_USER:$ORIGINAL_USER "$BOT_DIR/bot.py"
echo "Python script created at $BOT_DIR/bot.py"

# --- Step 5: Create systemd Service File ---
echo
echo -e "${GREEN}--- Creating systemd Service ---${NC}"
SERVICE_FILE="/etc/systemd/system/telegram-ssh-bot.service"

sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Telegram SSH Bot
After=network.target

[Service]
User=$ORIGINAL_USER
Group=$(id -gn $ORIGINAL_USER)
WorkingDirectory=$BOT_DIR
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "systemd service file created at $SERVICE_FILE"

# --- Step 6: Grant Sudo Permissions for Power Commands ---
echo
echo -e "${GREEN}--- Configuring Sudo Permissions ---${NC}"
echo "The bot needs passwordless sudo access for reboot, shutdown, and smartctl."
SUDOERS_FILE="/etc/sudoers.d/99-telegram-bot"
(
    echo "$ORIGINAL_USER ALL=(ALL) NOPASSWD: /sbin/reboot"
    echo "$ORIGINAL_USER ALL=(ALL) NOPASSWD: /sbin/shutdown"
    echo "$ORIGINAL_USER ALL=(ALL) NOPASSWD: /bin/systemctl suspend"
    echo "$ORIGINAL_USER ALL=(ALL) NOPASSWD: /usr/sbin/smartctl"
) | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 0440 "$SUDOERS_FILE"

echo "Sudo permissions configured."

# --- Step 7: Enable and Start the Service ---
echo
echo -e "${GREEN}--- Starting the Bot Service ---${NC}"
sudo systemctl daemon-reload
sudo systemctl enable telegram-ssh-bot.service
sudo systemctl restart telegram-ssh-bot.service

# --- Final Status Check ---
sleep 3 # Give the service a moment to start
echo
echo -e "${GREEN}--- Installation Complete! ---${NC}"
if systemctl is-active --quiet telegram-ssh-bot.service; then
    echo -e "${GREEN}The bot service is running successfully.${NC}"
else
    echo -e "${RED}The bot service failed to start. Please check the logs.${NC}"
fi
echo
echo "You can check its status with:"
echo -e "${YELLOW}sudo systemctl status telegram-ssh-bot.service${NC}"
echo
echo "To see the bot's logs, use:"
echo -e "${YELLOW}sudo journalctl -u telegram-ssh-bot.service -f${NC}"
echo
echo -e "${GREEN}Open Telegram and send /start to your bot to begin!${NC}"
