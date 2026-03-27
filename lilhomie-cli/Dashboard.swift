import Foundation
import Darwin

// MARK: - ANSI Helpers

private enum ANSI {
    static let clear        = "\u{1B}[2J\u{1B}[H"
    static let hideCursor   = "\u{1B}[?25l"
    static let showCursor   = "\u{1B}[?25h"
    static let reset        = "\u{1B}[0m"
    static let bold         = "\u{1B}[1m"
    static let dim          = "\u{1B}[2m"
    static let cyan         = "\u{1B}[36m"
    static let green        = "\u{1B}[32m"
    static let yellow       = "\u{1B}[33m"
    static let blue         = "\u{1B}[34m"
    static let magenta      = "\u{1B}[35m"
    static let white        = "\u{1B}[37m"
    static let brightWhite  = "\u{1B}[97m"
    static let bgDefault    = "\u{1B}[49m"

    static func move(_ row: Int, _ col: Int) -> String { "\u{1B}[\(row);\(col)H" }
    static func eraseLine() -> String { "\u{1B}[2K" }
}

// MARK: - Raw Terminal Mode

private var originalTermios = termios()

func enableRawMode() {
    tcgetattr(STDIN_FILENO, &originalTermios)
    var raw = originalTermios
    raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
    raw.c_cc.16 = 1  // VMIN
    raw.c_cc.17 = 0  // VTIME
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
}

func disableRawMode() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
}

// MARK: - Key Reading

private enum Key {
    case up, down, left, right
    case space, enter, plus, minus
    case char(Character)
}

private func readKey() -> Key? {
    var buf = [UInt8](repeating: 0, count: 3)
    let n = read(STDIN_FILENO, &buf, 3)
    guard n > 0 else { return nil }
    if n == 3 && buf[0] == 27 && buf[1] == 91 {
        switch buf[2] {
        case 65: return .up
        case 66: return .down
        case 67: return .right
        case 68: return .left
        default: return nil
        }
    }
    switch buf[0] {
    case 32:  return .space
    case 13:  return .enter
    case 43:  return .plus
    case 45:  return .minus
    default:
        if let scalar = Unicode.Scalar(buf[0]) {
            return .char(Character(scalar))
        }
        return nil
    }
}

// MARK: - Dashboard

/// A flat entry representing one item in the navigable list
private struct ListEntry {
    enum Kind { case device(Device); case scene(Scene) }
    let kind: Kind
    var displayName: String {
        switch kind {
        case .device(let d): return d.name
        case .scene(let s):  return s.name
        }
    }
}

public class Dashboard {
    // State
    private var devices: [Device] = []
    private var scenes:  [Scene]  = []
    private var entries: [ListEntry] = []
    private var selectedIndex = 0
    private var view: ViewMode = .devices
    private var statusMessage = ""
    private var isRunning = true

    private enum ViewMode { case devices, scenes }

    // Terminal dimensions
    private var termWidth  = 80
    private var termHeight = 24

    public init() {}

    public func run() {
        // Initial fetch — bail early if server unreachable
        guard fetchDevices(), fetchScenes() else {
            print("❌ Cannot connect to Homie. Is the app running? (http://127.0.0.1:8420)")
            return
        }
        buildEntries()

        // Setup terminal
        enableRawMode()
        print(ANSI.hideCursor, terminator: "")
        fflush(stdout)

        // Restore on exit
        defer {
            disableRawMode()
            print(ANSI.showCursor, terminator: "")
            print(ANSI.clear, terminator: "")
            fflush(stdout)
        }

        // Background poll thread
        let pollThread = Thread {
            while self.isRunning {
                Thread.sleep(forTimeInterval: 2.0)
                guard self.isRunning else { break }
                _ = self.fetchDevices()
                _ = self.fetchScenes()
                self.buildEntries()
                self.render()
            }
        }
        pollThread.start()

        // Initial render
        updateTermSize()
        render()

        // Input loop
        while isRunning {
            guard let key = readKey() else { continue }
            handleKey(key)
            render()
        }
    }

    // MARK: - Input

    private func handleKey(_ key: Key) {
        switch key {
        case .up:
            if selectedIndex > 0 { selectedIndex -= 1 }
        case .down:
            if selectedIndex < entries.count - 1 { selectedIndex += 1 }
        case .space:
            actOnSelected()
        case .enter:
            actOnSelected()
        case .plus:
            adjustBrightness(delta: +10)
        case .minus:
            adjustBrightness(delta: -10)
        case .char(let c):
            switch c {
            case "q", "Q":
                isRunning = false
            case "s", "S":
                view = view == .devices ? .scenes : .devices
                selectedIndex = 0
                buildEntries()
                statusMessage = view == .devices ? "Devices" : "Scenes"
            case "d", "D":
                view = .devices
                selectedIndex = 0
                buildEntries()
            case "r", "R":
                _ = fetchDevices()
                _ = fetchScenes()
                buildEntries()
                statusMessage = "Refreshed"
            default:
                break
            }
        default:
            break
        }
    }

    private func actOnSelected() {
        guard selectedIndex < entries.count else { return }
        let entry = entries[selectedIndex]
        switch entry.kind {
        case .device(let d):
            let encoded = d.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? d.id
            if let _ = request("POST", "/devices/\(encoded)/toggle") {
                _ = fetchDevices()
                buildEntries()
                let newState = devices.first(where: { $0.id == d.id })?.isOn ?? !d.isOn
                statusMessage = "\(d.name) → \(newState ? "ON" : "OFF")"
            } else {
                statusMessage = "❌ Toggle failed"
            }
        case .scene(let s):
            let encoded = s.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s.id
            if let _ = request("POST", "/scenes/\(encoded)/trigger") {
                statusMessage = "✓ Scene '\(s.name)' triggered"
            } else {
                statusMessage = "❌ Scene failed"
            }
        }
    }

    private func adjustBrightness(delta: Int) {
        guard selectedIndex < entries.count else { return }
        let entry = entries[selectedIndex]
        guard case .device(let d) = entry.kind else { return }
        let current = d.brightness ?? 50
        let newLevel = max(0, min(100, current + delta))
        let encoded = d.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? d.id
        if let _ = request("POST", "/devices/\(encoded)/set", body: ["brightness": newLevel, "on": true]) {
            _ = fetchDevices()
            buildEntries()
            statusMessage = "\(d.name) → \(newLevel)%"
        } else {
            statusMessage = "❌ Set brightness failed"
        }
    }

    // MARK: - Data

    @discardableResult
    private func fetchDevices() -> Bool {
        guard let data = request("GET", "/devices"),
              let resp = try? JSONDecoder().decode(DevicesResponse.self, from: data) else {
            return false
        }
        devices = resp.devices
        return true
    }

    @discardableResult
    private func fetchScenes() -> Bool {
        guard let data = request("GET", "/scenes"),
              let resp = try? JSONDecoder().decode(ScenesResponse.self, from: data) else {
            return false
        }
        scenes = resp.scenes
        return true
    }

    private func buildEntries() {
        switch view {
        case .devices:
            entries = devices
                .sorted { ($0.room ?? "zzz") < ($1.room ?? "zzz") || (($0.room ?? "") == ($1.room ?? "") && $0.name < $1.name) }
                .map { ListEntry(kind: .device($0)) }
        case .scenes:
            entries = scenes
                .sorted { $0.name < $1.name }
                .map { ListEntry(kind: .scene($0)) }
        }
        if selectedIndex >= entries.count { selectedIndex = max(0, entries.count - 1) }
    }

    // MARK: - Rendering

    private func updateTermSize() {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 {
            termWidth  = max(60, Int(ws.ws_col))
            termHeight = max(16, Int(ws.ws_row))
        }
    }

    private func render() {
        updateTermSize()
        var lines: [String] = []

        let innerWidth = termWidth - 2  // inside the box borders

        // ── Title bar ──
        let title = " lilhomie "
        let viewLabel = view == .devices ? " devices " : " scenes "
        let titlePad = String(repeating: "─", count: max(0, innerWidth - title.count - viewLabel.count - 2))
        lines.append("\(ANSI.cyan)┌\(title)\(ANSI.dim)\(titlePad)\(ANSI.reset)\(ANSI.cyan)\(viewLabel)┐\(ANSI.reset)")

        // ── Device/scene rows ──
        let maxRows = termHeight - 6  // title + help + status + bottom border
        var lastRoom: String? = nil
        var rowCount = 0

        // Determine scroll window
        let scrollStart = max(0, selectedIndex - maxRows + 3)
        let visibleEntries = Array(entries.dropFirst(scrollStart).prefix(maxRows))

        for (i, entry) in visibleEntries.enumerated() {
            let globalIdx = i + scrollStart
            let isSelected = globalIdx == selectedIndex

            switch entry.kind {
            case .device(let d):
                // Room header
                let room = d.room ?? "No Room"
                if room != lastRoom {
                    if lastRoom != nil {
                        lines.append("\(ANSI.cyan)│\(ANSI.reset)\(String(repeating: " ", count: innerWidth))\(ANSI.cyan)│\(ANSI.reset)")
                        rowCount += 1
                    }
                    let roomLine = "  \(ANSI.bold)\(ANSI.yellow)\(room)\(ANSI.reset)"
                    let roomPad = String(repeating: " ", count: max(0, innerWidth - 2 - room.count))
                    lines.append("\(ANSI.cyan)│\(ANSI.reset)\(roomLine)\(roomPad)\(ANSI.cyan)│\(ANSI.reset)")
                    rowCount += 1
                    lastRoom = room
                }

                // Device row
                let dot    = d.isOn ? "\(ANSI.green)●\(ANSI.reset)" : "\(ANSI.dim)○\(ANSI.reset)"
                let state  = d.isOn ? "\(ANSI.green)ON \(ANSI.reset)" : "\(ANSI.dim)OFF\(ANSI.reset)"
                let bar    = brightnessBar(d.brightness, on: d.isOn)
                let pct    = d.brightness.map { "\(ANSI.dim)\($0)%\(ANSI.reset)" } ?? ""
                let nameTrunc = truncate(d.name, to: 22)
                let namePad = String(repeating: " ", count: max(0, 22 - d.name.count))
                let cursor = isSelected ? "\(ANSI.magenta)▶\(ANSI.reset)" : " "
                let row = "  \(cursor) \(dot) \(nameTrunc)\(namePad)  \(state)  \(bar) \(pct)"
                let visLen = 2 + 1 + 1 + 1 + 1 + 22 + 2 + 3 + 2 + 10 + 1 + 4
                let rowPad = String(repeating: " ", count: max(0, innerWidth - visLen))
                lines.append("\(ANSI.cyan)│\(ANSI.reset)\(row)\(rowPad)\(ANSI.cyan)│\(ANSI.reset)")
                rowCount += 1

            case .scene(let s):
                let cursor = isSelected ? "\(ANSI.magenta)▶\(ANSI.reset)" : " "
                let nameTrunc = truncate(s.name, to: 36)
                let namePad = String(repeating: " ", count: max(0, 36 - s.name.count))
                let home = "\(ANSI.dim)\(truncate(s.home, to: 20))\(ANSI.reset)"
                let row = "  \(cursor) \(ANSI.blue)◆\(ANSI.reset) \(nameTrunc)\(namePad)  \(home)"
                let visLen = 2 + 1 + 1 + 1 + 1 + 36 + 2 + 20
                let rowPad = String(repeating: " ", count: max(0, innerWidth - visLen))
                lines.append("\(ANSI.cyan)│\(ANSI.reset)\(row)\(rowPad)\(ANSI.cyan)│\(ANSI.reset)")
                rowCount += 1
            }

            if rowCount >= maxRows { break }
        }

        // Fill remaining rows
        while rowCount < maxRows {
            lines.append("\(ANSI.cyan)│\(ANSI.reset)\(String(repeating: " ", count: innerWidth))\(ANSI.cyan)│\(ANSI.reset)")
            rowCount += 1
        }

        // ── Status bar ──
        let statusTrunc = truncate(statusMessage, to: innerWidth - 2)
        let statusPad = String(repeating: " ", count: max(0, innerWidth - 2 - statusTrunc.count))
        lines.append("\(ANSI.cyan)│\(ANSI.reset) \(ANSI.dim)\(statusTrunc)\(statusPad) \(ANSI.reset)\(ANSI.cyan)│\(ANSI.reset)")

        // ── Help bar ──
        let helpText: String
        if view == .devices {
            helpText = " ↑↓ nav  spc toggle  +/- dim  [s]cenes  [r]efresh  [q]uit "
        } else {
            helpText = " ↑↓ nav  enter trigger  [d]evices  [r]efresh  [q]uit "
        }
        let helpTrunc = truncate(helpText, to: innerWidth)
        let helpPad = String(repeating: "─", count: max(0, innerWidth - helpTrunc.count))
        lines.append("\(ANSI.cyan)└\(ANSI.dim)\(helpTrunc)\(ANSI.reset)\(ANSI.cyan)\(helpPad)┘\(ANSI.reset)")

        // Output atomically
        let output = ANSI.clear + lines.joined(separator: "\n")
        print(output, terminator: "")
        fflush(stdout)
    }

    // MARK: - Helpers

    private func brightnessBar(_ brightness: Int?, on: Bool) -> String {
        guard let pct = brightness, on else {
            return "\(ANSI.dim)░░░░░░░░░░\(ANSI.reset)"
        }
        let filled = Int(Double(pct) / 10.0)
        let empty  = 10 - filled
        let bar    = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        return "\(ANSI.yellow)\(bar)\(ANSI.reset)"
    }

    private func truncate(_ str: String, to length: Int) -> String {
        guard str.count > length else { return str }
        return String(str.prefix(length - 1)) + "…"
    }
}
