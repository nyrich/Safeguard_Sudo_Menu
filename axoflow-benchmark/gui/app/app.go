// Package app holds the GUI's binding logic, deliberately free of any Wails
// imports so it can be built and unit-tested on any platform. The Wails layer
// (main.go) injects an Emitter and binds these methods to the frontend.
package app

import (
	"context"
	"errors"
	"runtime"
	"strings"
	"time"

	"github.com/nyrich/axobench/internal/engine"
)

// Emitter abstracts the Wails runtime so the core stays platform-independent.
type Emitter interface {
	// Emit sends a named event with an optional payload to the frontend.
	Emit(event string, data ...interface{})
	// BrowseDir opens a native directory picker and returns the chosen path.
	BrowseDir(title string) (string, error)
}

// Event names emitted to the frontend.
const (
	EventStats = "stats" // engine.Snapshot, on each report tick
	EventDone  = "done"  // engine.Result, when a run finishes
	EventError = "error" // string message, when a run fails to start/run
)

// RunConfig is the JSON-friendly form the frontend submits. Durations are in
// seconds (0 = unbounded, stopped via Stop) to keep the UI simple.
type RunConfig struct {
	Target      string `json:"target"`
	Transport   string `json:"transport"`
	Logs        string `json:"logs"`
	Workers     int    `json:"workers"`
	DurationSec int    `json:"durationSec"`
	Count       int64  `json:"count"`
	Rate        int    `json:"rate"`
	Format      string `json:"format"`
	Framing     string `json:"framing"`
	Facility    int    `json:"facility"`
	Severity    int    `json:"severity"`
	Batch       int    `json:"batch"`
	OTLPTLS     bool   `json:"otlpTLS"`
	AppName     string `json:"appName"`
	Service     string `json:"service"`
}

// App is the object bound into the frontend (window.go.app.App.*).
type App struct {
	ctx     context.Context
	emitter Emitter
	eng     *engine.Engine
}

// New returns an App with an idle engine.
func New() *App {
	return &App{ctx: context.Background(), eng: engine.New()}
}

// Bind wires the runtime context and emitter; called once at startup.
func (a *App) Bind(ctx context.Context, e Emitter) {
	a.ctx = ctx
	a.emitter = e
}

// Defaults returns sensible initial form values for the UI.
func (a *App) Defaults() RunConfig {
	return RunConfig{
		Target:      "127.0.0.1:514",
		Transport:   "tcp",
		Logs:        "testdata/logs",
		Workers:     runtime.NumCPU(),
		DurationSec: 30,
		Format:      "rfc5424",
		Framing:     "octet",
		Facility:    1,
		Severity:    6,
		Batch:       100,
		AppName:     "axobench",
		Service:     "axobench",
	}
}

// Running reports whether a benchmark is in progress.
func (a *App) Running() bool { return a.eng.Running() }

// Stop cancels the current run; the engine emits a Done shortly after.
func (a *App) Stop() { a.eng.Stop() }

// BrowseLogs opens a native folder picker and returns the selection.
func (a *App) BrowseLogs() (string, error) {
	if a.emitter == nil {
		return "", nil
	}
	return a.emitter.BrowseDir("Select a log file or directory to replay")
}

// Start validates the config and launches the benchmark in the background,
// streaming "stats" events and a terminal "done"/"error" event. It returns
// quickly; connection/validation failures arrive via the "error" event.
func (a *App) Start(rc RunConfig) error {
	if a.eng.Running() {
		return errors.New("a benchmark is already running")
	}
	cfg := a.toEngineConfig(rc)
	go func() {
		res, err := a.eng.Run(a.ctx, cfg, func(s engine.Snapshot) {
			a.emit(EventStats, s)
		})
		if err != nil {
			a.emit(EventError, err.Error())
			return
		}
		a.emit(EventDone, res)
	}()
	return nil
}

// toEngineConfig maps the UI form onto the engine's Config.
func (a *App) toEngineConfig(rc RunConfig) engine.Config {
	return engine.Config{
		Target:    strings.TrimSpace(rc.Target),
		Transport: rc.Transport,
		Logs:      splitCSV(rc.Logs),
		Workers:   rc.Workers,
		Duration:  time.Duration(rc.DurationSec) * time.Second,
		Count:     rc.Count,
		Rate:      rc.Rate,
		Format:    rc.Format,
		Framing:   rc.Framing,
		Facility:  rc.Facility,
		Severity:  rc.Severity,
		Batch:     rc.Batch,
		OTLPTLS:   rc.OTLPTLS,
		AppName:   rc.AppName,
		Service:   rc.Service,
	}
}

func (a *App) emit(event string, data ...interface{}) {
	if a.emitter != nil {
		a.emitter.Emit(event, data...)
	}
}

func splitCSV(s string) []string {
	var out []string
	for _, seg := range strings.Split(s, ",") {
		if seg = strings.TrimSpace(seg); seg != "" {
			out = append(out, seg)
		}
	}
	return out
}
