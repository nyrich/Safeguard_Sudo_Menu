# axobench GUI — desktop app (macOS & Windows)

A native desktop UI for the Axoflow log benchmark tester, built with
[Wails v2](https://wails.io). It wraps the same engine the `axobench` CLI uses,
so it produces the same numbers — with live **events/sec** and **MB/sec** charts,
form-driven configuration, and Start/Stop controls.

![layout](https://img.shields.io/badge/UI-Wails%20v2-blue) — config panel on the
left, live stats + chart on the right, final summary on completion.

## Architecture

The GUI is split so the logic is testable on any platform:

| File | Imports Wails? | Role |
|------|----------------|------|
| `main.go` | **yes** | Thin shell: embeds the frontend, wires the Wails runtime, binds `app.App`. |
| `app/app.go` | no | All binding logic (`Start`/`Stop`/`Defaults`/`BrowseLogs`), maps the form to `engine.Config`, emits events. Pure Go, unit-tested. |
| `frontend/` | — | Vite + vanilla JS + Chart.js dashboard. |
| `../internal/engine` | no | Shared benchmark core (also used by the CLI). |

`app` is a separate Go module (`go.mod` here) so the repo's root `go build ./...`
stays clean without GUI/CGO toolchains. The `internal/engine` import is allowed
because the import path shares the module prefix.

## Prerequisites

- **Go 1.24+**
- **Node.js 18+** (for the frontend build; the Wails CLI runs it for you)
- **Wails CLI**: `go install github.com/wailsapp/wails/v2/cmd/wails@latest`
- Platform webview (already present on stock systems):
  - **macOS** — built-in WebKit (just install Xcode command-line tools: `xcode-select --install`)
  - **Windows** — [WebView2 runtime](https://developer.microsoft.com/microsoft-edge/webview2/) (preinstalled on Win11; auto-installed by the Wails installer otherwise)

Run `wails doctor` to confirm your environment.

## Build

From this `gui/` directory:

```bash
# Development (hot-reload, opens the app window)
wails dev

# Production app bundle
wails build
```

Outputs land in `build/bin/`:

| OS | Artifact |
|----|----------|
| **macOS** | `build/bin/axobench-gui.app` (drag to /Applications) |
| **Windows** | `build/bin/axobench-gui.exe` |

### macOS notes
```bash
# Universal binary (Apple Silicon + Intel)
wails build -platform darwin/universal

# Signed + notarized DMG (needs an Apple Developer cert) — see Wails docs
```

### Windows notes
```powershell
wails build -platform windows/amd64
# Add an NSIS installer:
wails build -nsis
```

> **Cross-compiling note:** Wails apps use each OS's native webview via CGO, so
> build macOS apps on a Mac and Windows apps on Windows. They cannot be reliably
> cross-compiled from Linux.

## Using it

1. Enter the **target** AxoRouter address (e.g. `10.0.0.5:514`).
2. Pick a **transport** (Syslog TCP/UDP or OTLP/gRPC). Transport-specific fields
   (TCP framing, OTLP batch/TLS) show/hide automatically.
3. Point **Log source** at a file or directory of sample logs (use **Browse…**,
   or the bundled `../testdata/logs` after running `make logs` in the parent).
4. Set workers / duration / target rate, then **Start**.
5. Watch the live EPS + MB/s chart; the **Final results** panel shows the headline
   throughput when the run ends (or when you hit **Stop**).

## Tests

```bash
go test ./app/   # end-to-end: drives Start against a local TCP sink, asserts the Result
```
