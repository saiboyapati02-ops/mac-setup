#!/bin/bash
# =============================================================
# Mac Setup Script for Sai Boyapati
# Mirrors Windows PC config for MVS/Verizon device testing
# Run: chmod +x mac-setup.sh && ./mac-setup.sh
# =============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

# ---------------------------
# 1. Homebrew
# ---------------------------
if ! command -v brew &>/dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon Macs
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  fi
else
  log "Homebrew already installed"
fi

brew update

# ---------------------------
# 2. Core Dev Tools
# ---------------------------
log "Installing core dev tools..."

FORMULAS=(
  git
  node
  python@3
  poppler
  7zip
  gh
)

for formula in "${FORMULAS[@]}"; do
  if brew list "$formula" &>/dev/null; then
    warn "$formula already installed, skipping"
  else
    log "Installing $formula..."
    brew install "$formula"
  fi
done

# ---------------------------
# 2b. Java 8 (Temurin - arm64 compatible)
# ---------------------------
# Note: openjdk@8 has no Apple Silicon build, so we use Eclipse Temurin 8
# which works on both Intel and Apple Silicon Macs.
log "Installing Java 8 (Eclipse Temurin)..."
if ! brew list --cask temurin@8 &>/dev/null 2>&1 && ! /usr/libexec/java_home -v 1.8 &>/dev/null; then
  log "Installing Temurin 8..."
  brew install --cask temurin@8 || warn "Temurin 8 install failed - try: brew install --cask temurin@8"
else
  warn "Java 8 already installed"
fi

# Python packages for utility scripts (read_excel, read_pdfs equivalents)
log "Installing Python packages for testing utilities..."
pip3 install --user openpyxl pandas PyPDF2 pdfplumber 2>/dev/null || warn "Some Python packages failed"

# ---------------------------
# 3. GUI Apps (Casks)
# ---------------------------
log "Installing GUI applications..."

CASKS=(
  # IDEs
  android-studio
  intellij-idea-ce
  pycharm-ce
  jetbrains-toolbox

  # Browsers
  google-chrome
  firefox

  # AI Tools
  claude
  chatgpt

  # Android
  android-platform-tools

  # Utilities
  anydesk
  vysor

  # Office
  microsoft-office
  microsoft-teams
)

for cask in "${CASKS[@]}"; do
  if brew list --cask "$cask" &>/dev/null; then
    warn "$cask already installed, skipping"
  else
    log "Installing $cask..."
    brew install --cask "$cask" || warn "Failed to install $cask, skipping"
  fi
done

# ---------------------------
# 4. Android SDK & ADB Setup
# ---------------------------
log "Setting up Android SDK, ADB, and debugging tools..."

ANDROID_SDK="$HOME/Library/Android/sdk"
SDKMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"

if [[ ! -d "$ANDROID_SDK" ]]; then
  mkdir -p "$ANDROID_SDK"
  log "Created Android SDK directory at $ANDROID_SDK"
fi

# Install cmdline-tools if missing
if [[ ! -f "$SDKMANAGER" ]]; then
  log "Installing Android command-line tools..."
  CMDLINE_ZIP="commandlinetools-mac-latest.zip"
  curl -o "/tmp/$CMDLINE_ZIP" "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
  mkdir -p "$ANDROID_SDK/cmdline-tools"
  unzip -qo "/tmp/$CMDLINE_ZIP" -d "$ANDROID_SDK/cmdline-tools"
  mv "$ANDROID_SDK/cmdline-tools/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest" 2>/dev/null || true
  rm -f "/tmp/$CMDLINE_ZIP"
  log "Command-line tools installed"
fi

# Accept all licenses and install SDK packages
if [[ -f "$SDKMANAGER" ]]; then
  log "Accepting Android SDK licenses..."
  yes | "$SDKMANAGER" --licenses > /dev/null 2>&1 || true

  log "Installing Android SDK packages (matching your Windows config)..."
  "$SDKMANAGER" \
    "platforms;android-35" \
    "platforms;android-36" \
    "build-tools;34.0.0" \
    "build-tools;35.0.0" \
    "build-tools;36.0.0" \
    "platform-tools" \
    "emulator" \
    "system-images;android-36;google_apis;arm64-v8a" \
    2>/dev/null || warn "Some SDK packages may need manual install via Android Studio"
  log "SDK packages installed"

  # Create a default AVD
  AVDMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager"
  if [[ -f "$AVDMANAGER" ]]; then
    if ! "$AVDMANAGER" list avd 2>/dev/null | grep -q "Pixel_7_API_36"; then
      log "Creating default AVD: Pixel_7_API_36..."
      echo "no" | "$AVDMANAGER" create avd \
        -n "Pixel_7_API_36" \
        -k "system-images;android-36;google_apis;arm64-v8a" \
        -d "pixel_7" \
        --force 2>/dev/null || warn "AVD creation needs manual setup in Android Studio"
      log "AVD 'Pixel_7_API_36' created"
    else
      warn "AVD Pixel_7_API_36 already exists"
    fi
  fi
else
  warn "sdkmanager not found - install SDK packages via Android Studio > SDK Manager"
fi

# ---------------------------
# 4b. ADB & USB Debugging Config
# ---------------------------
log "Configuring ADB and USB debugging..."

mkdir -p ~/.android

# ADB vendor IDs — Motorola (primary), Qualcomm, MediaTek, and others
ADB_USB_INI=~/.android/adb_usb.ini
if [[ ! -f "$ADB_USB_INI" ]]; then
  cat > "$ADB_USB_INI" << 'ADBVENDORS'
# USB vendor IDs for ADB device detection
# Motorola (primary test devices)
0x22b8
# Qualcomm (Motorola QCOM chipset devices — fastboot/EDL)
0x05c6
# MediaTek (Motorola MTK chipset devices — SP Flash)
0x0e8d
# Google/Pixel
0x18d1
# Samsung
0x04e8
# OnePlus
0x2a70
# Xiaomi
0x2717
# LG
0x1004
# Sony
0x0fce
# Huawei
0x12d1
ADBVENDORS
  log "ADB USB vendor IDs configured (Motorola + Qualcomm + MediaTek priority)"
else
  warn "adb_usb.ini already exists"
fi

# macOS USB permissions — no driver install needed (unlike Windows)
log "Note: macOS doesn't need Motorola/Qualcomm/MediaTek drivers like Windows."
log "USB devices are accessible natively. Just enable USB Debugging on the phone."

# Restart ADB server
if command -v adb &>/dev/null; then
  adb kill-server 2>/dev/null || true
  adb start-server 2>/dev/null || true
  log "ADB server restarted"
fi

# ---------------------------
# 4c. Testing Folder Structure
# ---------------------------
log "Creating test folders (matching your Windows layout)..."

mkdir -p "$HOME/MVS Apk's"
mkdir -p "$HOME/Test Apk's"
mkdir -p "$HOME/AVS_AUTO"
mkdir -p "$HOME/testing-logs"
mkdir -p "$HOME/bugreports"

log "Folders created: ~/MVS Apk's, ~/Test Apk's, ~/AVS_AUTO, ~/testing-logs, ~/bugreports"

# ---------------------------
# 5. Global npm Packages
# ---------------------------
log "Installing global npm packages..."

npm install -g @anthropic-ai/claude-code pm2

# ---------------------------
# 6. Git Config
# ---------------------------
if [[ -z "$(git config --global user.name)" ]]; then
  log "Setting up Git identity..."
  git config --global user.name "Sai Boyapati"
  read -p "Enter your Git email: " git_email
  git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  log "Git configured"
else
  warn "Git identity already set: $(git config --global user.name)"
fi

# ---------------------------
# 7. SSH Key
# ---------------------------
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  log "Generating SSH key..."
  read -p "Enter email for SSH key (same as Git email): " ssh_email
  ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519 -N ""
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519

  echo ""
  log "Your public SSH key (add this to GitHub > Settings > SSH Keys):"
  echo "---"
  cat ~/.ssh/id_ed25519.pub
  echo "---"
  echo ""
  read -p "Press Enter after you've added the key to GitHub..."
else
  warn "SSH key already exists"
fi

# ---------------------------
# 8. Shell Config (.zshrc)
# ---------------------------
log "Setting up shell config with testing environment..."

ZSHRC=~/.zshrc
touch "$ZSHRC"

if ! grep -q "# == Mac Setup Script ==" "$ZSHRC"; then
  cat >> "$ZSHRC" << 'SHELL_CONFIG'

# == Mac Setup Script ==
# Java 8 (Temurin)
export JAVA_HOME=$(/usr/libexec/java_home -v 1.8 2>/dev/null || echo "")
export PATH="$JAVA_HOME/bin:$PATH"

# Android SDK (full paths for all tools)
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH="$ANDROID_HOME/emulator:$PATH"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export PATH="$ANDROID_HOME/build-tools/36.0.0:$PATH"

# Python 3 as default
alias python=python3
alias pip=pip3

# General shortcuts
alias gs="git status"
alias gl="git log --oneline -20"
alias serve="npx serve ."
alias ll="ls -la"
alias cls="clear"
# == End Mac Setup Script ==
SHELL_CONFIG
  log "Shell config added to .zshrc"
else
  warn ".zshrc already configured"
fi

# ---------------------------
# 9. ADB / Fastboot / MVS Testing Functions
# ---------------------------
log "Adding MVS device testing functions to .zshrc..."

ZSHRC_MVS_MARKER="# == MVS Device Testing =="
if ! grep -q "$ZSHRC_MVS_MARKER" "$ZSHRC"; then
  cat >> "$ZSHRC" << 'MVS_TESTING'

# == MVS Device Testing ==
# --- Device Connection & Info ---
alias adb-devices="adb devices -l"
alias adb-restart="adb kill-server && adb start-server && echo 'ADB restarted' && adb devices -l"
alias adb-info="echo '--- Device Info ---' && adb shell getprop ro.product.model && adb shell getprop ro.product.manufacturer && adb shell getprop ro.build.display.id && adb shell getprop ro.build.version.release && adb shell getprop ro.build.version.sdk"
alias adb-serial="adb shell getprop ro.serialno"

# --- MVS Package Management ---
alias mvs-version='adb shell "dumpsys package com.verizon.mips.services | grep version"'
alias mvs-clear='adb shell pm clear com.verizon.mips.services && echo "MVS data cleared"'
alias mvs-uninstall='adb uninstall com.verizon.mips.services && echo "MVS uninstalled"'
alias mvs-path='adb shell pm path com.verizon.mips.services'

alias apnlib-version='adb shell "dumpsys package com.vzw.apnlib | grep version"'
alias ecid-version='adb shell "dumpsys package com.vzw.ecid | grep version"'
alias myvzw-version='adb shell "dumpsys package com.vzw.hss.myverizon | grep version"'
alias sso-version='adb shell "dumpsys package com.verizon.mips.services | grep version"'
alias vms-version='adb shell "dumpsys package com.securityandprivacy.android.verizon.vms | grep version"'
alias tracfone-version='adb shell "dumpsys package com.tracfone.preload.accountservices | grep version"'

mvs-install() {
  if [[ -z "$1" ]]; then
    echo "Usage: mvs-install <path-to-apk>"
    echo "Available APKs in ~/MVS Apk's/:"
    ls -1 "$HOME/MVS Apk's/"*.apk 2>/dev/null || echo "  (none found)"
    return 1
  fi
  echo "Installing: $1"
  adb install -r -d "$1"
  echo "Verifying installed version..."
  mvs-version
}

apk-install() {
  if [[ -z "$1" ]]; then
    echo "Usage: apk-install <path-to-apk>"
    echo "Available APKs in ~/Test Apk's/:"
    ls -1 "$HOME/Test Apk's/"*.apk 2>/dev/null || echo "  (none found)"
    return 1
  fi
  adb install -r -d "$1"
}

alias mvs-trigger='adb shell am broadcast -a com.verizon.mvsi.intent.action.COLLECT_AND_PUBLISH com.verizon.mips.services && echo "MVS collect & publish triggered"'
alias radio-info='adb shell am start -n com.android.phone/com.android.phone.settings.RadioInfo'

# --- Logging ---
alias adb-logcat="adb logcat -v time"
alias adb-logcat-clear="adb logcat -c"

mvs-logcat() {
  local logfile="${1:-$HOME/testing-logs/mvs_$(date +%Y%m%d_%H%M%S).txt}"
  echo "Capturing MVS logs to: $logfile"
  echo "Press Ctrl+C to stop..."
  adb logcat -v time MVS_VZWAVSService:D *:S | tee "$logfile"
}

log-save() {
  local logfile="$HOME/testing-logs/logcat_$(date +%Y%m%d_%H%M%S).txt"
  echo "Dumping full logcat to: $logfile"
  adb logcat -d -v time > "$logfile"
  echo "Saved: $logfile ($(wc -l < "$logfile") lines)"
}

bugreport() {
  local outfile="$HOME/bugreports/bugreport_$(date +%Y%m%d_%H%M%S).zip"
  echo "Collecting bugreport (this takes a few minutes)..."
  adb bugreport "$outfile"
  echo "Saved: $outfile"
}

# --- Reboot Commands ---
alias adb-reboot="adb reboot"
alias adb-bootloader="adb reboot bootloader"
alias adb-fastboot-reboot="adb reboot fastboot"
alias adb-download="adb reboot download"

# --- Fastboot Commands ---
alias fb-devices="fastboot devices"
alias fb-reboot="fastboot reboot"
alias fb-factory="fastboot oem config bootmode factory"
alias fb-device-info="fastboot oem device-info"
alias fb-unlock="echo 'WARNING: This unlocks bootloader!' && fastboot oem unlock"

# --- WiFi / Data Toggle ---
alias wifi-on="adb shell svc wifi enable && echo 'WiFi ON'"
alias wifi-off="adb shell svc wifi disable && echo 'WiFi OFF'"
alias data-on="adb shell svc data enable && echo 'Mobile data ON'"
alias data-off="adb shell svc data disable && echo 'Mobile data OFF'"
alias wifi-only="adb shell svc wifi enable && adb shell svc data disable && echo 'WiFi-only mode'"

# --- Screenshot / Record ---
alias adb-screenshot='adb exec-out screencap -p > "$HOME/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png" && echo "Screenshot saved to Desktop"'
alias adb-record="adb shell screenrecord /sdcard/recording.mp4 && echo 'Recording... Ctrl+C to stop'"
alias adb-pull-record='adb pull /sdcard/recording.mp4 "$HOME/Desktop/recording_$(date +%Y%m%d_%H%M%S).mp4"'

# --- Battery & Network ---
alias adb-battery="adb shell dumpsys battery"
alias adb-ip="adb shell ip route | awk '{print \$9}'"
alias adb-sim='adb shell getprop gsm.sim.operator.numeric'

# --- Wireless Debugging ---
adb-pair() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: adb-pair <ip:port> <pairing-code>"
    return 1
  fi
  adb pair "$1" "$2"
}

adb-connect() {
  if [[ -z "$1" ]]; then
    echo "Usage: adb-connect <ip:port>"
    return 1
  fi
  adb connect "$1"
}

# --- Emulator ---
alias emu-list="$HOME/Library/Android/sdk/emulator/emulator -list-avds"
alias emu-start="$HOME/Library/Android/sdk/emulator/emulator -avd"
alias emu-cold="$HOME/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_36 -no-snapshot-load"

# --- Full Device Status Report ---
device-status() {
  echo "============================================"
  echo "  DEVICE STATUS REPORT — $(date)"
  echo "============================================"
  echo ""
  echo "--- Connected Devices ---"
  adb devices -l
  echo ""
  echo "--- Device Info ---"
  adb shell getprop ro.product.manufacturer 2>/dev/null
  adb shell getprop ro.product.model 2>/dev/null
  echo "Android: $(adb shell getprop ro.build.version.release 2>/dev/null)"
  echo "SDK:     $(adb shell getprop ro.build.version.sdk 2>/dev/null)"
  echo "Build:   $(adb shell getprop ro.build.display.id 2>/dev/null)"
  echo "Serial:  $(adb shell getprop ro.serialno 2>/dev/null)"
  echo ""
  echo "--- SIM Info ---"
  echo "MCC/MNC: $(adb shell getprop gsm.sim.operator.numeric 2>/dev/null)"
  echo "Carrier: $(adb shell getprop gsm.sim.operator.alpha 2>/dev/null)"
  echo ""
  echo "--- MVS Version ---"
  adb shell "dumpsys package com.verizon.mips.services | grep versionName" 2>/dev/null || echo "  MVS not installed"
  echo ""
  echo "--- Battery ---"
  adb shell dumpsys battery 2>/dev/null | grep -E "level|status|temperature"
  echo "============================================"
}

vzw-versions() {
  echo "=== Verizon Package Versions ==="
  echo "MVS:      $(adb shell dumpsys package com.verizon.mips.services 2>/dev/null | grep versionName | head -1)"
  echo "APNLib:   $(adb shell dumpsys package com.vzw.apnlib 2>/dev/null | grep versionName | head -1)"
  echo "ECID:     $(adb shell dumpsys package com.vzw.ecid 2>/dev/null | grep versionName | head -1)"
  echo "MyVZW:    $(adb shell dumpsys package com.vzw.hss.myverizon 2>/dev/null | grep versionName | head -1)"
  echo "VMS:      $(adb shell dumpsys package com.securityandprivacy.android.verizon.vms 2>/dev/null | grep versionName | head -1)"
  echo "Tracfone: $(adb shell dumpsys package com.tracfone.preload.accountservices 2>/dev/null | grep versionName | head -1)"
  echo "================================"
}

nwlock-install-qcom() {
  local apk="${1:-$HOME/Test Apk's/NWLock_POC_v302_preprod.apk}"
  echo "Installing NWLock POC (QCOM): $apk"
  adb install -r -d "$apk"
}

nwlock-install-mtk() {
  local apk="${1:-$HOME/Test Apk's/NWLock_POC_v303_preprod_MTK.apk}"
  echo "Installing NWLock POC (MTK): $apk"
  adb install -r -d "$apk"
}

# == End MVS Device Testing ==
MVS_TESTING
  log "MVS testing functions added to .zshrc"
else
  warn "MVS testing functions already in .zshrc"
fi

# ---------------------------
# 10. AVS WiFi Test Script
# ---------------------------
log "Creating AVS WiFi test script..."

AVS_SCRIPT="$HOME/AVS_AUTO/avs_wifi_test.sh"
if [[ ! -f "$AVS_SCRIPT" ]]; then
  cat > "$AVS_SCRIPT" << 'AVS_SCRIPT_CONTENT'
#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TAG="MVS_VZWAVSService"
LOGDIR="$HOME/AVS_AUTO"
LOG_FILE="$LOGDIR/avs_log.txt"
REQ_FILE="$LOGDIR/avs_request.txt"
RES_FILE="$LOGDIR/avs_response.txt"

echo "===== AVS WiFi-only Automated Test ====="
echo -e "${YELLOW}[STEP]${NC} Checking device connection..."
DEVICE_COUNT=$(adb devices | grep -c -E "device$")
if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo -e "${RED}[FAIL]${NC} No device connected."
  exit 1
fi
adb devices -l

echo -e "${YELLOW}[STEP]${NC} Clearing previous logcat buffer..."
adb logcat -c

echo -e "${YELLOW}[STEP]${NC} Rebooting device..."
adb reboot

echo -e "${YELLOW}[STEP]${NC} Waiting for device..."
adb wait-for-device

echo -e "${YELLOW}[STEP]${NC} Giving device 60 seconds to boot..."
sleep 60

echo -e "${YELLOW}[STEP]${NC} Forcing WiFi ON and data OFF..."
adb shell svc wifi enable
adb shell svc data disable

echo -e "${YELLOW}[STEP]${NC} Waiting 20 seconds for WiFi..."
sleep 20

echo -e "${YELLOW}[STEP]${NC} Dumping logs for $TAG..."
adb logcat -d -v time "$TAG:D" "*:S" > "$LOG_FILE"

grep -i "Request" "$LOG_FILE" > "$REQ_FILE" 2>/dev/null || true
grep -i "Response" "$LOG_FILE" > "$RES_FILE" 2>/dev/null || true

echo ""
echo "===== RESULT ====="
if [[ -s "$REQ_FILE" ]]; then
  echo -e "${GREEN}[OK]${NC}   $(wc -l < "$REQ_FILE") Request log(s) found"
else
  echo -e "${RED}[FAIL]${NC} No Request log found"
fi

if [[ -s "$RES_FILE" ]]; then
  echo -e "${GREEN}[OK]${NC}   $(wc -l < "$RES_FILE") Response log(s) found"
else
  echo -e "${RED}[FAIL]${NC} No Response log found"
fi

echo ""
echo "Full logs:      $LOG_FILE"
echo "Request lines:  $REQ_FILE"
echo "Response lines: $RES_FILE"
AVS_SCRIPT_CONTENT
  chmod +x "$AVS_SCRIPT"
  log "AVS WiFi test script created at $AVS_SCRIPT"
else
  warn "AVS WiFi test script already exists"
fi

# ---------------------------
# 11. Summary
# ---------------------------
echo ""
echo "==========================================="
log "Setup complete!"
echo "==========================================="
echo "  Dev:       git, node, python3, java 8 (Temurin), poppler, gh"
echo "  IDEs:      Android Studio, IntelliJ, PyCharm, JetBrains Toolbox"
echo "  Browsers:  Chrome, Firefox, Safari"
echo "  AI:        Claude Desktop, ChatGPT, claude-code CLI"
echo "  Android:   SDK 35+36, build-tools, ADB, fastboot, emulator, AVD"
echo "  Testing:   MVS aliases, AVS WiFi test, device-status"
echo "  Utils:     AnyDesk, Vysor, 7zip, pm2"
echo "  Office:    Microsoft 365, Teams"
echo "==========================================="
echo ""
warn "Next steps:"
echo "  1. Restart terminal: source ~/.zshrc"
echo "  2. Open Android Studio once to finish IDE setup"
echo "  3. Connect phone via USB → adb-devices"
echo "  4. Full device report   → device-status"
echo "  5. Run AVS WiFi test    → ~/AVS_AUTO/avs_wifi_test.sh"
echo "  6. Run 'gh auth login' for GitHub CLI"
echo "  7. Run 'claude' to set up Claude Code"
echo ""
echo "  TIP: No Motorola/Qualcomm/MediaTek drivers needed on Mac!"
echo ""
