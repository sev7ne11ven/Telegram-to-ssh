
---

# 🛡️ Telegram SSH Bot Installer

Easily set up a Telegram bot to monitor and control your Ubuntu server via Telegram commands like `/status`, `/shutdown`, `/reboot`, and more.

---

## 🔧 How to Use This Installer

### 1. Get Your Telegram Bot Token and User ID

* **Bot Token**:
  Talk to [@BotFather](https://t.me/BotFather) on Telegram.
  Create a new bot, and it will give you a **token**.

* **User ID**:
  Talk to [@userinfobot](https://t.me/userinfobot).
  It will show you your **numeric Telegram user ID**.

---

### 2. Save the Script

Copy the entire code block from `install_bot.sh` and save it to a file on your **Ubuntu server**.

```bash
nano install_bot.sh
# Paste the script and save (Ctrl+O, Enter, Ctrl+X)
```

---

### 3. Make it Executable

Run this command in your terminal to make the script executable:

```bash
chmod +x install_bot.sh
```

---

### 4. Run the Installer

Execute the script with `sudo` since it needs to install packages and create system files:

```bash
sudo ./install_bot.sh
```

---

### 5. Follow the Prompts

The script will ask for:

* Your **Bot Token**
* Your **Telegram User ID**
* A **nickname** or label for your server

Enter the information carefully when prompted.

---

### ✅ After Installation

* Your bot will now run **in the background**
* It will automatically **start on boot** using `systemd`
* You can now go to Telegram, open your bot, and send:

```plaintext
/start
```

You’ll see an **inline keyboard** and can begin managing your server.

---

## 🔁 Available Commands

| Command     | Description                 |
| ----------- | --------------------------- |
| `/start`    | Show the main keyboard      |
| `/status`   | Server usage + status graph |
| `/shutdown` | Shut down the server        |
| `/reboot`   | Reboot the server           |
| `/suspend`  | Suspend the server          |
| `/help`     | Show help text              |

---

## 💡 Notes

* Only **one authorized user** (your user ID) can access the bot.
* Works on **Ubuntu 20.04+**.
* Requires Python 3.8+ and `python-telegram-bot`.

---

Feel free to contribute or customize the bot after installation. Happy self-hosting! 🚀

---
