<div align="center">

# 🍅 FreshTomato Theme Collection

**Custom UI themes for FreshTomato firmware — video background, adaptive colors, and audio support**

![GitHub repo size](https://img.shields.io/github/repo-size/Lucrumae/Fresh-Tomato-Theme?style=flat-square&color=ff4d8d)
![GitHub stars](https://img.shields.io/github/stars/Lucrumae/Fresh-Tomato-Theme?style=flat-square&color=7ec8e3)
![License](https://img.shields.io/badge/license-MIT-pink?style=flat-square)

</div>

---

## ✨ Themes Preview
> *Just ignore the CPU temperature. My device does have a problem with the cooling system.*

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

### 🎨 Adaptive & Adaptive Realtime

**Adaptive** reads the colors from your uploaded `bgmp4.gif` on load and applies them to the panel UI.

**Adaptive Realtime** continuously samples the video frame-by-frame and shifts panel colors in real time as the video plays.

---

## 🚀 Installation

> **Requirements:** FreshTomato firmware with JFFS partition enabled
> *(Administration → JFFS → Enable)*
> *Format & Load JFFS if mount fails.*
>
> Use SSH terminal — **PuTTY** on Windows, **Termius** on Android. Do not use the browser terminal on the router web UI.

```sh
wget -O - https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/install.sh | sh
```

After installation, press **Ctrl + F5** to clear browser cache.

> If the theme hasn't changed, go to **Administration → Admin Access**, make sure the Theme UI is set to **Default Theme**, and click **Save**. If it still doesn't work, reboot and clear browser cache.

---

## 🔑 Custom Login Page

The installer replaces the default router login with a custom page featuring the video background and adaptive colors. On your **first visit**, a tooltip guides you to the mute button in the bottom-right corner. On your **first login**, a tooltip introduces the hide panel button.

Credentials are synced across the web login, router admin, and SSH automatically.

---

## 🔇 Background Audio

Slide or tap the **bottom-right corner** of any page to reveal the mute/unmute button.

> No sound? The `bgmp4.gif` in the selected theme has no audio track.

---

## 🎬 Custom MP4 Background

Rename your MP4 file to `bgmp4.gif` and upload it to the router:

```sh
scp bgmp4.gif root@192.168.1.1:/jffs/mywww/bgmp4.gif
```

Then press **Ctrl + F5**. Recommended: 1080p, under 15MB, uncompressed.

> **Why `.gif`?** BusyBox httpd has no MIME type for `.mp4`. Renaming to `.gif` bypasses this — the browser plays it correctly because the MIME type is declared in the HTML, not read from the file extension.

---

## 🗑️ Uninstall

```sh
wget -O - https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/uninstall.sh | sh
```

The uninstaller will walk you through the process interactively, including an option to reset credentials back to the default `root` / `admin`. Press **Ctrl + F5** after to confirm the default UI is restored.

---

## 🛠️ Compatibility

| Firmware | Status |
|---|---|
| FreshTomato ARM | ✅ Tested |
| FreshTomato MIPS | ⚠️ Untested |

Tested on: **Cisco Linksys EA6300v1 / EA6400** (ARMv7, FreshTomato 2026.1)

---

<div align="center">

Personal project for my FreshTomato Linksys EA6300v1/EA6400

</div>
