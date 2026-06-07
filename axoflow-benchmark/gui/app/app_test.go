package app

import (
	"bufio"
	"context"
	"net"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/nyrich/axoflow-benchmark/internal/engine"
)

// fakeEmitter captures events and signals when a terminal event arrives.
type fakeEmitter struct {
	mu       sync.Mutex
	done     chan engine.Result
	errs     chan string
	statHits atomic.Int64
}

func newFakeEmitter() *fakeEmitter {
	return &fakeEmitter{done: make(chan engine.Result, 1), errs: make(chan string, 1)}
}

func (f *fakeEmitter) Emit(event string, data ...interface{}) {
	switch event {
	case EventStats:
		f.statHits.Add(1)
	case EventDone:
		if len(data) > 0 {
			if r, ok := data[0].(engine.Result); ok {
				f.done <- r
			}
		}
	case EventError:
		if len(data) > 0 {
			f.errs <- data[0].(string)
		}
	}
}

func (f *fakeEmitter) BrowseDir(string) (string, error) { return "/tmp/picked", nil }

func TestStartRunsAndReportsResult(t *testing.T) {
	// Minimal TCP sink that counts newline-delimited frames.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	var recv atomic.Int64
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				sc := bufio.NewScanner(c)
				sc.Buffer(make([]byte, 0, 64*1024), 1<<20)
				for sc.Scan() {
					recv.Add(1)
				}
			}(c)
		}
	}()

	// A tiny corpus on disk.
	dir := t.TempDir()
	logFile := filepath.Join(dir, "sample.log")
	if err := os.WriteFile(logFile, []byte("line one\nline two\nline three\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	a := New()
	fe := newFakeEmitter()
	a.Bind(context.Background(), fe)

	const want = 3000
	cfg := RunConfig{
		Target:    ln.Addr().String(),
		Transport: "tcp",
		Logs:      logFile,
		Workers:   2,
		Count:     want,
		Format:    "rfc5424",
		Framing:   "newline",
	}
	if err := a.Start(cfg); err != nil {
		t.Fatalf("Start: %v", err)
	}
	if !a.Running() {
		// It may already be running; tolerate either since Start is async.
	}

	select {
	case res := <-fe.done:
		if res.Messages != want {
			t.Fatalf("Messages = %d, want %d", res.Messages, want)
		}
		if res.AvgEPS <= 0 {
			t.Fatalf("AvgEPS should be > 0, got %f", res.AvgEPS)
		}
		if res.Errors != 0 {
			t.Fatalf("unexpected errors: %d", res.Errors)
		}
	case e := <-fe.errs:
		t.Fatalf("unexpected error event: %s", e)
	case <-time.After(15 * time.Second):
		t.Fatal("timed out waiting for done event")
	}

	if a.Running() {
		t.Fatal("engine should be idle after completion")
	}
	// Give the sink a moment to drain, then confirm it received what we sent.
	time.Sleep(200 * time.Millisecond)
	if got := recv.Load(); got != want {
		t.Fatalf("sink received %d, want %d", got, want)
	}
}

func TestStartRejectsConcurrentRuns(t *testing.T) {
	a := New()
	a.Bind(context.Background(), newFakeEmitter())

	// Point at a black-hole TCP listener so the first run stays busy briefly.
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			_ = c
		}
	}()

	dir := t.TempDir()
	logFile := filepath.Join(dir, "s.log")
	_ = os.WriteFile(logFile, []byte("a\nb\n"), 0o644)

	cfg := RunConfig{
		Target: ln.Addr().String(), Transport: "tcp", Logs: logFile,
		Workers: 1, DurationSec: 2, Format: "raw", Framing: "newline",
	}
	if err := a.Start(cfg); err != nil {
		t.Fatalf("first Start: %v", err)
	}
	// Wait until it's actually running.
	deadline := time.Now().Add(2 * time.Second)
	for !a.Running() && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if err := a.Start(cfg); err == nil {
		t.Fatal("expected error starting a second concurrent run")
	}
	a.Stop()
}

func TestDefaults(t *testing.T) {
	d := New().Defaults()
	if d.Transport != "tcp" || d.Format != "rfc5424" || d.Workers < 1 {
		t.Fatalf("unexpected defaults: %+v", d)
	}
}
