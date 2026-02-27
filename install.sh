#!/bin/sh

# =================================================================
# GLOBAL CONFIGURATION
# =================================================================
BASE_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main"
THEME_URL="https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme"
LIST_FILE="ThemeList.txt"
INSTALL_PATH="/jffs/mywww"
NGINX_PATH="/jffs/nginx"
TEMP_WORKSPACE="/tmp/theme_deploy"
THEME_FILES="default.css logol.png logor.png bgmp4.gif"

# ANSI Colors
CYAN='\033[0;36m'; BGREEN='\033[1;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; PINK='\033[1;35m'; WHITE='\033[1;37m'
DIM='\033[2m'; NC='\033[0m'

cleanup() { [ -d "$TEMP_WORKSPACE" ] && rm -rf "$TEMP_WORKSPACE"; }
trap cleanup EXIT INT TERM

divider() { echo -e "${DIM}  ────────────────────────────────────────────────${NC}"; }
ok()   { echo -e "  ${BGREEN}✔${NC}  $1"; }
fail() { echo -e "  ${RED}✘${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
do_wget() { wget --no-check-certificate -T 15 "$1" -O "$2" 2>/dev/null; }

# =================================================================
# PHASE 1: THEME SELECTION
# =================================================================
clear
echo ""
echo -e "${PINK}  ████████╗██╗  ██╗███████╗███╗   ███╗███████╗${NC}"
echo -e "${PINK}     ██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝${NC}"
echo -e "${PINK}     ██║   ███████║█████╗  ██╔████╔██║█████╗  ${NC}"
echo -e "${PINK}     ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝  ${NC}"
echo -e "${PINK}     ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗${NC}"
echo -e "${PINK}     ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝${NC}"
echo ""
echo -e "${WHITE}        FreshTomato Theme Installer${NC}  ${DIM}by Lucrumae${NC}"
divider; echo ""

mkdir -p "$TEMP_WORKSPACE"
echo -ne "  ${CYAN}↓${NC}  Fetching theme catalog... "
do_wget "$BASE_URL/$LIST_FILE" "$TEMP_WORKSPACE/list.txt"
[ ! -s "$TEMP_WORKSPACE/list.txt" ] && echo -e "${RED}failed${NC}" && fail "Cannot reach GitHub." && exit 1
echo -e "${BGREEN}done${NC}"; echo ""

echo -e "  ${WHITE}Available Themes${NC}"; divider
i=1
while IFS='|' read -r name folder || [ -n "$name" ]; do
    n=$(echo "$name" | tr -d '\r\n'); f=$(echo "$folder" | tr -d '\r\n')
    [ -z "$n" ] && continue
    echo -e "  ${PINK}$i)${NC}  $n  ${DIM}← $f${NC}"
    echo "$n" >> "$TEMP_WORKSPACE/names.txt"
    echo "$f" >> "$TEMP_WORKSPACE/folders.txt"
    i=$((i+1))
done < "$TEMP_WORKSPACE/list.txt"
total=$((i-1))
[ "$total" -eq 0 ] && fail "No themes found." && exit 1

divider; echo ""
printf "  Select a theme (1-$total): "
read choice < /dev/tty
case "$choice" in ''|*[!0-9]*) fail "Invalid input."; exit 1 ;; esac
[ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] && fail "Out of range." && exit 1

SELECTED_NAME=$(sed -n "${choice}p" "$TEMP_WORKSPACE/names.txt")
SELECTED_FOLDER=$(sed -n "${choice}p" "$TEMP_WORKSPACE/folders.txt")
THEME_BASE_URL="$THEME_URL/$SELECTED_FOLDER"

# =================================================================
# PHASE 2: SYSTEM CHECKS
# =================================================================
echo ""; echo -e "  ${WHITE}System Checks${NC}"; divider
! mount | grep -q "/jffs" && fail "JFFS not mounted." && exit 1
ok "JFFS partition active"
FREE=$(df -k /jffs | awk 'NR==2{print $4}')
[ "$FREE" -lt 10240 ] && warn "Low JFFS space (${FREE}KB)" || ok "JFFS space OK (${FREE}KB free)"

HAS_NGINX=0
which nginx > /dev/null 2>&1 && {
    ok "nginx available ($(nginx -v 2>&1 | cut -d/ -f2))"
    HAS_NGINX=1
} || warn "nginx not found — Basic Auth fallback"

# Deteksi LAN IP router
LAN_IP=$(nvram get lan_ipaddr 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"
ok "Router LAN IP: $LAN_IP"

echo ""; echo -e "  ${WHITE}Installing:${NC} ${PINK}$SELECTED_NAME${NC}"; divider

# =================================================================
# PHASE 3: PREPARATION
# =================================================================
echo -ne "  ${CYAN}[1/5]${NC}  Checking previous installation...       "
if [ -d "$INSTALL_PATH" ] && [ "$(ls -A $INSTALL_PATH 2>/dev/null)" ]; then
    echo -e "${YELLOW}found${NC}"; echo ""
    warn "Previous installation at ${DIM}$INSTALL_PATH${NC}"; echo ""
    printf "  Overwrite? (y/n): "; read confirm < /dev/tty; echo ""
    case "$confirm" in
        y|Y)
            echo -ne "  ${CYAN}[1/5]${NC}  Removing previous...                    "
            # Stop semua service dulu
            pkill -9 nginx 2>/dev/null; kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
            sleep 1
            umount -l /www 2>/dev/null; sleep 1
            rm -rf "$INSTALL_PATH"
            echo -e "${BGREEN}done${NC}" ;;
        *) echo -e "  ${CYAN}→${NC}  Cancelled."; exit 0 ;;
    esac
else
    echo -e "${BGREEN}clean${NC}"
    pkill -9 nginx 2>/dev/null; kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
    sleep 1; umount -l /www 2>/dev/null; sleep 1
fi

echo -ne "  ${CYAN}[2/5]${NC}  Mirroring /www to JFFS...               "
mkdir -p "$INSTALL_PATH"
cp -a /www/. "$INSTALL_PATH/"
rm -f "$INSTALL_PATH/default.css"
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 4: DOWNLOAD
# =================================================================
failed_files=""
echo -e "  ${CYAN}[3/5]${NC}  Downloading theme files..."; echo ""

VIDEO_SCRIPT="bg-video.js"
for TRY_SCRIPT in adaptiverealtime.js adaptive.js; do
    printf "        ${DIM}%-22s${NC} " "$TRY_SCRIPT"
    do_wget "$THEME_BASE_URL/$TRY_SCRIPT" "$INSTALL_PATH/$TRY_SCRIPT"
    if [ $? -eq 0 ] && [ -s "$INSTALL_PATH/$TRY_SCRIPT" ]; then
        SIZE=$(ls -lh "$INSTALL_PATH/$TRY_SCRIPT" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
        VIDEO_SCRIPT="$TRY_SCRIPT"; break
    else
        rm -f "$INSTALL_PATH/$TRY_SCRIPT" 2>/dev/null
        echo -e "${DIM}skipped${NC}"
    fi
done

if [ "$VIDEO_SCRIPT" = "bg-video.js" ]; then
    printf "        ${DIM}%-22s${NC} " "bg-video.js"
    do_wget "$BASE_URL/bg-video.js" "$INSTALL_PATH/bg-video.js"
    if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/bg-video.js" ]; then
        echo -e "${RED}failed${NC}"; fail "Cannot download bg-video.js."; exit 1
    fi
    SIZE=$(ls -lh "$INSTALL_PATH/bg-video.js" | awk '{print $5}')
    echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
fi

for FILE in $THEME_FILES; do
    printf "        ${DIM}%-22s${NC} " "$FILE"
    do_wget "$THEME_BASE_URL/$FILE" "$INSTALL_PATH/$FILE"
    if [ $? -ne 0 ] || [ ! -s "$INSTALL_PATH/$FILE" ]; then
        case "$FILE" in logol.png|logor.png|bgmp4.gif) echo -e "${DIM}skipped${NC} ${DIM}(optional)${NC}" ;;
            *) echo -e "${RED}failed${NC}"; failed_files="$failed_files $FILE" ;; esac
    else
        SIZE=$(ls -lh "$INSTALL_PATH/$FILE" | awk '{print $5}')
        echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
    fi
done

# login.html — embed langsung, tidak pull dari GitHub
printf "        ${DIM}%-22s${NC} " "login.html"
mkdir -p "$NGINX_PATH/static"
cat > "$INSTALL_PATH/login.html" << 'LOGINEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FreshTomato — Login</title>
<script>
(function(){
  function getCookie(n){
    var m=document.cookie.match('(?:^|; )'+n+'=([^;]*)');
    return m?m[1]:'';
  }
  var p=new URLSearchParams(window.location.search);
  if(p.get('logout')==='1'){
    document.cookie='ft_auth=; Path=/; Max-Age=0; SameSite=Lax';
    history.replaceState(null,'','/login.html');
  } else if(getCookie('ft_auth')){
    window.location.replace('/index.asp');
  }
})();
</script>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@200;300;400;600;700&family=Space+Mono:wght@400;700&display=swap');
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
  :root{
    --panel-bg:rgba(8,6,10,0.40);
    --panel-edge:rgba(255,255,255,0.10);
    --text-main:#f0ece8;
    --text-dim:rgba(240,236,232,0.50);
    --accent:#e8a86e;
    --accent2:#7ec8e3;
    --error:#ff6b6b;
    --tr:0.22s;
  }
  html,body{width:100%;height:100%;overflow:hidden;font-family:'Outfit',sans-serif;background:#080610;}
  #bg-video{position:fixed;inset:0;width:100vw;height:100vh;object-fit:cover;object-position:center;z-index:0;pointer-events:none;}
  #bg-overlay{position:fixed;inset:0;z-index:1;background:rgba(8,6,10,0.38);transition:background 1.2s ease;pointer-events:none;}
  .stage{position:relative;z-index:2;width:100%;height:100%;display:flex;align-items:center;justify-content:center;}
  .card{width:min(400px,90vw);background:var(--panel-bg);border:1px solid var(--panel-edge);border-radius:18px;padding:40px 36px 36px;backdrop-filter:blur(20px) saturate(1.5);-webkit-backdrop-filter:blur(20px) saturate(1.5);box-shadow:0 8px 48px rgba(0,0,0,0.6),0 1px 0 rgba(255,255,255,0.06) inset;animation:cardIn 0.5s cubic-bezier(0.22,1,0.36,1) both;transition:background 1.2s ease,border-color 1.2s ease;}
  @keyframes cardIn{from{opacity:0;transform:translateY(24px) scale(0.97);}to{opacity:1;transform:translateY(0) scale(1);}}
  .card-header{text-align:center;margin-bottom:32px;}
  .logo-row{display:flex;align-items:center;justify-content:center;gap:10px;margin-bottom:6px;}
  .logo-icon svg{width:32px;height:32px;}
  .logo-text{font-size:22px;font-weight:700;letter-spacing:-0.02em;color:var(--text-main);transition:color 1.2s;}
  .logo-text span{color:var(--accent);transition:color 1.2s;}
  .card-subtitle{font-size:11px;font-weight:300;letter-spacing:0.14em;text-transform:uppercase;color:var(--text-dim);font-family:'Space Mono',monospace;transition:color 1.2s;}
  .divider{height:1px;background:linear-gradient(90deg,transparent,var(--panel-edge),transparent);margin-bottom:28px;transition:background 1.2s;}
  .field{margin-bottom:16px;}
  .field label{display:block;font-size:11px;font-weight:600;letter-spacing:0.10em;text-transform:uppercase;color:var(--text-dim);margin-bottom:7px;font-family:'Space Mono',monospace;transition:color 1.2s;}
  .field-wrap{position:relative;display:flex;align-items:center;}
  .field-icon{position:absolute;left:13px;display:flex;align-items:center;pointer-events:none;opacity:0.4;transition:opacity var(--tr);}
  .field-icon svg{width:15px;height:15px;fill:none;stroke:var(--text-main);stroke-width:2;stroke-linecap:round;stroke-linejoin:round;}
  .field input{width:100%;padding:11px 12px 11px 38px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.10);border-radius:10px;color:var(--text-main);font-size:14px;font-family:'Outfit',sans-serif;outline:none;transition:border-color var(--tr),background var(--tr),box-shadow var(--tr);}
  .field input::placeholder{color:rgba(240,236,232,0.25);}
  .field input:focus{border-color:var(--accent);background:rgba(255,255,255,0.09);box-shadow:0 0 0 3px rgba(232,168,110,0.13);}
  .field-wrap:focus-within .field-icon{opacity:0.85;}
  .eye-btn{position:absolute;right:11px;background:none;border:none;cursor:pointer;padding:4px;color:var(--text-dim);display:flex;align-items:center;opacity:0.45;transition:opacity var(--tr);}
  .eye-btn:hover{opacity:1;}
  .eye-btn svg{width:15px;height:15px;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;}
  .error-msg{display:none;font-size:12px;color:var(--error);margin-top:5px;padding-left:2px;}
  .error-msg.show{display:block;animation:shake 0.35s ease;}
  @keyframes shake{0%,100%{transform:translateX(0);}25%{transform:translateX(-5px);}75%{transform:translateX(5px);}}
  .btn-login{width:100%;margin-top:22px;padding:13px;background:var(--accent);border:none;border-radius:10px;color:#0e0810;font-size:14px;font-weight:700;font-family:'Outfit',sans-serif;letter-spacing:0.04em;cursor:pointer;position:relative;overflow:hidden;transition:background 1.2s,transform var(--tr),box-shadow var(--tr),opacity var(--tr);}
  .btn-login:hover{transform:translateY(-2px);box-shadow:0 6px 24px rgba(232,168,110,0.35);}
  .btn-login:active{transform:translateY(0);box-shadow:none;}
  .btn-login.loading{opacity:0.7;pointer-events:none;}
  .btn-login .btn-text{transition:opacity 0.2s;}
  .btn-login .spinner{display:none;width:16px;height:16px;border:2px solid rgba(14,8,16,0.3);border-top-color:#0e0810;border-radius:50%;animation:spin 0.7s linear infinite;position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);}
  .btn-login.loading .btn-text{opacity:0;}
  .btn-login.loading .spinner{display:block;}
  @keyframes spin{to{transform:translate(-50%,-50%) rotate(360deg);}}
  .card-footer{margin-top:20px;text-align:center;font-size:11px;color:var(--text-dim);font-family:'Space Mono',monospace;letter-spacing:0.04em;}
  .card-footer a{color:var(--accent2);text-decoration:none;opacity:0.75;transition:opacity var(--tr);}
  .card-footer a:hover{opacity:1;}
  #ft-unmute-popup{position:fixed;bottom:24px;left:50%;transform:translateX(-50%);z-index:9999;background:rgba(10,10,10,0.82);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);color:#fff;font-size:13px;font-family:'Outfit',sans-serif;padding:10px 22px;border-radius:24px;box-shadow:0 4px 16px rgba(0,0,0,0.5);cursor:pointer;display:flex;align-items:center;gap:8px;animation:popIn 0.3s ease;}
  @keyframes popIn{from{opacity:0;transform:translateX(-50%) translateY(12px);}to{opacity:1;transform:translateX(-50%) translateY(0);}}
  .pop-out{animation:popOut 0.3s ease forwards!important;}
  @keyframes popOut{from{opacity:1;transform:translateX(-50%) translateY(0);}to{opacity:0;transform:translateX(-50%) translateY(12px);}}
</style>
</head>
<body>
<video id="bg-video" autoplay loop muted playsinline>
  <source src="/bgmp4.gif" type="video/mp4">
</video>
<div id="bg-overlay"></div>
<div class="stage" id="stage" style="visibility:hidden">
  <div class="card" id="card">
    <div class="card-header">
      <div class="logo-row">
        <div class="logo-icon">
          <svg viewBox="0 0 48 48" fill="none">
            <ellipse cx="24" cy="28" rx="18" ry="16" fill="var(--accent)" opacity="0.9"/>
            <ellipse cx="24" cy="28" rx="18" ry="16" fill="url(#tg)" opacity="0.6"/>
            <path d="M24 13C24 13 20 6 14 8C18 8 20 13 24 13Z" fill="#4caf50"/>
            <path d="M24 13C24 13 28 6 34 8C30 8 28 13 24 13Z" fill="#388e3c"/>
            <path d="M24 13C22 8 24 4 24 4C24 4 26 8 24 13Z" fill="#66bb6a"/>
            <defs>
              <linearGradient id="tg" x1="6" y1="14" x2="42" y2="44" gradientUnits="userSpaceOnUse">
                <stop stop-color="#ffb347"/>
                <stop offset="1" stop-color="#c0392b"/>
              </linearGradient>
            </defs>
          </svg>
        </div>
        <div class="logo-text">Fresh<span>Tomato</span></div>
      </div>
      <div class="card-subtitle">Router Administration</div>
    </div>
    <div class="divider"></div>
    <form id="form" autocomplete="on">
      <div class="field">
        <label for="username">Username</label>
        <div class="field-wrap">
          <input id="username" type="text" name="username" placeholder="admin" autocomplete="username" spellcheck="false">
          <span class="field-icon">
            <svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/></svg>
          </span>
        </div>
      </div>
      <div class="field">
        <label for="password">Password</label>
        <div class="field-wrap">
          <input id="password" type="password" name="password" placeholder="••••••••" autocomplete="current-password">
          <span class="field-icon">
            <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          </span>
          <button type="button" class="eye-btn" id="eye-btn">
            <svg id="eye-svg" viewBox="0 0 24 24">
              <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
            </svg>
          </button>
        </div>
        <div class="error-msg" id="err"></div>
      </div>
      <button type="submit" class="btn-login" id="btn">
        <span class="btn-text">Sign In</span>
        <span class="spinner"></span>
      </button>
    </form>
    <div class="card-footer">
      <a href="http://freshtomato.org" target="_blank">FreshTomato</a>
      &nbsp;·&nbsp; Router Admin Panel
    </div>
  </div>
</div>

<script>
(function(){
  'use strict';

  // ── ADAPTIVE COLOR ────────────────────────────────────────
  var vid=document.getElementById('bg-video');
  var overlay=document.getElementById('bg-overlay');
  var card=document.getElementById('card');
  var cv=document.createElement('canvas');
  cv.width=64;cv.height=36;
  var ctx=cv.getContext('2d');
  var lastHue=-1,lastTs=0;

  function H(h,s,l){h/=360;s/=100;l/=100;var q=l<.5?l*(1+s):l+s-l*s,p=2*l-q;function f(t){t<0&&(t+=1);t>1&&(t-=1);return t<1/6?p+(q-p)*6*t:t<.5?q:t<2/3?p+(q-p)*(2/3-t)*6:p;}return[~~(f(h+1/3)*255),~~(f(h)*255),~~(f(h-1/3)*255)];}
  function toHsl(r,g,b){r/=255;g/=255;b/=255;var mx=Math.max(r,g,b),mn=Math.min(r,g,b),h,s,l=(mx+mn)/2;if(mx===mn){h=s=0;}else{var d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);h=mx===r?((g-b)/d+(g<b?6:0))/6:mx===g?((b-r)/d+2)/6:((r-g)/d+4)/6;}return[h*360,s*100,l*100];}

  function adaptLoop(ts){
    if(ts-lastTs>120){lastTs=ts;if(vid.readyState>=2){try{ctx.drawImage(vid,0,0,64,36);var px=ctx.getImageData(0,0,64,36).data,r=0,g=0,b=0,n=0;for(var i=0;i<px.length;i+=4){var br=(px[i]+px[i+1]+px[i+2])/3;if(br<15||br>240)continue;r+=px[i];g+=px[i+1];b+=px[i+2];n++;}if(n){r=~~(r/n);g=~~(g/n);b=~~(b/n);var hsl=toHsl(r,g,b),hue=hsl[0],sat=hsl[1],lum=hsl[2];var d=Math.abs(hue-lastHue);if(d>180)d=360-d;if(lastHue<0||d>=5){lastHue=hue;var dark=lum<50,s2=Math.max(sat,50);var acc=H(hue,Math.max(s2,65),dark?68:42);var acc2=H((hue+40)%360,Math.max(s2,55),dark?72:40);var pan=H(hue,Math.min(s2,40),dark?Math.min(lum+8,20):Math.max(lum-8,80));var ov=Math.max(pan[0]-30,0)+','+Math.max(pan[1]-30,0)+','+Math.max(pan[2]-30,0);overlay.style.background='rgba('+ov+',0.42)';card.style.background='rgba('+pan[0]+','+pan[1]+','+pan[2]+',0.36)';card.style.borderColor='rgba('+acc[0]+','+acc[1]+','+acc[2]+',0.20)';document.documentElement.style.setProperty('--accent','rgb('+acc[0]+','+acc[1]+','+acc[2]+')');document.documentElement.style.setProperty('--accent2','rgb('+acc2[0]+','+acc2[1]+','+acc2[2]+')');document.documentElement.style.setProperty('--panel-edge','rgba('+acc[0]+','+acc[1]+','+acc[2]+',0.20)');document.body.style.background='rgb('+Math.max(pan[0]-45,0)+','+Math.max(pan[1]-45,0)+','+Math.max(pan[2]-45,0)+')';}}}catch(e){}}}
    requestAnimationFrame(adaptLoop);
  }
  vid.muted=true;
  vid.play().catch(function(){});
  requestAnimationFrame(adaptLoop);

  // ── UNMUTE POPUP ──────────────────────────────────────────
  if(localStorage.getItem('ft_bg_muted')==='false'){
    setTimeout(function(){
      var p=document.createElement('div');
      p.id='ft-unmute-popup';
      p.innerHTML='<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5L6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>Click anywhere to unmute';
      function bye(u){p.classList.add('pop-out');setTimeout(function(){p.parentNode&&p.parentNode.removeChild(p);},300);if(u){vid.muted=false;localStorage.setItem('ft_bg_muted','false');}}
      p.addEventListener('click',function(e){e.stopPropagation();bye(true);});
      document.addEventListener('click',function once(){document.removeEventListener('click',once);bye(true);},{once:true});
      setTimeout(function(){bye(false);},5000);
      document.body.appendChild(p);
    },700);
  }

  // ── EYE BUTTON ────────────────────────────────────────────
  var pwdEl=document.getElementById('password');
  var eyeBtn=document.getElementById('eye-btn');
  var eyeSvg=document.getElementById('eye-svg');
  var OPEN='<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>';
  var CLOSED='<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/>';
  eyeBtn.addEventListener('click',function(){var show=pwdEl.type==='password';pwdEl.type=show?'text':'password';eyeSvg.innerHTML=show?CLOSED:OPEN;});

  // ── FORM SUBMIT ───────────────────────────────────────────
  var stage=document.getElementById('stage');
  var form=document.getElementById('form');
  var btn=document.getElementById('btn');
  var errEl=document.getElementById('err');

  stage.style.visibility='visible';

  function showErr(msg){errEl.textContent=msg;errEl.classList.remove('show');void errEl.offsetWidth;errEl.classList.add('show');}

  form.addEventListener('submit',function(e){
    e.preventDefault();
    var user=document.getElementById('username').value.trim();
    var pass=pwdEl.value;
    if(!user||!pass){showErr('Please enter username and password.');return;}

    errEl.classList.remove('show');
    btn.classList.add('loading');

    // Kirim credentials sebagai Basic Auth header via X-Login-Auth
    // nginx akan forward ke httpd:8008 dengan Authorization header
    var creds='Basic '+btoa(unescape(encodeURIComponent(user+':'+pass)));

    fetch('/index.asp',{
      method:'GET',
      headers:{'X-Login-Auth':creds},
      credentials:'omit'
    })
    .then(function(r){
      if(r.ok){
        // Set cookie ft_auth — nginx pakai ini untuk cek session di GET /
        document.cookie='ft_auth='+encodeURIComponent(creds)+'; Path=/; SameSite=Lax';
        window.location.replace('/index.asp');
      } else {
        btn.classList.remove('loading');
        showErr('Invalid username or password.');
        pwdEl.value='';pwdEl.focus();
      }
    })
    .catch(function(){
      btn.classList.remove('loading');
      showErr('Cannot reach router. Check connection.');
    });
  });

  setTimeout(function(){document.getElementById('username').focus();},550);
})();
</script>
</body>
</html>
LOGINEOF
cp "$INSTALL_PATH/login.html" "$NGINX_PATH/static/login.html"
SIZE=$(ls -lh "$INSTALL_PATH/login.html" | awk '{print $5}')
echo -e "${BGREEN}done${NC} ${DIM}($SIZE)${NC}"
echo ""

[ -n "$failed_files" ] && fail "Required files failed:$failed_files" && exit 1

# =================================================================
# PHASE 5: PERMISSIONS
# =================================================================
echo -ne "  ${CYAN}[4/5]${NC}  Setting permissions...                  "
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/* 2>/dev/null
chmod 755 "$INSTALL_PATH"/*.cgi 2>/dev/null
echo -e "${BGREEN}done${NC}"

# =================================================================
# PHASE 6: LOGIN PAGE + NGINX + BOOT HOOK
# =================================================================
echo -ne "  ${CYAN}[5/5]${NC}  Configuring login & boot hooks...       "

# Inject video script ke tomato.js
if [ -f "$INSTALL_PATH/tomato.js" ] && ! grep -q "$VIDEO_SCRIPT" "$INSTALL_PATH/tomato.js"; then
    echo "document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$VIDEO_SCRIPT\";document.head.appendChild(s);});" >> "$INSTALL_PATH/tomato.js"
fi

SAFE_PATH=$(echo "$INSTALL_PATH" | tr -cd 'a-zA-Z0-9/_-')
SAFE_SCRIPT=$(echo "$VIDEO_SCRIPT" | tr -cd 'a-zA-Z0-9/_.-')
SAFE_NGINX=$(echo "$NGINX_PATH" | tr -cd 'a-zA-Z0-9/_-')

# Simpan credentials
HTTP_USER=$(nvram get http_username)
HTTP_PASS=$(nvram get http_passwd)
echo "${HTTP_USER}:${HTTP_PASS}" > "$INSTALL_PATH/.passwd"
chmod 600 "$INSTALL_PATH/.passwd"

# Buat auth.cgi
cat > "$INSTALL_PATH/auth.cgi" << 'AUTHEOF'
#!/bin/sh
printf "Content-Type: text/plain\r\n\r\n"
POST=$(cat)
USER=$(echo "$POST" | sed 's/&/\n/g' | grep '^user=' | cut -d= -f2-)
PASS=$(echo "$POST" | sed 's/&/\n/g' | grep '^pass=' | cut -d= -f2-)
CRED=$(cat /jffs/mywww/.passwd 2>/dev/null || cat /www/.passwd 2>/dev/null)
STORED_U="${CRED%%:*}"
STORED_P="${CRED#*:}"
if [ -n "$USER" ] && [ "$USER" = "$STORED_U" ] && [ "$PASS" = "$STORED_P" ]; then
    TOKEN=$(date +%s)$$
    printf "OK:%s" "$TOKEN"
else
    printf "FAIL"
fi
AUTHEOF
chmod 755 "$INSTALL_PATH/auth.cgi"

# Buat index.html
cat > "$INSTALL_PATH/index.html" << 'IDXEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta http-equiv="refresh" content="0;url=/login.html">
<script>window.location.replace('/login.html');</script>
</head><body></body></html>
IDXEOF

# ── NGINX SETUP ───────────────────────────────────────────────────
if [ "$HAS_NGINX" -eq 1 ] && [ -s "$INSTALL_PATH/login.html" ]; then
    B64=$(echo -n "${HTTP_USER}:${HTTP_PASS}" | openssl base64 | tr -d '\n')

    # Pindahkan httpd ke port 8008
    nvram set http_lanport=8008
    nvram commit >/dev/null 2>&1
    service httpd restart >/dev/null 2>&1
    sleep 2

    # Buat dirs
    mkdir -p "$NGINX_PATH/static"
    mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy

    # Salin static files ke nginx/static (TANPA .asp)
    cp "$INSTALL_PATH"/*.css  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.js   "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.png  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH"/*.ico  "$NGINX_PATH/static/" 2>/dev/null
    cp "$INSTALL_PATH/login.html" "$NGINX_PATH/static/"
    [ -f "$INSTALL_PATH/bgmp4.gif" ] && cp "$INSTALL_PATH/bgmp4.gif" "$NGINX_PATH/static/"

    # mime.types
    cat > "$NGINX_PATH/mime.types" << 'MIMEEOF'
types {
    text/html                 html htm;
    text/css                  css;
    text/plain                txt;
    application/javascript    js;
    application/json          json;
    image/png                 png;
    image/jpeg                jpg jpeg;
    image/x-icon              ico;
    image/svg+xml             svg;
    image/gif                 gif;
    font/woff                 woff;
    font/woff2                woff2;
}
MIMEEOF

    # nginx.conf — pakai cookie ft_auth untuk cek session
    cat > "$NGINX_PATH/nginx.conf" << NGINXEOF
user nobody;
worker_processes 1;
pid /tmp/nginx.pid;
error_log /tmp/nginx_error.log;

events { worker_connections 128; }

http {
    access_log off;
    include $NGINX_PATH/mime.types;

    proxy_connect_timeout 10s;
    proxy_send_timeout    60s;
    proxy_read_timeout    60s;
    proxy_buffer_size     32k;
    proxy_buffers         8 32k;
    proxy_busy_buffers_size 64k;

    map \$http_x_login_auth \$auth_header {
        default       "Basic $B64";
        "~^Basic .+"  \$http_x_login_auth;
    }

    server {
        listen 80;
        root $NGINX_PATH/static;

        # Logout — FreshTomato pakai logout.asp
        # Hapus cookie ft_auth, redirect ke login
        location ~* logout {
            add_header Set-Cookie "ft_auth=; Path=/; Max-Age=0; SameSite=Lax" always;
            return 302 /login.html?logout=1;
        }

        # Login page — no-cache agar selalu fresh, tidak pernah redirect
        location = /login.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
            add_header Pragma "no-cache" always;
            try_files \$uri =404;
        }

        # Root "/" = Overview di FreshTomato (status-overview.asp)
        # Jika ada cookie ft_auth → proxy ke httpd
        # Jika tidak ada cookie → serve login.html
        location = / {
            set \$do_login "1";
            if (\$cookie_ft_auth) {
                set \$do_login "0";
            }
            if (\$do_login = "1") {
                rewrite ^ /login.html last;
            }
            proxy_pass http://$LAN_IP:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering on;
        }

        # bgmp4.gif sebagai video
        location = /bgmp4.gif {
            types { video/mp4 gif; }
            try_files \$uri =404;
        }

        # Static files dari nginx/static
        location ~* \.(css|js|png|jpg|jpeg|ico|svg|woff|woff2|html)$ {
            try_files \$uri @proxy;
        }

        # Semua lain → proxy ke httpd
        location / {
            proxy_pass http://$LAN_IP:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_buffering on;
        }

        location @proxy {
            proxy_pass http://$LAN_IP:8008;
            proxy_set_header Authorization \$auth_header;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_buffering on;
        }
    }
}
NGINXEOF

    # Bebaskan port 80 — kill semua yang pakai port 80
    PORT80_PID=$(netstat -tlnp 2>/dev/null | grep ':80 ' | awk '{print $7}' | cut -d/ -f1 | head -1)
    if [ -n "$PORT80_PID" ]; then
        kill -9 "$PORT80_PID" 2>/dev/null
        sleep 1
    fi
    # Kill semua nginx instance
    pkill -9 nginx 2>/dev/null
    kill -9 $(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
    rm -f /tmp/nginx.pid 2>/dev/null
    sleep 2

    # Start nginx
    nginx -c "$NGINX_PATH/nginx.conf" -t >/dev/null 2>&1 && nginx -c "$NGINX_PATH/nginx.conf"
    sleep 1

    # Verifikasi nginx jalan di port 80
    if ! netstat -tlnp 2>/dev/null | grep -q ':80 '; then
        # Retry sekali lagi
        sleep 2; nginx -c "$NGINX_PATH/nginx.conf"
    fi

    # Mount dan restart httpd
    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    BOOT_HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
mount | grep -q $SAFE_PATH || mount --bind $SAFE_PATH /www
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$SAFE_SCRIPT\";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
nvram set http_lanport=8008
service httpd restart
sleep 2
mkdir -p /var/log/nginx /var/lib/nginx/client /var/lib/nginx/proxy
PORT80_PID=\$(netstat -tlnp 2>/dev/null | grep ':80 ' | awk '{print \$7}' | cut -d/ -f1 | head -1)
[ -n "\$PORT80_PID" ] && kill -9 "\$PORT80_PID" 2>/dev/null && sleep 1
pkill -9 nginx 2>/dev/null
kill -9 \$(cat /tmp/nginx.pid 2>/dev/null) 2>/dev/null
rm -f /tmp/nginx.pid 2>/dev/null
sleep 2
nginx -c $SAFE_NGINX/nginx.conf
# --- End Theme Startup ---"

    LOGIN_STATUS="${BGREEN}Custom login page (nginx)${NC}"

else
    # Fallback tanpa nginx
    mount --bind "$INSTALL_PATH" /www
    service httpd restart >/dev/null 2>&1

    BOOT_HOOK="# --- Theme Startup ---
sleep 10
[ -d $SAFE_PATH ] || exit 0
mount | grep -q $SAFE_PATH || { mount --bind $SAFE_PATH /www && service httpd restart; }
grep -q $SAFE_SCRIPT $SAFE_PATH/tomato.js 2>/dev/null || echo 'document.addEventListener(\"DOMContentLoaded\",function(){var s=document.createElement(\"script\");s.src=\"/$SAFE_SCRIPT\";document.head.appendChild(s);});' >> $SAFE_PATH/tomato.js
# --- End Theme Startup ---"

    LOGIN_STATUS="${YELLOW}Basic Auth (nginx unavailable)${NC}"
fi

# Simpan boot hook
CLEAN=$(nvram get script_init | awk '/# --- Theme Startup ---/{f=1} f{next} {print} /# --- End Theme Startup ---/{f=0}')
if [ -n "$(nvram get script_init)" ]; then
    nvram set script_init="$CLEAN
$BOOT_HOOK"
else
    nvram set script_init="$BOOT_HOOK"
fi
nvram commit >/dev/null 2>&1

echo -e "${BGREEN}done${NC}"

# =================================================================
# DONE
# =================================================================
echo ""; divider; echo ""
echo -e "  ${BGREEN}✔  Installation complete!${NC}"; echo ""
echo -e "  ${WHITE}Theme   ${NC}${PINK}$SELECTED_NAME${NC}"
echo -e "  ${WHITE}Path    ${NC}${DIM}$INSTALL_PATH${NC}"
echo -e "  ${WHITE}Script  ${NC}${DIM}$VIDEO_SCRIPT${NC}"
echo -e "  ${WHITE}Login   ${NC}$LOGIN_STATUS"
echo -e "  ${WHITE}Status  ${NC}${BGREEN}Active & persistent${NC}"
echo ""
echo -e "  ${YELLOW}⚑  Press Ctrl+F5 to clear browser cache.${NC}"
echo ""; divider; echo ""
