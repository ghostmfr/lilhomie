<p align="center">
  <img src="docs/images/icon.png" width="128" alt="lilhomie icon">
</p>

<h1 align="center">lilhomie</h1>

<p align="center">
  <strong>HomeKit REST API + CLI for macOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/github/v/release/ghostmfr/lilhomie" alt="Release">
  <img src="https://github.com/ghostmfr/lilhomie/actions/workflows/ci.yml/badge.svg" alt="CI">
</p>

---

I built **lilhomie** so my AI assistant could control my house. Now you can too.

It's a **macOS app** that runs a local REST API for your HomeKit devices. The CLI talks to the app. No hacks, no workarounds — just Apple's native HomeKit framework exposed over HTTP.

### How it works

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  lilhomie CLI   │ ───► │  lilhomie.app   │ ───► │    HomeKit      │
│  (or any HTTP)  │      │  (REST server)  │      │   (Apple API)   │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

- 🖥️ **macOS app** runs the server on `localhost:8420`
- ⌨️ **CLI** sends requests to the app
- 🏠 **100% Apple HomeKit** — no reverse engineering, no cloud APIs
- 🔒 **Local only** — never touches the internet (unless you're an idiot)
- 🚀 **Raycast extension** — coming soon

### Screenshots

<p align="center">
  <img src="docs/images/main.png" width="280" alt="lilhomie main view">
  <img src="docs/images/endpoints.png" width="280" alt="lilhomie API endpoints">
  <img src="docs/images/settings.png" width="280" alt="lilhomie settings">
</p>

---

## Installation

### Download

Grab the latest release:

👉 **[Download lilhomie](https://github.com/ghostmfr/lilhomie/releases/latest)**

- `lil-homie-v1.0-mac.zip` — macOS app
- `lilhomie-cli-v1.0.zip` — CLI binary

### Setup

1. Unzip and drag **lilhomie.app** to Applications
2. Launch and grant HomeKit access when prompted
3. Server starts automatically on port 8420

### CLI Installation

```bash
# Download and install
curl -L https://github.com/ghostmfr/lilhomie/releases/latest/download/lilhomie-cli.zip -o lilhomie.zip
unzip lilhomie.zip
sudo mv lilhomie /usr/local/bin/
```

---

## REST API

The API runs on `http://localhost:8420` while the app is running.

> **Tip:** Use underscores for spaces in device/room names: `Desk_Lamp`

### Devices

```bash
# List all devices
curl localhost:8420/devices

# Get device info
curl localhost:8420/device/Desk_Lamp

# Toggle
curl -X POST localhost:8420/device/Desk_Lamp/toggle

# Explicit on/off
curl -X POST localhost:8420/device/Desk_Lamp/on
curl -X POST localhost:8420/device/Desk_Lamp/off

# Set brightness
curl -X POST localhost:8420/device/Desk_Lamp/set \
  -H "Content-Type: application/json" \
  -d '{"brightness": 50}'
```

### Rooms

```bash
# List rooms
curl localhost:8420/rooms

# All devices in room
curl localhost:8420/room/Office

# Room on/off
curl -X POST localhost:8420/room/Office/on
curl -X POST localhost:8420/room/Office/off

# Room-scoped device on/off
curl -X POST localhost:8420/room/Office/device/Desk_Lamp/on
curl -X POST localhost:8420/room/Office/device/Desk_Lamp/off
```

### Scenes

```bash
# List scenes
curl localhost:8420/scenes

# Trigger scene
curl -X POST localhost:8420/scene/Good_Night/trigger
```

---

## CLI

```bash
lilhomie list                    # List all devices
lilhomie status "Desk Lamp"      # Device status
lilhomie on "Desk Lamp"          # Turn on
lilhomie off "Desk Lamp"         # Turn off
lilhomie toggle "Desk Lamp"      # Toggle
lilhomie set "Desk Lamp" -b 50   # Set brightness

lilhomie scenes                  # List scenes
lilhomie scene "Good Night"      # Trigger scene
```

---

## Use Cases

- **Home automation scripts** — bash, Python, Node.js
- **Stream Deck buttons** — trigger via curl
- **Clawdbot** — quick device control via imessage
- **Webhooks** — IFTTT, n8n, Home Assistant
- **Cron jobs** — scheduled lighting
- **SSH** — control home from anywhere

---

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Developer account (for HomeKit entitlement)
- HomeKit-compatible devices

---

## Building from Source

```bash
git clone https://github.com/ghostmfr/lilhomie.git
cd lilhomie
open Homie.xcodeproj
# Build and run in Xcode
```

---

## Known Issues

See [Issues](https://github.com/ghostmfr/lilhomie/issues) for current bugs.

---

## License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  Made because siri sucks at turning off my lights.<br>
  <a href="https://github.com/ghostmfr">Ghost Manufacture</a>
</p>
