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
> Pink & dark industrial aesthetic inspired by the anime *Bocchi the Rock!*

![Bocchi The Rock Theme](https://raw.githubusercontent.com/Lucrumae/Fresh-Tomato-Theme/main/BocchiTheRockTheme/preview.png)

---

### 🌊 Aemeath — Wuthering Waves
> Deep dark theme featuring Aemeath from *Wuthering Waves*, with animated CPU usage bar.

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
5. Mount and activate it — no reboot needed

After installation, press **Ctrl + F5** in your browser to clear the cache.

---

## 🗑️ Uninstall / Revert to Default

Paste this single command into your router's SSH terminal to fully remove the theme:

```sh
umount -l /www && rm -rf /jffs/mywww && nvram set script_init="$(nvram get script_init | sed '/# --- Theme Startup ---/,/fi/d')" && nvram commit && service httpd restart
```

This will in order: unmount the theme, delete all theme files from JFFS, remove the boot hook from NVRAM, save NVRAM, and restart the web server. After running, press **Ctrl + F5** in your browser to confirm the default UI is restored. ✅

---

## 🗂️ Adding a New Theme

Want to contribute your own theme? Follow these steps:

**1. Create a folder** in the root of this repository:
```
YourThemeName/
├── Theme.tar        ← all theme files packed inside
└── preview.png      ← screenshot for the README (recommended: 1280x720)
```

**2. Pack your theme files** into `Theme.tar`:
```sh
# From inside your theme folder
tar -cf Theme.tar bg.gif default.css logol.png logor.png
```

The tar archive should contain at minimum:

| File | Description |
|------|-------------|
| `default.css` | Main stylesheet for the theme |
| `bg.gif` / `bg.png` | Background image or animation |
| `logol.png` | Left header logo |
| `logor.png` | Right header logo |

**3. Register your theme** by adding a line to `ThemeList.txt`:
```
Theme Display Name|YourThemeFolderName
```

Example:
```
Bocchi The Rock|BocchiTheRockTheme
Aemeath Wuthering Waves|AemeathWutheringWavesTheme
Your Theme Name|YourThemeName
```

**4. Submit a Pull Request** and your theme will be available to everyone via the installer!

---

## 🛠️ Compatibility

| Firmware | Status |
|----------|--------|
| FreshTomato ARM | ✅ Tested |
| FreshTomato MIPS | ⚠️ Untested |
| DD-WRT / OpenWrt | ❌ Not supported |

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
