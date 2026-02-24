# Homie Architecture

> The missing bridge between macOS and your home.

## Vision

Homie is a context-aware HomeKit controller that understands what you're doing on your Mac and adjusts your home accordingly. It's local-first, privacy-respecting, and paranoid about security.

## Core Principles

1. **Local-only** — Never touches the internet. LAN at most.
2. **Context-aware** — Knows what app you're using, time of day, calendar
3. **Bi-directional** — Mac → Home AND Home → Mac
4. **Personality** — Homie is a character, not just an app

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         HOMIE APP                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Homie UI   │  │  HTTP API    │  │  CLI (hkctl) │           │
│  │  (SwiftUI)   │  │ :8420 local  │  │              │           │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │
│         │                 │                 │                    │
│         └────────────┬────┴────────────────┘                    │
│                      │                                           │
│              ┌───────▼───────┐                                  │
│              │  HomeKit Core │                                  │
│              │  (HMHomeManager)                                 │
│              └───────┬───────┘                                  │
│                      │                                           │
│  ┌───────────────────┼───────────────────┐                      │
│  │                   │                   │                      │
│  ▼                   ▼                   ▼                      │
│ ┌─────────┐   ┌─────────────┐   ┌─────────────┐                 │
│ │ Devices │   │   Scenes    │   │   Rooms     │                 │
│ └─────────┘   └─────────────┘   └─────────────┘                 │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                      CONTEXT ENGINE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ App Monitor  │  │ Focus Mode   │  │  Calendar    │           │
│  │ (NSWorkspace)│  │   Sync       │  │   Peek       │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Time-of-Day │  │ Display/Mic  │  │  User Rules  │           │
│  │   Awareness  │  │   Monitor    │  │   Engine     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                      INTEGRATIONS                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Raycast    │  │  Shortcuts   │  │  AppleScript │           │
│  │  Extension   │  │    .app      │  │   Actions    │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │   HomeKit (Local) │
                    │   Your Home       │
                    └───────────────────┘
```

---

## Module Breakdown

### 1. Homie UI (SwiftUI)

The character-driven interface.

```
Components:
├── HomieCharacter.swift      # Animated character with expressions
├── MenuBarView.swift         # Menu bar presence
├── DeviceListView.swift      # Device browser
├── FavoritesView.swift       # Quick access strip
├── RulesView.swift           # App-aware rules editor
├── SettingsView.swift        # Preferences, CLI install, auto-start
└── SecurityIndicator.swift   # Network exposure warning
```

**Character Expressions:**
- 😊 Happy (idle, everything good)
- 🤩 Excited (action triggered)
- 😴 Sleepy (night mode / low activity)
- 😠 Angry (port exposed to internet!)
- 🤔 Thinking (processing)
- 💡 Idea (suggestion available)

### 2. HomeKit Core

Wraps Apple's HomeKit framework.

```
Components:
├── HomeKitManager.swift      # HMHomeManager wrapper
├── DeviceController.swift    # Toggle, set brightness, etc.
├── SceneController.swift     # Trigger HomeKit scenes
└── StateCache.swift          # Local device state cache
```

### 3. HTTP API

Local-only REST API for automation.

```
Endpoints:
GET  /health              # Health check
GET  /devices             # List all devices
GET  /device/:id          # Get device state
POST /device/:id/toggle   # Toggle device
POST /device/:id/on       # Turn device on
POST /device/:id/off      # Turn device off
POST /device/:id/set      # Set state {on, brightness}
POST /room/:r/device/:d/on   # Turn room-scoped device on
POST /room/:r/device/:d/off  # Turn room-scoped device off
GET  /scenes              # List scenes
POST /scene/:id/trigger   # Trigger scene
GET  /rules               # List app-aware rules
POST /rules               # Create rule
```

**Security:**
- Binds to 127.0.0.1 ONLY
- Startup check for port forwarding
- Optional: LAN mode with API key (10.x.x.x access)

### 4. Context Engine

The brain that watches what you're doing.

```
Components:
├── AppMonitor.swift          # NSWorkspace frontmost app
├── WindowTitleMonitor.swift  # Active window title (accessibility)
├── FocusModeMonitor.swift    # macOS Focus state
├── CalendarMonitor.swift     # Upcoming meetings
├── DisplayMonitor.swift      # Display sleep/wake
├── MediaMonitor.swift        # Camera/mic active
└── RuleEngine.swift          # Evaluates conditions, triggers actions
```

**App-Aware Rules Format:**
```json
{
  "id": "uuid",
  "name": "Editing Mode",
  "enabled": true,
  "conditions": {
    "app": "com.adobe.Lightroom*",
    "timeRange": {"after": "18:00", "before": "23:00"},
    "focus": null
  },
  "actions": [
    {"type": "scene", "sceneId": "dim-office"},
    {"type": "device", "deviceId": "xxx", "set": {"brightness": 20}}
  ],
  "revert": true  // Revert when conditions no longer match
}
```

### 5. CLI (hkctl)

Command-line interface.

```bash
hkctl list                    # List devices
hkctl toggle "Office Lamp"    # Toggle
hkctl on/off <device>         # Set state
hkctl set <device> 50         # Set brightness
hkctl scenes                  # List scenes
hkctl scene "Good Night"      # Trigger scene
hkctl rules                   # List rules
hkctl status                  # Homie status
```

### 6. Integrations

**Raycast Extension:**
- TypeScript extension in separate repo
- Calls Homie HTTP API
- Natural language via local LLM or fuzzy matching
- Commands: toggle, scenes, favorites

**Shortcuts.app:**
- Expose Intents via App Intents framework
- "Toggle Device", "Set Brightness", "Trigger Scene"
- Enables: HomeKit trigger → Mac action

**AppleScript:**
- Expose scripting dictionary
- `tell application "Homie" to toggle device "Office Lamp"`

---

## Data Storage

```
~/Library/Application Support/Homie/
├── config.json           # User preferences
├── rules.json            # App-aware rules
├── favorites.json        # Pinned devices
├── cache/
│   └── devices.json      # Cached device state
└── logs/
    └── activity.log      # Action history
```

---

## Security Model

### Paranoid Local-Only

1. **Bind to 127.0.0.1** — Never 0.0.0.0
2. **Startup audit** — Check for port forwarding rules
3. **Periodic check** — Every 5 min, verify no exposure
4. **Visual indicator** — Character mood reflects security state
5. **LAN mode** (optional) — API key required, only 10.x/192.168.x

### Character Security States

| State | Character | Trigger |
|-------|-----------|---------|
| 🟢 Secure | 😊 Happy | Localhost only, no exposure |
| 🟡 LAN | 🤔 Cautious | LAN mode enabled with API key |
| 🔴 EXPOSED | 😠 ANGRY | Port forwarded to internet |

If EXPOSED state detected:
- Character permanently frowns
- Warning banner in UI
- API returns 503 until fixed
- Log security event

---

## Roadmap

### v1.0 — Core + App-Aware Scenes
- [ ] Homie character UI (menu bar)
- [ ] Device list and control
- [ ] HTTP API (localhost)
- [ ] App monitor (NSWorkspace)
- [ ] Basic rules engine (app → scene)
- [ ] CLI tool
- [ ] Auto-start (SMAppService)

### v1.1 — Polish
- [ ] Character animations
- [ ] Favorites
- [ ] Room grouping
- [ ] Security audit on launch

### v1.2 — Integrations
- [ ] Raycast extension
- [ ] Shortcuts.app intents
- [ ] Focus mode sync

### v2.0 — Bi-directional
- [ ] HomeKit → Mac actions
- [ ] Calendar awareness
- [ ] On-air detection

---

## Development

### Requirements
- macOS 13+
- Xcode 15+
- Apple Developer Program ($99) — for HomeKit entitlement

### Build
```bash
# Open in Xcode
open Homie.xcodeproj

# Or via CLI
xcodebuild -scheme Homie -configuration Release build
```

### Test API
```bash
curl http://localhost:8420/health
curl http://localhost:8420/devices
```

---

## File Structure

```
Homie/
├── Homie/
│   ├── App/
│   │   ├── HomieApp.swift
│   │   └── AppDelegate.swift
│   ├── UI/
│   │   ├── Character/
│   │   │   ├── HomieCharacter.swift
│   │   │   └── Expressions.swift
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift
│   │   ├── Devices/
│   │   │   └── DeviceListView.swift
│   │   ├── Rules/
│   │   │   └── RulesView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── HomeKit/
│   │   ├── HomeKitManager.swift
│   │   └── DeviceController.swift
│   ├── Context/
│   │   ├── AppMonitor.swift
│   │   ├── RuleEngine.swift
│   │   └── Rules.swift
│   ├── API/
│   │   └── HTTPServer.swift
│   └── Resources/
│       └── Assets.xcassets
├── hkctl/
│   └── main.swift
├── docs/
│   └── ARCHITECTURE.md
├── README.md
├── LICENSE
└── Makefile
```

---

*Last updated: 2026-01-28*
