#!/bin/bash

rebuild_apk() {
  OUTPUT_DIR="./output"
  mkdir -p "$OUTPUT_DIR"

  echo -e "${blue}[DEBUG] Rebuilding APK...${default}"
  if apktool b "$OUTPUT_DIR/decompiled_apk" -o "$OUTPUT_DIR/unsigned.apk" -f; then
    echo -e "${green}[LOG] APK rebuilt successfully at $OUTPUT_DIR/unsigned.apk${default}"
  else
    echo -e "${red}[ERROR] Failed to rebuild APK.${default}"
  fi
}
