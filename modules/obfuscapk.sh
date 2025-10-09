#!/bin/bash

# Integrates Obfuscapk into the workflow
# Prereqs installed by assistant under:
#   - Repo:   /home/smith/Desktop/github-projects/Obfuscapk
#   - Venv:   /home/smith/Desktop/github-projects/Obfuscapk/.venv311
#   - Tools:  apktool, zipalign (~/.local/bin), apksigner

obfuscapk_obfuscate() {
  local OUTPUT_DIR="./output"
  local DEFAULT_INPUT_APK="$OUTPUT_DIR/unsigned.apk"
  local OBF_REPO="/home/smith/Desktop/github-projects/Obfuscapk"
  local OBF_VENV="$OBF_REPO/.venv311"
  local OBF_PY="$OBF_VENV/bin/python"
  local OBF_SRC="$OBF_REPO/src"
  local WORK_DIR="$OUTPUT_DIR/obfuscapk_work"
  local DEST_APK="$OUTPUT_DIR/obfuscated.apk"

  mkdir -p "$OUTPUT_DIR"

  # Validate installation
  if [ ! -x "$OBF_PY" ] || [ ! -d "$OBF_SRC" ]; then
    echo -e "${red}[ERROR] Obfuscapk environment not found at $OBF_VENV.${default}"
    echo -e "${yellow}[HINT] Please let me know to reinstall/setup Obfuscapk.${default}"
    return 1
  fi

  # Ensure zipalign on PATH for Obfuscapk
  export PATH="$HOME/.local/bin:$PATH"
  export BUNDLE_DECOMPILER_PATH=true   # bypass AAB tool check, we handle APKs here

  # Choose input APK
  local INPUT_APK=""
  if [ -f "$DEFAULT_INPUT_APK" ]; then
    echo -ne "Use rebuilt APK at $DEFAULT_INPUT_APK? [Y/n]: "
    read yn
    if [ -z "$yn" ] || [[ "$yn" =~ ^[Yy]$ ]]; then
      INPUT_APK="$DEFAULT_INPUT_APK"
    fi
  fi
  while [ -z "$INPUT_APK" ]; do
    echo -ne "Enter path to APK to obfuscate (or leave blank to list ./APPS): "
    read p
    if [ -z "$p" ]; then
      echo "Available in ./APPS:"; ls -1 ./APPS/*.apk 2>/dev/null || echo "  (no APKs)"
      echo -ne "Pick an APK path: "
      read p
    fi
    if [ -n "$p" ] && [ -f "$p" ]; then
      INPUT_APK="$p"
    else
      echo -e "${red}[ERROR] Invalid APK path. Try again.${default}"
    fi
  done

  # Ask obfuscator list (safe default)
  echo "Allowed obfuscators include: ClassRename, MethodRename, FieldRename, Reorder,"
  echo "  ArithmeticBranch, DebugRemoval, Goto, Nop, Reflection, CallIndirection,"
  echo "  ConstStringEncryption, ResStringEncryption, AssetEncryption, LibEncryption,"
  echo "  RandomManifest, NewAlignment, NewSignature, Rebuild, VirusTotal"
  echo -ne "Enter comma-separated obfuscators (default: ClassRename,MethodRename,FieldRename,Rebuild): "
  read OLIST
  OLIST=${OLIST:-ClassRename,MethodRename,FieldRename,Rebuild}

  # Clean work dir
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR"

  # Build CLI arguments
  local args=( )
  IFS=',' read -r -a obfs <<< "$OLIST"
  for ob in "${obfs[@]}"; do
    ob_trim=$(echo "$ob" | xargs)
    [ -n "$ob_trim" ] && args+=( -o "$ob_trim" )
  done

  echo -e "${blue}[DEBUG] Running Obfuscapk...${default}"
  echo "  Input:  $INPUT_APK"
  echo "  Out:    $DEST_APK"
  echo "  Work:   $WORK_DIR"
  echo "  Obfs:   ${args[*]}"

  # Execute
  PYTHONPATH="$OBF_SRC" "$OBF_PY" -m obfuscapk.cli \
    "${args[@]}" \
    -w "$WORK_DIR" \
    -d "$DEST_APK" \
    "$INPUT_APK"
  local rc=$?
  if [ $rc -ne 0 ] || [ ! -f "$DEST_APK" ]; then
    echo -e "${red}[ERROR] Obfuscapk failed. Exit code: $rc${default}"
    return 1
  fi

  echo -e "${green}[LOG] Obfuscated APK created: $DEST_APK${default}"

  # Verify signature and alignment
  if command -v apksigner >/dev/null 2>&1; then
    echo -e "${blue}[DEBUG] Verifying APK signature...${default}"
    apksigner verify --print-certs "$DEST_APK" || echo -e "${yellow}[WARN] apksigner verification failed.${default}"
  fi
  if command -v zipalign >/dev/null 2>&1; then
    echo -e "${blue}[DEBUG] Checking alignment...${default}"
    zipalign -c 4 "$DEST_APK" && echo -e "${green}[LOG] Alignment OK.${default}" || echo -e "${yellow}[WARN] Not 4-byte aligned.${default}"
  fi
}

