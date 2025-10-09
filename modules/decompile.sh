#!/bin/bash

decompile_apk() {
  OUTPUT_DIR="./output"
  APPS_DIR="./APPS"
  mkdir -p "$OUTPUT_DIR"
  
  echo -e "${blue}[DEBUG] Scanning $APPS_DIR for APK files...${default}"
  files=("$APPS_DIR"/*.apk)
  if [ ${#files[@]} -eq 0 ]; then
    echo -e "${red}[ERROR] No APK files found in $APPS_DIR.${default}"
    return
  fi

  echo "Available APKs:"
  for i in "${!files[@]}"; do
    echo "$((i + 1)). ${files[i]}"
  done

  echo -ne "Select an APK by number: "
  read choice
  selected_apk="${files[$((choice - 1))]}"

  if [ -z "$selected_apk" ]; then
    echo -e "${red}[ERROR] Invalid selection.${default}"
    return
  fi

  echo -e "${blue}[DEBUG] Selected APK: $selected_apk${default}"
  if apktool d "$selected_apk" -o "$OUTPUT_DIR/decompiled_apk" --no-debug-info -f; then
    echo -e "${green}[LOG] APK decompiled successfully into $OUTPUT_DIR/decompiled_apk${default}"
  else
    echo -e "${red}[ERROR] Failed to decompile APK.${default}"
  fi
}
