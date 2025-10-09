#!/bin/bash

cleanup() {
  OUTPUT_DIR="./output"

  echo -e "${blue}[DEBUG] Cleaning up...${default}"
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
  echo -e "${green}[LOG] Cleanup complete.${default}"
}

