# Mac Setup — MVS/Verizon Device Testing Environment

One-script setup to mirror a Windows PC testing environment onto a Mac.
Built for Verizon MVS (com.verizon.mips.services) device testing on Motorola phones (Qualcomm + MediaTek).

## Quick Start

On your Mac, open Terminal and run:

```bash
curl -o ~/mac-setup.sh https://raw.githubusercontent.com/saiboyapati02-ops/mac-setup/main/mac-setup.sh
chmod +x ~/mac-setup.sh
~/mac-setup.sh
```

## What It Installs

| Category | Tools |
|----------|-------|
| **Dev Tools** | git, node, python3, java 8, poppler, 7zip, gh |
| **IDEs** | Android Studio, IntelliJ IDEA CE, PyCharm CE, JetBrains Toolbox |
| **Browsers** | Chrome, Firefox (+ Safari built-in) |
| **AI Tools** | Claude Desktop, ChatGPT, claude-code CLI |
| **Android** | SDK API 35+36, build-tools 34-36, ADB, fastboot, emulator, AVD |
| **Testing** | 40+ MVS aliases, AVS WiFi test script, device-status, vzw-versions |
| **Utilities** | AnyDesk, Vysor, pm2 |
| **Office** | Microsoft 365, Teams |
| **Python** | openpyxl, pandas, PyPDF2, pdfplumber |

## macOS Driver Note

macOS does **NOT** need Motorola, Qualcomm, or MediaTek USB drivers (unlike Windows).
Just enable USB Debugging on the phone and trust the Mac when prompted.

## Re-running

The script is idempotent — safe to run again. It skips anything already installed.
