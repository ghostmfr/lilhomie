# lilhomie for Raycast

Control your HomeKit devices and scenes directly from Raycast using the [lilhomie](https://github.com/ghostmfr/lilhomie) macOS app.

## Requirements

- **lilhomie** macOS app must be running (it exposes a local HTTP API on port 8420)
- Raycast installed on macOS

## Commands

### List Devices
Browse all your HomeKit devices with their current on/off state and brightness. Filter by room using the dropdown. Toggle devices or set brightness presets (25%, 50%, 75%, 100%) directly from the list.

### Toggle Device
Search for a device by name or room and toggle it on or off. Accepts an optional pre-filled device name argument so you can create Quicklinks for specific devices.

### Scenes
View all your HomeKit scenes and trigger them with a single keypress. Scenes are grouped by home and show how many actions they contain.

### Quick Toggle _(no-view)_
Instantly toggle a device without opening any window. Type the device name as an argument and get a HUD confirmation. Perfect for assigning hotkeys to frequently toggled devices.

**Example:** Set up a Raycast hotkey for `Quick Toggle` with argument `desk lamp` to toggle your desk lamp with a single keystroke.

## Setup

1. Install and launch the **lilhomie** macOS app
2. In Raycast, go to **Extensions → Import Extension** and select the `raycast-extension` folder, **or** install from the Raycast Store
3. Search for any of the commands above in Raycast

The extension connects to `http://127.0.0.1:8420` — no configuration needed as long as lilhomie is running.

## Troubleshooting

**"lilhomie Not Reachable" error**
- Make sure the lilhomie macOS app is open and running in the menu bar
- Check that nothing else is using port 8420

**Device not found (Quick Toggle)**
- Device names are matched case-insensitively; partial matches work (e.g., `lamp` matches `Desk Lamp`)
- Use the List Devices command to see exact device names

## Store Assets Note

> ⚠️ `extension-icon.png` (512×512) and store screenshots are required for Raycast Store submission but are not yet included in this repository. See issue #17.

## Development

```bash
cd raycast-extension
npm install
npm run dev
```

## License

MIT
