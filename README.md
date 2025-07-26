Telegram SSH Control Bot for Ubuntu
A simple, secure, and powerful Python Telegram bot to manage and monitor your Ubuntu server using SSH commands. This bot runs as a systemd service, starts automatically on boot, and is installed via a single, convenient auto-install script.

✨ Features
System Commands: Execute critical system commands with confirmation.

Reboot

Shutdown

Suspend

Live Server Monitoring: Get real-time server status with a clean, visual interface.

CPU Usage (with text-based graph)

RAM Usage (with text-based graph)

Disk Usage (with text-based graph)

CPU Temperature

Network I/O Statistics

Health & Diagnostics:

Daily Health Check: Automatically performs a health check on startup.

Disk Health: Checks S.M.A.R.T. status of all physical drives.

Process Monitoring: View the top 5 memory-consuming processes.

Uptime: Check how long the server has been running.

Secure:

The bot will only respond to the Telegram User ID you specify during installation.

Uses passwordless sudo for specific, predefined commands only.

Easy Installation: A single auto-install script handles all dependencies, configuration, and service setup.

Interactive UI: Uses Telegram's inline keyboard buttons for quick and easy command access.

📋 Requirements
An Ubuntu Server (20.04 LTS or newer is recommended).

sudo or root access on the server.

A Telegram account.

🚀 Installation
The entire process is automated with a single script.

1. Get Your Telegram Credentials
You will need two pieces of information from Telegram before running the installer.

Bot Token:

Open Telegram and search for the @BotFather.

Start a chat and send /newbot.

Follow the prompts to name your bot.

@BotFather will give you a unique token. Save this token.

User ID:

Search for the @userinfobot.

Start a chat and it will immediately reply with your user information, including your ID. Save this ID.

2. Run the Installer Script
Now, connect to your Ubuntu server via SSH and follow these steps.

Download the Installer:
Save the install_bot.sh script from this repository to your server.

Make the Script Executable:
Open a terminal on your server and run:

chmod +x install_bot.sh

Execute the Installer:
Run the script with sudo. It needs elevated privileges to install packages and set up the system service.

sudo ./install_bot.sh

Follow the Prompts:
The script will ask for the Bot Token, your User ID, and a Server Name/Location. Enter the information you gathered earlier.

That's it! The script will handle everything else. Once it finishes, the bot is running.

🤖 Usage
Open Telegram and start a chat with the bot you created.

Send the /start or /help command.

The bot will reply with a welcome message and an interactive keyboard. Use the buttons to manage your server.

🔧 Troubleshooting
If the bot doesn't respond, you can check its status and logs directly on the server.

Check Service Status:

sudo systemctl status telegram-ssh-bot.service

View Live Logs:

sudo journalctl -u telegram-ssh-bot.service -f

Restart the Bot:

sudo systemctl restart telegram-ssh-bot.service

🔒 Security Note
This bot is designed to be run by a trusted user. The script configures sudo to allow the user running the bot to execute specific power-related commands (reboot, shutdown, suspend, smartctl) without a password. Ensure you understand the security implications of this before proceeding. The bot will only respond to the ALLOWED_USER_ID specified during installation.
