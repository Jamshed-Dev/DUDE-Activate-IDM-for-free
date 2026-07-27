# **DUDE IDM Activator**

DUDE IDM Activator is a tool designed to activate, freeze, reset, or perform a clean reinstall of Internet Download Manager (IDM) for free. By utilizing modern registry manipulation and locking techniques, this activator works with the **latest official IDM versions** (including 2026/v6.42 Build 64 and beyond) without needing to modify or replace the core `IDMan.exe` executable. This ensures full compatibility with the official browser extensions and resolves issues such as YouTube download errors.

---

## 💪 **Features**

- 🔍 **Auto-Detection**: Automatically detects if IDM is not installed on the system and prompts you to download and install the latest official setup.
- ❄️ **Freeze Trial (Recommended)**: Keep the IDM 30-day trial frozen indefinitely without using a fake serial. Completely immune to counterfeit warnings.
- ✅ **Free Activation**: Register IDM with custom details using the registry-lock method and hosts validation bypass. Now runs a two-pass CLSID lock, so the "fake serial" warning no longer appears on the latest IDM builds.
- 🔕 **Alert Blocker (Toggle)**: Turn the three IDM nag alerts off — *fake serial number*, *counterfeit/stolen serial (30-day block)*, and *trial expired* — and turn them back on any time from the same menu.
- 🔄 **Reset Trial**: Clear trial history and restore a fresh, clean 30-day evaluation period.
- 🧹 **Clean Reinstall**: Perform a full uninstallation, deep clean of leftover registry/folders, and automatically download/install the latest official IDM.
- 🗑️ **Clean Uninstall**: Completely purges IDM and all registry remnants without requiring a reboot.
- ⚙️ **Settings & Tools Submenu**:
  - 🚀 **Speed Optimizer**: Configure High-Speed Direct Connection and up to 32 parallel connections for maximum download speed.
  - 🛑 **Block Auto-Updates**: Stop IDM from nagging you to update, keeping your setup stable.
  - 📦 **Extra Extensions**: Automatically import extra file-type download extensions to IDM.
  - 💾 **Backup & Restore**: Export and import your download history, categories, and settings to a folder on your Desktop.
  - 🔧 **Browser Integration Repair**: Re-register DLLs and repair native messaging keys to restore missing browser extensions.
  - 🚀 **Startup Controller**: Easily enable or disable IDM launching automatically on Windows startup.
  - 🔕 **IDM Alerts Toggle**: One option to block or restore all three IDM warning popups, with the current state shown at the top of the menu.
- 🔓 **Unlock Registry**: Restore default registry permissions to allow updates or clean uninstallation.

---

## 🛠️ **Installation & Preparation**

1. **Install official IDM**: Make sure you have downloaded and installed the latest official version of Internet Download Manager directly from the [official IDM website](https://www.internetdownloadmanager.com/download.html). Alternatively, simply run this activator and it will detect the absence of IDM and offer to install it for you!
2. **Download Activator**: Download the latest release of this tool from the [releases page](https://github.com/Jamshed-Dev/DUDE-Activate-IDM-for-free/releases) and extract the files to a folder.

---

## 💻 **Usage**

### **Quick Run (Online via PowerShell)**
Open PowerShell as Administrator and paste the following command to download, extract, and launch the tool automatically:
```powershell
<<<<<<< HEAD
cd $env:TEMP; irm https://github.com/Jamshed-Dev/DUDE-Activate-IDM-for-free/releases/download/IDM/DUDEv3.zip -OutFile DUDEv3.zip; Expand-Archive DUDEv3.zip -DestinationPath . -Force; Remove-Item DUDEv3.zip -Force; cmd.exe /c .\DUDE\script.bat
=======
cd $env:TEMP; irm https://github.com/Jamshed-Dev/DUDE-Activate-IDM-for-free/releases/download/DUDEv3/DUDEv3.zip -OutFile DUDEv3.zip; Expand-Archive DUDEv3.zip -DestinationPath . -Force; Remove-Item DUDEv3.zip -Force; cmd.exe /c .\DUDE\script.bat
>>>>>>> 5e8d98bc43c2f7357d5dcb487604447bd6584d8b
```

### 1. Run the Script Locally:
- Double-click on `script.bat` to execute it. The script will automatically request administrative privileges (UAC elevation) since modifying registry Access Control Lists (ACLs) requires higher permissions.
- Click **Yes** if prompted by User Account Control.

### 2. Main Menu Options:
- **`1` - Freeze Trial (Recommended)**:
  - Resets the trial status and locks the registry keys to hold the trial timer at 30 days forever. Requires no serial keys.
- **`2` - Activate IDM**:
  - Registers IDM under the name `DUDE`, applies a registry lock + hosts block, then runs a second lock pass over the CLSID keys IDM regenerates on its next launch — which is what used to leak the "fake serial" warning.
- **`3` - Reset Trial**:
  - Restores the default, clean 30-day evaluation period.
- **`4` - Clean Reinstall**:
  - Performs a deep-clean uninstall, downloads the latest installer from Tonec, and runs the official setup.
- **`5` - Clean Uninstall**:
  - Fully uninstalls IDM and purges registry traces.
- **`6` - Settings & Tools**:
  - Opens the Submenu containing optimization, update controls, backups, browser repairs, startup toggles, the alert blocker, and registry unlockers.
- **`7` - Exit**:
  - Exits the application.

### 3. Settings & Tools Submenu:
- **`1`** Optimize Download Speed — enable high-speed 32 connections.
- **`2`** Toggle Auto-Updates — block or allow IDM online update checks.
- **`3`** Import Extra Extensions — add extra file formats to the IDM download list.
- **`4`** Backup Settings & Queue — export settings and download history to the Desktop.
- **`5`** Restore Settings & Queue — import them back.
- **`6`** Fix Browser Integration — repair extension capture and the missing download bar.
- **`7`** Toggle Startup Launch — turn IDM auto-launch on Windows startup on or off.
- **`8`** Unlock Registry — restore registry permissions to default.
- **`9`** Toggle IDM Alerts — block or restore the three warning popups (see below).
- **`0`** Back to Main Menu.

---

## 🔕 **About the Alert Blocker**

Option `9` in the Settings submenu switches all three IDM nag alerts off, and switches them back on just as easily. The menu header always shows the current state.

| Alert | How it is blocked |
| --- | --- |
| "IDM has been registered with a **fake serial number**" | Finds IDM's CLSID tracking keys and locks them with `Everyone → Deny` and owner `S-1-0-0`. A **second pass** then seals the keys IDM regenerates on its next launch. |
| "...**counterfeit / stolen serial number**" (30-day block) | Routes Tonec's validation servers to `127.0.0.1` in the `hosts` file. |
| "Your IDM **trial period has expired**" | Restores the registration values, sets `LstCheck` to `12/31/99`, and removes `tvfrdt` / `LastCheckQU`. |

Notes:
- Hosts entries are written inside `# DUDE-IDM-ALERT-BLOCK-START/END` markers, so turning alerts back on removes them cleanly and leaves nothing behind.
- If a serial is already present in the registry it is **not** overwritten — your own registration stays intact.
- Turning alerts back on unlocks the CLSID keys, clears the hosts block, and re-enables IDM's online checks.

---

## 📂 **Files Structure**

- `script.bat` — The entry point and main menu loader.
- `src/menu.ps1` — The main console UI and Logic loop.
- `src/settings.ps1` — The settings, optimizer, updates, and utilities submenu.
- `src/activate.ps1` — PowerShell script to register and lock registry details.
- `src/freeze.ps1` — PowerShell script to reset and freeze the trial period.
- `src/reset.ps1` — PowerShell script to reset the 30-day trial evaluation.
- `src/uninstall.ps1` — PowerShell script to completely purge IDM from the system.
- `src/reinstall.ps1` — PowerShell script to clean uninstall and install the latest official IDM.
- `src/alerts.ps1` — PowerShell script to block or restore the three IDM warning alerts (`-Mode Off` / `-Mode On`).
- `src/unlock.ps1` — PowerShell script to restore default registry permissions.
- `src/extensions.bin` — Registry configurations for extra file extensions.

---

## ☕ **Support the Project (Donations)**

If this activator helps you keep IDM running, consider buying us a coffee! Your support keeps the scripts updated against new IDM builds and the project maintained.

### 🪙 **Supported Cryptocurrencies**

**Bitcoin (BTC)** — *Bitcoin Mainnet Network*

```
12zBsP3LBp352tqCsENS997j1AoCybtW6M
```

**Binance Pay** — *Direct User-to-User Transfer*

```
1247002770
```

---

## 📜 **License**

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## ❓ **Contact & Support**

For questions or support, please open an issue on the GitHub repository or join our Discord.
