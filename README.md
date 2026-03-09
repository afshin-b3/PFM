<p align="center">
  <pre>
   ██████╗ ███████╗███╗   ███╗
   ██╔══██╗██╔════╝████╗ ████║
   ██████╔╝█████╗  ██╔████╔██║
   ██╔═══╝ ██╔══╝  ██║╚██╔╝██║
   ██║     ██║     ██║ ╚═╝ ██║
   ╚═╝     ╚═╝     ╚═╝     ╚═╝
  </pre>
  <h3>Port Forward Manager</h3>
  <p>Port Forwarding Tool with Per-Port Bandwidth Monitoring</p>

  <a href="https://t.me/AbrAfagh"><img src="https://img.shields.io/badge/Telegram-Channel-blue?logo=telegram" alt="Telegram"></a>
  <img src="https://img.shields.io/badge/Version-1.7-green" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
  <img src="https://img.shields.io/badge/OS-Ubuntu%2FDebian-orange" alt="OS">
</p>

---

<div dir="rtl" align="right">

## 🇮🇷 فارسی

### پی‌اف‌ام چیست؟

PFM یک ابزار مدیریت پورت فوروارد با قابلیت مانیتورینگ ترافیک روی هر پورت است. این ابزار به شما اجازه میدهد پورت‌های سرور ایران را به سرور خارج فوروارد کنید و مصرف ترافیک هر کاربر را به صورت دقیق پیگیری و محدود کنید.

### ✨ امکانات

- **سه موتور** — iptables، HAProxy و Realm (بهترین عملکرد)
- **مانیتورینگ ترافیک** — مشاهده مصرف دانلود روی هر پورت به صورت لحظه‌ای
- **محدودیت ترافیک** — تعیین سقف مصرف بر حسب گیگابایت و قطع خودکار
- **مدیریت کاربران** — اختصاص پورت به کاربران با لینک آیدی تلگرام
- **ربات تلگرام** — مدیریت کامل از راه دور با ربات تلگرام
- **بکاپ خودکار** — گزارش بکاپ ترافیک هر ۶ ساعت
- **هلث‌چک Realm** — ریستارت خودکار سرویس‌های خراب
- **پشتیبانی IPv4 و IPv6**

### 🚀 نصب سریع

<div dir="ltr" align="left">

```bash
bash <(curl -s https://raw.githubusercontent.com/afshin-b3/PFM/main/pfm.sh) install
```

</div>

### 🤖 نصب ربات تلگرام

<div dir="ltr" align="left">

```bash
bash <(curl -s https://raw.githubusercontent.com/afshin-b3/PFM/main/pfm-bot-setup.sh)
```

</div>

### 📬 ارتباط با ما

- کانال تلگرام: [@AbrAfagh](https://t.me/AbrAfagh)

</div>

---

## 🇬🇧 English

### ✨ Features

- **Multi-Engine** — iptables, HAProxy (splice), Realm (zero-copy)
- **Per-Port Bandwidth Monitoring** — Track download usage per port in real-time
- **Traffic Limits** — Set GB limits per port, auto-block when exceeded
- **User Management** — Assign ports to users with Telegram ID linking
- **Telegram Bot** — Full remote management via Telegram bot
- **Auto Backup** — 6-hour automatic traffic backup reports
- **Realm Health Check** — Auto-restart crashed or stuck Realm services
- **MTU Management** — Persistent MTU settings per interface
- **IPv4 & IPv6** — Full dual-stack support
- **Menu-Driven** — Easy interactive CLI interface

## 🚀 Quick Install

```bash
bash <(curl -s https://raw.githubusercontent.com/afshin-b3/PFM/main/pfm.sh) install
```

## 📦 Manual Install

```bash
curl -o /usr/local/bin/pfm https://raw.githubusercontent.com/afshin-b3/PFM/main/pfm.sh
chmod +x /usr/local/bin/pfm
pfm install
```

## 🤖 Telegram Bot Setup

The bot allows you to manage all your PFM servers remotely from Telegram.

```bash
bash <(curl -s https://raw.githubusercontent.com/afshin-b3/PFM/main/pfm-bot-setup.sh)
```

**Bot Features:**
- 📊 View traffic usage per user/port across all servers
- 🔄 Sync traffic data
- 🔴🟢 Block/Unblock ports
- 📝 Set/Edit traffic limits
- ➕➖ Add/Subtract traffic
- 📦 Manual & automatic backups (every 6h)
- ⚙️ Edit server connections from Telegram
- 👤 Users can check their own usage via bot

## 📸 Screenshots

<details>
<summary>CLI Menu</summary>

```
  ──────────────────────────────────────────
         PFM - Port Forward Manager v1.7
              https://t.me/AbrAfagh
  ──────────────────────────────────────────

  1)  Add Tunnel
  2)  Manage Tunnels
  3)  View Traffic
  4)  Monitor (Live)
  5)  Users
  6)  MTU Settings
  7)  Install / Update
  8)  Uninstall
  0)  Exit
```

</details>

<details>
<summary>Traffic View</summary>

```
  Traffic  (Download Only)

  a_real_shit [ON]  TG:1605183796

  PORT    DESTINATION        ENGINE    USED          LIMIT         REMAIN     STATUS
  ──────────────────────────────────────────────────────────────────────────────
  6003    91.107.251.41:6003 realm     2.72 MB       1.16 TB       1.16 TB    Active
  6004    91.107.251.41:6004 realm     381.09 KB     846.00 GB     846.00 GB  Active
  TOTAL                                3.10 MB       2.00 TB       2.00 TB
```

</details>

## ⚙️ Engines

| Engine | Type | Use Case |
|--------|------|----------|
| **iptables** | Kernel NAT | Default, simple port forwarding |
| **HAProxy** | Splice (TCP) | High-performance TCP proxy |
| **Realm** | Zero-copy | Best performance, TCP + UDP |

## 📁 File Structure

```
/usr/local/bin/pfm          # Main script
/usr/local/bin/pfm-cmd      # Bot command helper
/etc/pfm/
├── users/                  # User configs
├── ports/                  # Port configs
├── usage/                  # Traffic data (bytes)
├── mtu/                    # MTU settings
└── realm/                  # Realm TOML configs
```

## 🔧 Commands

```bash
pfm                  # Open interactive menu
pfm install          # Install/Update PFM
pfm restore          # Restore rules after reboot
pfm sync             # Sync traffic counters
pfm json             # JSON output (for bot)
pfm monitor          # Live traffic monitor
pfm uninstall        # Remove PFM
```

## 📋 Requirements

- Ubuntu 18+ / Debian 10+
- Root access
- `curl` or `wget`
- `sshpass` (for bot password auth)

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

## 📄 License

[MIT](LICENSE)

## 📬 Contact

- Telegram Channel: [@AbrAfagh](https://t.me/AbrAfagh)
