<div align="center">

# 🍅 FreshTomato Theme Collection

**A collection of custom UI themes for FreshTomato firmware with mp4 video and audio background support**

![GitHub repo size](https://img.shields.io/github/repo-size/Lucrumae/Fresh-Tomato-Theme?style=flat-square&color=ff4d8d)
![GitHub stars](https://img.shields.io/github/stars/Lucrumae/Fresh-Tomato-Theme?style=flat-square&color=7ec8e3)
![License](https://img.shields.io/badge/license-MIT-pink?style=flat-square)

</div>

---

## ✨ Themes Preview 
>*Just ignore the CPU temperature. My device does have a problem with the cooling system.*

### ⬜ Material White

![Material White Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme/MaterialWhite/preview.png)

---

### ⬛ Material Black

![Material Black Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme/MaterialBlack/preview.png)

---

### 🐈 Sleeping Cat

![Sleeping Cat Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme/SleepingCat/preview.png)

---

### 🎸 Bocchi The Rock

![Bocchi The Rock Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/Theme/BocchiTheRock/preview.png)

---
### 🦎 Adaptive Theme

>Adaptive Theme is a theme that adjusts the panel colors according to the custom bgmp4.gif you have uploaded.
>
>Adaptive Realtime is a theme that adjusts the panel color according to the background of the video that being played in real time.

---

## 🚀 Installation

> **Requirements:** FreshTomato firmware with JFFS partition enabled
> *(Administration → JFFS → Enable).*
> *Format & Load JFSS if Mount Failed.*

>Do not use the default terminal system on the Fresh Tomato 192.168.1.1 web. Use the SSH terminal in PuTTY for Windows or Termius for Android.

Paste this single command into your router's SSH terminal:

```sh
wget -O - https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/install | sh
```

The installer will:
1. Fetch the latest theme catalog from this repository
2. Show you a list of available themes to choose from
3. Mirror the system `/www` to JFFS for persistence
4. Download and extract your chosen theme
5. Inject the video background script into all pages
6. Mount and activate — no reboot needed

After installation, press **Ctrl + F5** in your browser to clear the cache.

>If the theme hasn't changed, try going to "administration → admin access" and Ensure that the Theme UI is in Default Theme, then click Save without changing anything.

Didn't work? Then try rebooting and make sure your browser cache has been cleared.

---

## 🔇 How do I turn on the mp4 background sound?

To activate the sound, slide the cursor to the bottom right and the button to activate the sound will appear along with the hide panel button.

What if I'm using a mobile phone? Tap the bottom right corner of the screen on the web and the button will appear.

>Still no sound? That means bgmp4.gif in the theme you selected has no sound.

---

## 🎬 How to Add a Custom MP4 Background

FreshTomato's built-in web server (BusyBox httpd) does not support serving `.mp4` files directly because it has no MIME type for video. The workaround is to **rename your MP4 file to `.gif`** — the browser will still play it correctly as long as the correct MIME type is declared in the HTML.

### Step 1 — Prepare your video file

Rename your MP4 video to bgmp4.gif before uploading to the router. Recommended specs:
- **Format:** MP4
- **Resolution:** 1920x1080 
- **File size:** under 15MB for smooth loading
- **Filename:** `bgmp4.gif` *(must use this name)*
  
It is recommended to use the original 1920x1080p MP4 video file without compression because compressed videos, such as those from 4k to 1080p, cause heavy page loading and poor performance.

### Step 2 — Upload to the router via SCP

From your PC, run:
```sh
scp bgmp4.gif root@192.168.1.1:/jffs/mywww/bgmp4.gif
```

Or copy directly if you already have SSH access to the router:
```sh
cp /path/to/your/video.mp4 /jffs/mywww/bgmp4.gif
```

### Step 3 — Verify the file is in place

```sh
ls -lh /jffs/mywww/bgmp4.gif
```

### Step 4 — Restart the web server

```sh
service httpd restart
```

Then press **Ctrl + F5** in your browser. Your video should now play as the background.

> **How it works:** The installer injects `bg-video.js` into `tomato.js`, which runs on every page. This script creates a `<video>` element with `type="video/mp4"` pointing to `bgmp4.gif` — the browser reads the MIME type from the tag, not the file extension, so it plays correctly.

---

## 🗑️ Uninstall / Revert to Default

Paste this single command into your router's SSH terminal to fully remove the theme:

```sh
umount -l /www && rm -rf /jffs/mywww && nvram set script_init="$(nvram get script_init | awk '/# --- Theme Startup ---/{found=1} !found{print}')" && nvram commit && service httpd restart
```

This will in order: unmount the theme, delete all theme files from JFFS, remove the boot hook from NVRAM, save NVRAM, and restart the web server. After running, press **Ctrl + F5** in your browser to confirm the default UI is restored. ✅

---

## 🛠️ Compatibility

| Firmware | Status |
|----------|--------|
| FreshTomato ARM | ✅ Tested |
| FreshTomato MIPS | ⚠️ Untested |

I don't know if it works on other devices, but it should be universal. The thing is, I only have one device to test it on.

Tested on: **Cisco Linksys EA6300v1/EA6400** (ARMv7, FreshTomato 2026.1)

---

<div align="center">

Personal Project For My Fresh Tomato Linksys EA6300v1/EA6400
</div>
