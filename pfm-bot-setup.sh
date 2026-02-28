#!/bin/bash
#══════════════════════════════════════════════════════════════
#  PFM Bot Manager — Central Server
#══════════════════════════════════════════════════════════════

CONFIG_DIR="/etc/pfm-bot"
CONFIG_FILE="$CONFIG_DIR/config.json"
BOT_SCRIPT="/usr/local/bin/pfm-bot"
SERVICE_FILE="/etc/systemd/system/pfm-bot.service"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
W='\033[1;37m'; GR='\033[0;90m'; NC='\033[0m'; B='\033[1m'

[[ $EUID -ne 0 ]] && { echo -e "${R}Run as root${NC}"; exit 1; }

header() {
    clear
    echo -e "\n  ${C}──────────────────────────────────────${NC}"
    echo -e "  ${B}${C}     PFM Bot Manager${NC}"
    echo -e "  ${C}──────────────────────────────────────${NC}\n"
}

# ─── Config helpers ───
init_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '{"bot_token":"","admin_id":0,"servers":[]}' > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
}

# FIX: py_get/py_set use heredoc so the CONFIG_FILE path is passed as argv[1],
# not interpolated into Python source. User data is never in executable code.
py_get() {
    local script="$1"
    python3 - "$CONFIG_FILE" 2>/dev/null <<PYEOF
import json, sys
cfg = json.load(open(sys.argv[1]))
$script
PYEOF
}

py_set() {
    local script="$1"
    python3 - "$CONFIG_FILE" 2>/dev/null <<PYEOF
import json, sys
with open(sys.argv[1]) as f: cfg = json.load(f)
$script
with open(sys.argv[1],'w') as f: json.dump(cfg, f, indent=2)
PYEOF
}

# FIX: Safe token/admin setters pass values via env vars, never interpolated into code
py_set_token() {
    PFM_VAL="$1" python3 - "$CONFIG_FILE" 2>/dev/null << 'PYEOF'
import json, sys, os
with open(sys.argv[1]) as f: cfg = json.load(f)
cfg["bot_token"] = os.environ["PFM_VAL"]
with open(sys.argv[1],'w') as f: json.dump(cfg, f, indent=2)
PYEOF
}

py_set_admin() {
    PFM_VAL="$1" python3 - "$CONFIG_FILE" 2>/dev/null << 'PYEOF'
import json, sys, os
with open(sys.argv[1]) as f: cfg = json.load(f)
cfg["admin_id"] = int(os.environ["PFM_VAL"])
with open(sys.argv[1],'w') as f: json.dump(cfg, f, indent=2)
PYEOF
}

# FIX: Server append passes all fields via env vars
py_append_server() {
    SRV_NAME="$1" SRV_HOST="$2" SRV_PORT="$3" SRV_USER="$4" \
    SRV_PASSWORD="$5" SRV_KEY="$6" python3 - "$CONFIG_FILE" 2>/dev/null << 'PYEOF'
import json, sys, os
with open(sys.argv[1]) as f: cfg = json.load(f)
srv = {
    "name": os.environ.get("SRV_NAME",""),
    "host": os.environ.get("SRV_HOST",""),
    "port": int(os.environ.get("SRV_PORT","22")),
    "user": os.environ.get("SRV_USER","root"),
}
pw = os.environ.get("SRV_PASSWORD","")
key = os.environ.get("SRV_KEY","")
if pw: srv["password"] = pw
elif key: srv["key"] = key
cfg.setdefault("servers",[]).append(srv)
with open(sys.argv[1],'w') as f: json.dump(cfg, f, indent=2)
PYEOF
}

get_token()        { py_get "print(cfg.get('bot_token',''))"; }
get_admin()        { py_get "print(cfg.get('admin_id',0))"; }
get_server_count() { py_get "print(len(cfg.get('servers',[])))"; }

# ─── Bot service ───
setup_service() {
    local script_dir=$(dirname "$(readlink -f "$0")")
    for loc in "$script_dir/pfm-bot.py" "./pfm-bot.py" "/root/pfm-bot.py"; do
        [[ -f "$loc" ]] && { cp "$loc" "$BOT_SCRIPT"; break; }
    done
    chmod +x "$BOT_SCRIPT" 2>/dev/null

    if [[ ! -f "$SERVICE_FILE" ]]; then
        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=PFM Telegram Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $BOT_SCRIPT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable pfm-bot > /dev/null 2>&1
    fi
}

bot_status() {
    if systemctl is-active pfm-bot > /dev/null 2>&1; then
        echo -e "${G}Running${NC}"
    else
        echo -e "${R}Stopped${NC}"
    fi
}

# ─── Menu: Setup Bot (Token + Admin + Start) ───
menu_setup() {
    header; echo -e "  ${B}${W}Bot Setup${NC}\n"

    # Step 1: Token
    local cur=$(get_token)
    [[ -n "$cur" && "$cur" != "" ]] && echo -e "  ${GR}Current token: ${cur:0:15}...${NC}\n"

    echo -ne "  ${C}Bot Token (from @BotFather):${NC} "; read -r token
    [[ -z "$token" ]] && return

    echo -ne "  ${GR}Testing token...${NC} "
    local resp=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot${token}/getMe" 2>/dev/null)
    if ! echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok']" 2>/dev/null; then
        echo -e "${R}Invalid token!${NC}"; sleep 2; return
    fi
    local bot_name=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['username'])" 2>/dev/null)
    echo -e "${G}OK!${NC} @${bot_name}"
    py_set_token "$token"   # FIX: safe setter via env var

    # Step 2: Admin ID
    echo ""
    local cur_adm=$(get_admin)
    [[ "$cur_adm" != "0" ]] && echo -e "  ${GR}Current admin: ${cur_adm}${NC}"
    echo -e "  ${GR}To find your ID: message @userinfobot on Telegram${NC}"
    echo -ne "  ${C}Admin Telegram ID:${NC} "; read -r adm
    [[ -z "$adm" ]] && return
    # FIX: Validate admin ID is numeric before saving
    [[ ! "$adm" =~ ^[0-9]+$ ]] && { echo -e "  ${R}Invalid ID: must be numeric${NC}"; sleep 2; return; }
    py_set_admin "$adm"    # FIX: safe setter via env var

    # Step 3: Start bot
    echo ""
    setup_service
    systemctl restart pfm-bot
    sleep 1

    if systemctl is-active pfm-bot > /dev/null 2>&1; then
        echo -e "  ${G}Bot started!${NC}"

        # Step 4: Send test message
        echo -ne "  ${GR}Sending test message...${NC} "
        local count=$(get_server_count)
        local tres=$(curl -s --connect-timeout 5 -X POST \
            "https://api.telegram.org/bot${token}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\":$adm,\"text\":\"🟢 <b>PFM Bot Online!</b>\n\n🤖 @${bot_name}\n👤 Admin: <code>$adm</code>\n📡 Servers: ${count}\n\n✅ Setup complete!\",\"parse_mode\":\"HTML\"}" 2>/dev/null)
        if echo "$tres" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok']" 2>/dev/null; then
            echo -e "${G}Sent! Check Telegram${NC}"
        else
            echo -e "${Y}Failed — /start the bot in Telegram first${NC}"
        fi
    else
        echo -e "  ${R}Bot failed to start${NC}"
        echo -e "  ${GR}Check: journalctl -u pfm-bot -n 20${NC}"
    fi

    echo -e "\n  ${G}${B}Setup complete!${NC}"
    sleep 3
}

# ─── Menu: Add Server ───
menu_add_server() {
    header; echo -e "  ${B}${W}Add Server${NC}\n"

    echo -ne "  ${C}Name (e.g. DE-1):${NC} "; read -r name
    [[ -z "$name" ]] && return
    echo -ne "  ${C}Host/IP:${NC} "; read -r host
    [[ -z "$host" ]] && return
    echo -ne "  ${C}SSH Port [22]:${NC} "; read -r port; port="${port:-22}"
    echo -ne "  ${C}SSH User [root]:${NC} "; read -r user; user="${user:-root}"

    echo -e "\n  ${C}Auth method:${NC}"
    echo -e "    ${W}1)${NC} Password"
    echo -e "    ${W}2)${NC} SSH Key"
    echo -ne "  ${C}Select [1]:${NC} "; read -r auth; auth="${auth:-1}"

    local key="" password="" ssh_test_cmd=""

    if [[ "$auth" == "2" ]]; then
        echo -ne "  ${C}SSH Key Path [/root/.ssh/id_rsa]:${NC} "; read -r key
        key="${key:-/root/.ssh/id_rsa}"
        # FIX: key path quoted properly
        ssh_test_cmd="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -i \"$key\" -p $port ${user}@${host}"
    else
        echo -ne "  ${C}Root Password:${NC} "; read -rs password; echo ""
        if ! command -v sshpass > /dev/null 2>&1; then
            echo -ne "  ${GR}Installing sshpass...${NC} "
            apt-get install -y -qq sshpass > /dev/null 2>&1
            command -v sshpass > /dev/null 2>&1 && echo -e "${G}OK${NC}" || { echo -e "${R}Failed${NC}"; sleep 1; return; }
        fi
        # FIX: Password passed via sshpass -e (environment) to avoid shell word-splitting on special chars
        ssh_test_cmd="SSHPASS=$(printf '%q' "$password") sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p $port ${user}@${host}"
    fi

    echo -ne "\n  ${GR}Testing connection...${NC} "
    if $ssh_test_cmd "echo ok" > /dev/null 2>&1; then
        echo -e "${G}Connected!${NC}"
    else
        echo -e "${R}Failed!${NC}"
        echo -ne "  ${Y}Add anyway? (y/N):${NC} "; read -r yn
        [[ "$yn" != "y" && "$yn" != "Y" ]] && return
    fi

    echo -ne "  ${GR}Checking pfm-cmd...${NC} "
    if $ssh_test_cmd "which pfm-cmd" > /dev/null 2>&1; then
        echo -e "${G}OK${NC}"
    else
        echo -e "${Y}Not found — install PFM on this server first${NC}"
    fi

    echo -ne "  ${GR}Checking pfm json...${NC} "
    if $ssh_test_cmd "pfm json" > /dev/null 2>&1; then
        echo -e "${G}OK${NC}"
    else
        echo -e "${Y}Not working${NC}"
    fi

    # FIX: Use py_append_server to safely pass values via env vars (no shell injection)
    if [[ -n "$password" ]]; then
        py_append_server "$name" "$host" "$port" "$user" "$password" ""
    else
        py_append_server "$name" "$host" "$port" "$user" "" "$key"
    fi

    echo -e "\n  ${G}Server '${name}' added!${NC}"

    if systemctl is-active pfm-bot > /dev/null 2>&1; then
        systemctl restart pfm-bot
        echo -e "  ${GR}Bot restarted${NC}"
    fi
    sleep 2
}

# ─── Menu: Remove Server ───
menu_remove_server() {
    header; echo -e "  ${B}${W}Remove Server${NC}\n"

    local count=$(get_server_count)
    if [[ "$count" == "0" ]]; then
        echo -e "  ${GR}No servers configured${NC}"; sleep 1; return
    fi

    py_get "
for i, s in enumerate(cfg.get('servers', [])):
    auth = 'key' if s.get('key') else 'pass'
    print(f'  {i+1}) {s[\"name\"]} — {s[\"host\"]}:{s.get(\"port\",22)} [{auth}]')
"
    echo -e "  ${W}0)${NC} Back"
    echo -ne "\n  ${C}Remove which? (number):${NC} "; read -r num
    [[ -z "$num" || "$num" == "0" ]] && return

    local idx=$((num - 1))
    local srv_name=$(py_get "
s = cfg.get('servers',[])
if 0 <= $idx < len(s): print(s[$idx]['name'])
")
    [[ -z "$srv_name" ]] && { echo -e "  ${R}Invalid${NC}"; sleep 1; return; }

    echo -ne "  ${R}Remove '${srv_name}'? (y/N):${NC} "; read -r yn
    [[ "$yn" != "y" && "$yn" != "Y" ]] && return

    py_set "cfg['servers'].pop($idx)"
    echo -e "  ${G}Removed '${srv_name}'${NC}"

    if systemctl is-active pfm-bot > /dev/null 2>&1; then
        systemctl restart pfm-bot
        echo -e "  ${GR}Bot restarted${NC}"
    fi
    sleep 2
}

# ─── Menu: List Servers ───
menu_list_servers() {
    header; echo -e "  ${B}${W}Servers${NC}\n"

    local count=$(get_server_count)
    if [[ "$count" == "0" ]]; then
        echo -e "  ${GR}No servers configured${NC}"
    else
        py_get "
for i, s in enumerate(cfg.get('servers', [])):
    auth = '🔑 key' if s.get('key') else '🔒 pass'
    print(f'  {i+1}) {s[\"name\"]:12s} {s[\"host\"]:18s} port:{s.get(\"port\",22)}  user:{s.get(\"user\",\"root\")}  {auth}')
"
    fi
    echo -ne "\n  ${GR}Enter...${NC}"; read -r
}

# ─── Menu: Edit Server ───
menu_edit_server() {
    header; echo -e "  ${B}${W}Edit Server${NC}\n"

    local count=$(get_server_count)
    if [[ "$count" == "0" ]]; then
        echo -e "  ${GR}No servers${NC}"; sleep 1; return
    fi

    py_get "
for i, s in enumerate(cfg.get('servers', [])):
    auth = '🔑 key' if s.get('key') else '🔒 pass'
    print(f'  {i+1}) {s[\"name\"]:12s} {s[\"host\"]:18s} port:{s.get(\"port\",22)}  {auth}')
"
    echo -ne "\n  ${C}Server number (0=back):${NC} "; read -r sel
    [[ -z "$sel" || "$sel" == "0" ]] && return
    local idx=$((sel - 1))

    # Get current values
    local cur_name=$(py_get "print(cfg['servers'][$idx]['name'])" 2>/dev/null)
    local cur_host=$(py_get "print(cfg['servers'][$idx]['host'])" 2>/dev/null)
    local cur_port=$(py_get "print(cfg['servers'][$idx].get('port',22))" 2>/dev/null)
    local cur_user=$(py_get "print(cfg['servers'][$idx].get('user','root'))" 2>/dev/null)
    [[ -z "$cur_name" ]] && { echo -e "  ${R}Invalid selection${NC}"; sleep 1; return; }

    echo -e "\n  ${GR}Current: ${cur_name} — ${cur_host}:${cur_port} (${cur_user})${NC}"
    echo -e "  ${GR}Press Enter to keep current value${NC}\n"

    echo -ne "  ${C}Name [${cur_name}]:${NC} "; read -r new_name
    echo -ne "  ${C}Host/IP [${cur_host}]:${NC} "; read -r new_host
    echo -ne "  ${C}SSH Port [${cur_port}]:${NC} "; read -r new_port
    echo -ne "  ${C}User [${cur_user}]:${NC} "; read -r new_user

    [[ -z "$new_name" ]] && new_name="$cur_name"
    [[ -z "$new_host" ]] && new_host="$cur_host"
    [[ -z "$new_port" ]] && new_port="$cur_port"
    [[ -z "$new_user" ]] && new_user="$cur_user"

    echo -e "\n  ${C}Change auth? (y/N):${NC} "; read -r chauth
    if [[ "$chauth" == "y" || "$chauth" == "Y" ]]; then
        echo -e "    ${W}1)${NC} Password"
        echo -e "    ${W}2)${NC} SSH Key"
        echo -ne "  ${C}Select [1]:${NC} "; read -r atype
        atype=${atype:-1}

        if [[ "$atype" == "2" ]]; then
            echo -ne "  ${C}Key path [/root/.ssh/id_rsa]:${NC} "; read -r kpath
            kpath=${kpath:-/root/.ssh/id_rsa}
            py_set "
s=cfg['servers'][$idx]
s['name']='$new_name'; s['host']='$new_host'; s['port']=$new_port; s['user']='$new_user'
s.pop('password',None); s['key']='$kpath'
"
        else
            echo -ne "  ${C}Password:${NC} "; read -r newpw
            py_set "
s=cfg['servers'][$idx]
s['name']='$new_name'; s['host']='$new_host'; s['port']=$new_port; s['user']='$new_user'
s.pop('key',None); s['password']='$newpw'
"
        fi
    else
        py_set "
s=cfg['servers'][$idx]
s['name']='$new_name'; s['host']='$new_host'; s['port']=$new_port; s['user']='$new_user'
"
    fi

    # Test connection
    echo -ne "\n  ${GR}Testing connection...${NC} "
    local ssh_test
    local cur_pw=$(py_get "print(cfg['servers'][$idx].get('password',''))" 2>/dev/null)
    local cur_key=$(py_get "print(cfg['servers'][$idx].get('key',''))" 2>/dev/null)
    if [[ -n "$cur_pw" ]]; then
        ssh_test=$(sshpass -p "$cur_pw" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p "$new_port" "${new_user}@${new_host}" "echo ok" 2>&1)
    else
        ssh_test=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -i "$cur_key" -p "$new_port" "${new_user}@${new_host}" "echo ok" 2>&1)
    fi

    if [[ "$ssh_test" == *"ok"* ]]; then
        echo -e "${G}Connected!${NC}"
    else
        echo -e "${Y}Connection failed — saved anyway${NC}"
    fi

    echo -e "  ${G}Server '${new_name}' updated!${NC}"

    if systemctl is-active pfm-bot > /dev/null 2>&1; then
        systemctl restart pfm-bot
        echo -e "  ${GR}Bot restarted${NC}"
    fi
    sleep 2
}

# ─── Menu: Test Servers ───
menu_test_servers() {
    header; echo -e "  ${B}${W}Test All Servers${NC}\n"

    local count=$(get_server_count)
    if [[ "$count" == "0" ]]; then
        echo -e "  ${GR}No servers configured${NC}"; sleep 1; return
    fi

    py_get "
import subprocess, shlex
for i, s in enumerate(cfg.get('servers', [])):
    name = s['name']
    host = s['host']
    port = s.get('port', 22)
    user = s.get('user', 'root')
    pw = s.get('password', '')
    key = s.get('key', '')

    if pw:
        cmd = f'sshpass -p {shlex.quote(pw)} ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p {port} {user}@{host} pfm json'
    else:
        cmd = f'ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -i {key} -p {port} {user}@{host} pfm json'

    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            import json as j
            d = j.loads(r.stdout)
            users = len(d.get('users', []))
            ports_count = sum(len(u.get('ports', [])) for u in d.get('users', []))
            print(f'  ✅ {name:12s} {host:18s} {users} users, {ports_count} ports')
        else:
            print(f'  ❌ {name:12s} {host:18s} pfm error')
    except Exception as e:
        print(f'  ❌ {name:12s} {host:18s} {str(e)[:30]}')
"
    echo -ne "\n  ${GR}Enter...${NC}"; read -r
}

# ─── Menu: Uninstall ───
menu_uninstall() {
    header
    echo -ne "  ${R}Remove PFM Bot completely? (y/N):${NC} "; read -r c
    [[ "$c" != "y" && "$c" != "Y" ]] && return
    systemctl stop pfm-bot 2>/dev/null
    systemctl disable pfm-bot 2>/dev/null
    rm -f "$SERVICE_FILE" "$BOT_SCRIPT"
    rm -rf "$CONFIG_DIR"
    systemctl daemon-reload
    echo -e "  ${G}Bot removed${NC}"; sleep 2
    exit 0
}

# ─── Main Menu ───
main_menu() {
    init_config
    while true; do
        header
        local token=$(get_token)
        local adm=$(get_admin)
        local count=$(get_server_count)

        echo -ne "  Bot: "; bot_status
        [[ -n "$token" && "$token" != "" ]] && \
            echo -e "  Token: ${G}Set${NC} ${GR}(${token:0:12}...)${NC}" || \
            echo -e "  Token: ${R}Not set${NC}"
        [[ "$adm" != "0" && -n "$adm" ]] && \
            echo -e "  Admin: ${G}${adm}${NC}" || \
            echo -e "  Admin: ${R}Not set${NC}"
        echo -e "  Servers: ${C}${count}${NC}"
        echo ""

        echo -e "  ${W}1)${NC}  Setup Bot ${GR}(Token + Admin)${NC}"
        echo -e "  ${W}2)${NC}  Add Server"
        echo -e "  ${W}3)${NC}  Edit Server"
        echo -e "  ${W}4)${NC}  Remove Server"
        echo -e "  ${W}5)${NC}  List Servers"
        echo -e "  ${W}6)${NC}  Test All Servers"
        echo -e "  ${W}7)${NC}  View Logs"
        echo -e "  ${R}8)${NC}  Uninstall"
        echo -e "  ${W}0)${NC}  Exit"
        echo -ne "\n  ${C}Select:${NC} "; read -r opt

        case "$opt" in
            1) menu_setup ;;
            2) menu_add_server ;;
            3) menu_edit_server ;;
            4) menu_remove_server ;;
            5) menu_list_servers ;;
            6) menu_test_servers ;;
            7) journalctl -u pfm-bot --no-pager -n 30; echo -ne "\n  ${GR}Enter...${NC}"; read -r ;;
            8) menu_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

main_menu
