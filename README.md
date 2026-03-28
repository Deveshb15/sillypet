# SillyPet

A pixel art desktop pet that lives on your macOS screen and monitors your AI coding agents. When Claude Code or Codex needs your attention, your pet sprints to your cursor to let you know.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

[![Download SillyPet](https://img.shields.io/badge/Download-SillyPet%20v0.1.0-brightgreen?style=for-the-badge&logo=apple)](https://github.com/Deveshb15/sillypet/releases/latest/download/SillyPet.dmg)

## What it does

SillyPet is a native macOS menu bar app that runs a desktop pet — a 16x16 pixel art animal rendered with SpriteKit. Choose from 10 pets on first launch: **Shiba Inu, Cat, Rabbit, Fox, Penguin, Hamster, Owl, Frog, Duck, or Panda**. The pet monitors your Claude Code and Codex sessions in real time and reacts to what's happening:

| Agent state | Pet behavior |
|---|---|
| No sessions running | Wanders to a screen edge and sleeps |
| Agent is working | Sits and watches |
| Agent needs permission | Sprints to your cursor, shows speech bubble |
| Task completed | Runs to you, celebrates with confetti |
| Session started | Walks over and greets you |
| Error | Alert animation with warning bubble |

After delivering a notification, the dog walks back to the side of the screen and either sleeps (nothing running) or wanders around (sessions still active).

## How it monitors

**Claude Code** — two methods, both active simultaneously:

1. **JSONL transcript tailing** (works immediately for all sessions): reads `~/.claude/sessions/*.json` to discover active sessions, then tails their JSONL transcripts. Detects `stop_reason=end_turn` (task complete) and `stop_reason=tool_use` (working).

2. **Hook-based events** (works after session restart): auto-installs hooks in `~/.claude/settings.json` for `Notification`, `TaskCompleted`, `SessionStart`, `SessionEnd`, and `Stop` events. A shell script writes event JSON to `/tmp/sillypet-events/`, which the app watches via FSEvents.

**Codex** — tails JSONL session files in `~/.codex/sessions/YYYY/MM/DD/` and parses events: `task_started`, `task_complete`, `agent_message`, `function_call`, `turn_aborted`.

## Install

1. Download `SillyPet.dmg` from the [latest release](https://github.com/Deveshb15/sillypet/releases/latest)
2. Open the DMG and drag `SillyPet.app` to **Applications**
3. Pick your pet on first launch!

> **macOS may block the app** since it isn't notarized (this is normal for open-source apps). To fix:
>
> **System Settings** → **Privacy & Security** → scroll down to **Security** → click **"Open Anyway"** next to SillyPet

## Build from source

Requires macOS 14+ and Swift 5.9+.

```bash
# Build and create the app bundle
make

# Build and launch
make run

# Create a DMG for distribution
make dmg

# Development (debug build, runs directly)
make dev
```

## Project structure

```
Sources/SillyPet/
├── App/
│   ├── SillyPetApp.swift        # @main entry, MenuBarExtra
│   └── AppDelegate.swift       # Pet lifecycle, event routing
├── Pet/
│   ├── Pet.swift               # Pet controller (window + scene + state + movement)
│   ├── PetWindow.swift         # Transparent floating NSPanel
│   ├── PetScene.swift          # SpriteKit scene (sprite, bubbles, confetti)
│   ├── PetSprites.swift        # Pixel art frames + texture generation
│   ├── PetStateMachine.swift   # State transitions and behavior timing
│   ├── PetMovement.swift       # Movement, cursor tracking, screen edges
│   └── SpeechBubble.swift      # Animated speech bubble overlay
├── Monitor/
│   ├── AgentEvent.swift        # Unified event model
│   ├── AgentMonitor.swift      # Monitor protocol
│   ├── ClaudeMonitor.swift     # Claude Code (JSONL + hooks)
│   └── CodexMonitor.swift      # Codex (JSONL tailing)
└── UI/
    └── MenuBarView.swift       # Menu bar dropdown (sessions, events, test buttons)
```

## Customizing the pixel art

All sprites live in `Sources/SillyPet/Pet/PetSprites.swift` as plain string arrays — each character maps to a color:

```
. = transparent    o = orange (body)    d = dark brown (ears)
w = white (face)   b = black (eyes)     p = pink (tongue)
t = tail orange
```

Each animation state (idle, walk, run, sit, sleep, celebrate, alert) has an array of frames. Edit the strings to change how the dog looks — the pixel art is rendered at 5x scale (80x80pt on screen) with nearest-neighbor filtering for crisp edges.

## Testing without running agents

Click the pawprint menu bar icon and use **Test Events** to trigger:
- **Permission Request** — dog sprints to your cursor with a speech bubble
- **Task Completed** — dog runs to you and celebrates with confetti
- **Session Start** — dog greets you

## How it's built

- **AppKit** (`NSPanel`) for the transparent, borderless, floating window
- **SpriteKit** for sprite animation, particle effects (confetti, Zzz), and rendering
- **SwiftUI** (`MenuBarExtra`) for the menu bar dropdown
- **No external dependencies** — pure Apple frameworks
- `LSUIElement = true` — no dock icon, no Cmd+Tab entry

Inspired by [DockItty](https://www.dockitty.app/), [Notchi](https://notchi.app/), and [lil-agents](https://github.com/ryanstephen/lil-agents).

## License

MIT
