# Homie Feature Roadmap

> Every feature idea we've discussed, organized by category.

---

## 🎯 Core (v1.0) — DONE ✅

- [x] Native HomeKit integration
- [x] Device control (toggle, brightness)
- [x] Scene triggering
- [x] HTTP API on localhost:8420
- [x] CLI tool (`hkctl`)
- [x] Homie character with mood expressions
- [x] Basic rules engine
- [x] Security-first (localhost only)

---

## 🧠 Context-Aware Automation

### App-Aware Scenes
- [ ] Detect frontmost app via NSWorkspace (requires native macOS, not Catalyst)
- [ ] Map apps to scenes/lighting presets
- [ ] Wildcard matching: `com.adobe.*` → dim lights
- [ ] Window title detection: "Zoom - Meeting" vs just Zoom open
- [ ] Time-aware rules: Lightroom at 2pm ≠ 10pm
- [ ] Learning mode: "You always dim lights when opening Logic. Make this automatic?"

### Presence Detection (Mac-based)
- [ ] Detect user at Mac (mouse/keyboard activity)
- [ ] "Away" timeout → trigger scene (dim lights, lock, etc.)
- [ ] "Return" detection → welcome scene (lights on, wake displays)
- [ ] Integrate with macOS screen lock state

### Focus Mode Sync
- [ ] Read macOS Focus state (Work, Personal, Do Not Disturb)
- [ ] Map Focus modes to HomeKit scenes
- [ ] Work Focus → bright office lights
- [ ] Do Not Disturb → dim everything

### Calendar Awareness
- [ ] Check calendar for upcoming meetings
- [ ] Pre-meeting lighting prep (T-10 minutes)
- [ ] "On Air" detection when meeting starts

### On-Air / Media Detection
- [ ] Detect camera/mic in use
- [ ] Turn on recording light / "On Air" indicator
- [ ] Pause Sonos when video call starts

---

## 🎵 Music & Audio Integration

### Music-Reactive Lighting
- [ ] Match light color to currently playing music
- [ ] Album art color extraction → Hue/RGB bulbs
- [ ] Beat detection for pulse effects (party mode)
- [ ] Genre-based presets (chill = warm, electronic = cool)

### Sonos Integration
- [ ] Detect what's playing on Sonos
- [ ] Music playing → ambient lighting mode
- [ ] Sonos room → corresponding light room

---

## ⌨️ Power User Features

### Keyboard Shortcuts
- [ ] Global hotkeys for favorite devices (⌘⇧1 = toggle office)
- [ ] Quick scene triggers (⌘⇧G = Good Night)
- [ ] Configurable in Settings

### Raycast Extension
- [ ] Natural language: "dim office to 40%"
- [ ] Fuzzy device search
- [ ] Scene quick-launch
- [ ] Favorites list
- [ ] Recent actions

### Shortcuts.app Integration
- [ ] App Intents for device control
- [ ] Scene triggers as Shortcuts actions
- [ ] Enable: HomeKit event → Mac automation

### AppleScript Support
- [ ] Scripting dictionary
- [ ] `tell application "Homie" to toggle device "Office Lamp"`

---

## 🔄 Bi-Directional (HomeKit → Mac)

### Launch Apps from HomeKit
- [ ] Scene triggers → launch specific apps
- [ ] "Movie mode" scene → open Plex, dim lights
- [ ] "Work mode" scene → open Slack, Notion, etc.

### Mac Actions from HomeKit Events
- [ ] Motion sensor → wake Mac from sleep
- [ ] Doorbell ring → show notification, pause media
- [ ] "Leaving" scene → lock Mac, quit apps
- [ ] Button press (Pico remote) → trigger Keyboard Maestro macro

### Wake/Sleep Sync
- [ ] Mac display sleeps → office lights off
- [ ] Mac wakes → lights on
- [ ] Bidirectional: lights off → sleep Mac (optional)

---

## 📊 Analytics & Logging

### Event Logging Service
- [ ] Log all HomeKit events (device changes, scene triggers)
- [ ] Timestamp, source (manual/auto/API), device, action
- [ ] Local SQLite database
- [ ] Export to CSV/JSON

### Analytics Dashboard
- [ ] Usage patterns visualization
- [ ] "Most used devices" chart
- [ ] "Peak usage times" heatmap
- [ ] Energy insights (time lights are on)
- [ ] Scene trigger frequency

### History View
- [ ] In-app activity log
- [ ] "What changed while I was away?"
- [ ] Filter by room, device, time

---

## 🔒 Security & Privacy

### Paranoid Mode (Current)
- [x] Localhost-only binding (127.0.0.1)
- [ ] Startup security audit
- [ ] Periodic exposure checks
- [ ] Character frown when exposed 😠

### LAN Mode (Optional)
- [ ] Allow 10.x.x.x / 192.168.x.x access
- [ ] Require API key for LAN access
- [ ] Per-device allowlisting

### Audit Log
- [ ] Log all API access attempts
- [ ] Alert on suspicious patterns

---

## 🎨 UI & Character

### Homie Character
- [ ] Custom artwork (from Garrett's Figma design)
- [ ] 6 expressions: happy, excited, sleepy, angry, thinking, idea
- [ ] Smooth transitions between moods
- [ ] Blink animation
- [ ] Reaction animations (bounce on action, shake when angry)

### Menu Bar (Native macOS only)
- [ ] Compact device list
- [ ] Quick toggles
- [ ] Status at a glance: "3 lights on"
- [ ] Active rules indicator

### Settings UI
- [ ] Rules editor (app → scene mapping)
- [ ] Keyboard shortcuts configuration
- [ ] CLI install button
- [ ] Launch at login toggle
- [ ] LAN mode + API key

---

## 🛠️ Developer Experience

### HTTP API
- [x] GET /health
- [x] GET /devices
- [x] POST /device/:id/toggle
- [x] POST /device/:id/set
- [x] GET /scenes
- [x] POST /scene/:id/trigger
- [x] GET /rules
- [ ] WebSocket for real-time events
- [ ] Webhooks for external integrations

### CLI Enhancements
- [x] hkctl list
- [x] hkctl toggle <device>
- [x] hkctl scene <name>
- [ ] hkctl watch (real-time event stream)
- [ ] hkctl log (show recent activity)
- [ ] hkctl config (manage settings)

---

## 📱 Platform Support

### Current
- [x] Mac Catalyst (limited features)

### Planned
- [ ] Native macOS app (full features, menu bar, NSWorkspace)
- [ ] iOS companion (remote control when away from Mac)
- [ ] watchOS complication (quick toggles)

---

## 💰 Monetization Ideas

### Free Tier
- Device control
- Basic scenes
- HTTP API
- CLI

### Pro Tier ($10-15)
- App-aware scenes
- Music-reactive lighting
- Raycast extension
- Analytics dashboard
- Priority support

### Distribution
- Direct download (notarized) — avoid App Store 30%
- GitHub releases
- Optional: App Store for discoverability

---

*Last updated: 2026-01-28*
