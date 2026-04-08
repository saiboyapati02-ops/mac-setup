---
name: User role and testing workflow
description: Sai is a QA/device tester at PamTen working on Verizon MVS (com.verizon.mips.services) — tests APKs on Motorola devices (Qualcomm + MediaTek) using ADB/fastboot from PowerShell/CMD
type: user
---

Sai Boyapati works at PamTen Inc as a device tester focused on Verizon MVS (Mobile Virtual Services) testing.

**Primary work:**
- Testing MVS APK builds (preprod, release, dev variants) on physical Motorola devices
- Devices use both Qualcomm and MediaTek chipsets
- Testing NWLock (Network Lock) POC on both QCOM and MTK platforms
- AVS (App Verification Service) WiFi-only automated testing
- Testing related Verizon packages: APNLib, ECID, MyVerizon, VMS, GameBooster, SSO Client, Tracfone

**Tools & workflow:**
- Uses Windows PowerShell and Command Prompt as primary testing terminals
- Heavy ADB usage: install APKs (-r -d flag), check package versions via dumpsys, logcat capture, bugreports
- Uses fastboot for bootloader operations (factory mode, device-info)
- Vysor for screen mirroring test devices
- Android Studio installed but primarily for SDK/tools, not app development
- Has custom AVS WiFi test batch script that reboots device, forces WiFi-only, captures AVS logs
- Stores APKs in organized folders: "MVS Apk's", "Test Apk's", "AVS_AUTO"

**How to apply:** Frame suggestions around device testing workflows, not app development. Prioritize ADB/fastboot tooling and terminal efficiency.
