// Command axobench-gui is the cross-platform desktop UI for the Axoflow log
// benchmark tester. It is a thin Wails shell: all benchmark logic lives in the
// platform-independent ./app and ../internal/engine packages.
package main

import (
	"context"
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	wruntime "github.com/wailsapp/wails/v2/pkg/runtime"

	"github.com/nyrich/axobench/gui/app"
)

//go:embed all:frontend/dist
var assets embed.FS

// wailsEmitter implements app.Emitter using the Wails runtime.
type wailsEmitter struct{ ctx context.Context }

func (w wailsEmitter) Emit(event string, data ...interface{}) {
	wruntime.EventsEmit(w.ctx, event, data...)
}

func (w wailsEmitter) BrowseDir(title string) (string, error) {
	return wruntime.OpenDirectoryDialog(w.ctx, wruntime.OpenDialogOptions{Title: title})
}

func main() {
	a := app.New()

	err := wails.Run(&options.App{
		Title:  "axobench — Axoflow Benchmark Tester",
		Width:  1180,
		Height: 860,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		OnStartup: func(ctx context.Context) {
			a.Bind(ctx, wailsEmitter{ctx: ctx})
		},
		Bind: []interface{}{a},
	})
	if err != nil {
		println("error:", err.Error())
	}
}
