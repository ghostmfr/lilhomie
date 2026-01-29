# Homie for Raycast

Control your HomeKit devices directly from Raycast.

## Prerequisites

- [Homie](https://github.com/ghostmfr/Homie) app running on your Mac
- Raycast installed

## Installation

1. Clone this extension or download it
2. Open Raycast → Extensions → Import Extension
3. Select the `raycast-extension` folder

Or install via npm:

```bash
cd raycast-extension
npm install
npm run dev
```

## Commands

### List Devices
Show all your HomeKit devices with their current state. Filter by room.

### Toggle Device
Search and toggle any device on/off.

### Scenes
View and trigger HomeKit scenes.

### Quick Toggle (no-view)
Instantly toggle a device by name without opening a window.

**Usage:** Type `homie quick-toggle` followed by a device name.

Example: `homie quick-toggle office lamp`

## Configuration

The extension connects to Homie's HTTP API at `http://127.0.0.1:8420`.

Make sure Homie is running before using the extension.

## Development

```bash
npm install
npm run dev
```

## License

MIT
