<div align="center">

# 🍅 FreshTomato Theme Collection

**A collection of custom anime-themed UI themes for FreshTomato router firmware,
complete with a one-line installer.**

![GitHub repo size](https://img.shields.io/github/repo-size/Lucrumae/Fresh-Tomato-Theme?style=flat-square&color=ff4d8d)
![GitHub stars](https://img.shields.io/github/stars/Lucrumae/Fresh-Tomato-Theme?style=flat-square&color=7ec8e3)
![License](https://img.shields.io/badge/license-MIT-pink?style=flat-square)

</div>

---

## ✨ Themes

### 🎸 Bocchi The Rock

![Bocchi The Rock Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/BocchiTheRockTheme/preview.png)

---

### 🌊 Aemeath — Wuthering Waves

![Aemeath Wuthering Waves Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/AemeathWutheringWavesTheme/preview.png)

---

## 🚀 Installation

> **Requirements:** FreshTomato firmware with JFFS partition enabled.
> *(Administration → JFFS2 → Enable)*

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

---

## 🎬 How to Add a Custom MP4 Background

FreshTomato's built-in web server (BusyBox httpd) does not support serving `.mp4` files directly because it has no MIME type for video. The workaround is to **rename your MP4 file to `.gif`** — the browser will still play it correctly as long as the correct MIME type is declared in the HTML.

### Step 1 — Prepare your video file

Compress and rename your video before uploading to the router. Recommended specs:
- **Format:** MP4 (H.264)
- **Resolution:** 1920x1080 or lower
- **File size:** under 15MB for smooth loading
- **Filename:** `bgmp4.gif` *(must use this name)*

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

Tested on: **Cisco Linksys EA6400** (ARMv7, FreshTomato 2026.1)

---

## 👤 Credits

| Role | Name |
|------|------|
| Theme author & installer | [Lucrumae](https://github.com/Lucrumae) |
| Firmware | [FreshTomato](https://freshtomato.org) |
| Bocchi The Rock | © Aki Hamaji / Aniplex |
| Wuthering Waves — Aemeath | © Kuro Games |

---

<div align="center">

Made with ❤️ and too many page refresh.

</div>
