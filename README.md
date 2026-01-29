# lil homie 🏠💨

> runs so you don't have to.

A friendly HomeKit REST API + CLI for macOS. Control your smart home from the terminal, scripts, or any automation tool.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🏠 **Native HomeKit** — Control all your HomeKit devices
- 🌐 **REST API** — Local server on port 8420
- ⌨️ **CLI Tool** — `lilhomie` for terminal access
- 🎭 **Personality** — A mascot that reacts to what's happening
- 🔒 **Local Only** — Never touches the internet

## Quick Start

```bash
# Clone
git clone https://github.com/ghostmfr/lilhomie.git
cd lilhomie

# Open in Xcode
open Homie.xcodeproj

# Build and run (requires Apple Developer account for HomeKit entitlement)
```

Grant HomeKit access when prompted, and you're good to go.

## REST API

lil homie runs a local API on `http://localhost:8420`.

### Devices

```bash
# List all devices
curl http://localhost:8420/devices

# Get device details
curl http://localhost:8420/device/Desk_Lamp

# Toggle a device (use underscores for spaces)
curl -X POST http://localhost:8420/device/Desk_Lamp/toggle

# Set brightness (0-100)
curl -X POST http://localhost:8420/device/Desk_Lamp/set \
  -H "Content-Type: application/json" \
  -d '{"brightness": 50}'
```

### Rooms

```bash
# List all rooms
curl http://localhost:8420/rooms

# Get devices in a room
curl http://localhost:8420/room/Office

# Turn all devices in room on/off
curl -X POST http://localhost:8420/room/Office/on
curl -X POST http://localhost:8420/room/Office/off

# Toggle specific device in room
curl -X POST http://localhost:8420/room/Office/device/Desk_Lamp/toggle
```

### Scenes

```bash
# List all scenes
curl http://localhost:8420/scenes

# Trigger a scene
curl -X POST http://localhost:8420/scene/Good_Night/trigger
```

## CLI

```bash
# Install CLI
sudo cp lilhomie-cli/lilhomie /usr/local/bin/

# List devices
lilhomie list

# Device status
lilhomie status "Desk Lamp"

# Control devices
lilhomie on "Desk Lamp"
lilhomie off "Desk Lamp"
lilhomie toggle "Desk Lamp"
lilhomie set "Desk Lamp" --brightness 50

# Scenes
lilhomie scenes
lilhomie scene "Good Night"
```

## App Settings

- **Start with computer** — Launch at login
- **Start server automatically** — Auto-start the API server
- **Hide from Dock** — Run as menu bar app only
- **Reset HomeKit Access** — Re-request HomeKit permissions

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Developer Program — required for HomeKit entitlement
- HomeKit-enabled devices

## Known Issues

- Toggle response returns inverted `isOn` state ([#1](https://github.com/ghostmfr/lilhomie/issues/1))

## License

MIT License — see [LICENSE](LICENSE) for details.

---

Built with 🏠💨 by [Ghost Manufacture](https://github.com/ghostmfr)
