// Package engine is the reusable benchmark core shared by the CLI (axobench)
// and the desktop GUI. It loads a corpus, drives a pool of worker goroutines
// that hammer logs at the target, streams periodic Snapshots to a callback, and
// returns a final Result. It owns no I/O or presentation concerns.
package engine

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/nyrich/axoflow-benchmark/internal/loader"
	"github.com/nyrich/axoflow-benchmark/internal/sender"
	"github.com/nyrich/axoflow-benchmark/internal/stats"
	"github.com/nyrich/axoflow-benchmark/internal/syslogfmt"
)

// Config fully describes a benchmark run. String enums are parsed by Run so
// callers (CLI flags, GUI form) can pass raw values.
type Config struct {
	Target         string        // host:port
	Transport      string        // udp | tcp | otlp
	Logs           []string      // file(s)/dir(s) to replay
	Workers        int           // concurrent connections
	Duration       time.Duration // 0 = until Count or Stop()
	Count          int64         // 0 = unlimited
	Rate           int           // target total eps; 0 = max
	Format         string        // raw | rfc5424 | rfc3164
	Framing        string        // newline | octet (tcp)
	Facility       int           // 0-23
	Severity       int           // 0-7
	Hostname       string        // syslog HOSTNAME (default: this host)
	AppName        string        // syslog APP-NAME / tag
	Batch          int           // OTLP records per export
	OTLPTLS        bool          // TLS for OTLP/gRPC (default plaintext)
	Service        string        // OTLP service.name
	ReportInterval time.Duration // snapshot cadence (default 1s)
}

// Snapshot is a point-in-time view emitted on each report tick.
type Snapshot struct {
	ElapsedSec float64 `json:"elapsedSec"`
	Messages   int64   `json:"messages"`
	Bytes      int64   `json:"bytes"`
	Errors     int64   `json:"errors"`
	InstEPS    float64 `json:"instEps"`
	AvgEPS     float64 `json:"avgEps"`
	InstMBps   float64 `json:"instMBps"`
	AvgMBps    float64 `json:"avgMBps"`
}

// Result is the final summary of a completed (or stopped) run.
type Result struct {
	DurationSec float64 `json:"durationSec"`
	Messages    int64   `json:"messages"`
	Bytes       int64   `json:"bytes"`
	Errors      int64   `json:"errors"`
	AvgEPS      float64 `json:"avgEps"`
	AvgMBps     float64 `json:"avgMBps"`
	AvgMsgBytes float64 `json:"avgMsgBytes"`
	LinesLoaded int     `json:"linesLoaded"`
}

// Engine runs at most one benchmark at a time and supports cooperative Stop.
type Engine struct {
	mu      sync.Mutex
	cancel  context.CancelFunc
	running bool
}

// New returns an idle Engine.
func New() *Engine { return &Engine{} }

// Running reports whether a benchmark is currently in progress.
func (e *Engine) Running() bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.running
}

// Stop cancels the in-progress run, if any. Run returns shortly after.
func (e *Engine) Stop() {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.cancel != nil {
		e.cancel()
	}
}

// Run executes a benchmark to completion, invoking onSnap (may be nil) on each
// report tick. It blocks until the run finishes, errors, or is stopped/cancelled.
func (e *Engine) Run(parent context.Context, cfg Config, onSnap func(Snapshot)) (Result, error) {
	e.mu.Lock()
	if e.running {
		e.mu.Unlock()
		return Result{}, errors.New("a benchmark is already running")
	}
	ctx, cancel := context.WithCancel(parent)
	e.cancel = cancel
	e.running = true
	e.mu.Unlock()
	defer func() {
		cancel()
		e.mu.Lock()
		e.running = false
		e.cancel = nil
		e.mu.Unlock()
	}()

	if cfg.Workers < 1 {
		cfg.Workers = 1
	}
	if cfg.ReportInterval <= 0 {
		cfg.ReportInterval = time.Second
	}

	format, err := syslogfmt.ParseFormat(cfg.Format)
	if err != nil {
		return Result{}, err
	}
	framing, err := syslogfmt.ParseFraming(cfg.Framing)
	if err != nil {
		return Result{}, err
	}

	corpus, err := loader.Load(cfg.Logs)
	if err != nil {
		return Result{}, err
	}

	st := stats.New()
	builder, err := sender.NewBuilder(sender.Config{
		Transport:   cfg.Transport,
		Addr:        cfg.Target,
		Format:      format,
		Framing:     framing,
		Facility:    cfg.Facility,
		Severity:    cfg.Severity,
		Hostname:    cfg.Hostname,
		AppName:     cfg.AppName,
		BatchSize:   cfg.Batch,
		ServiceName: cfg.Service,
		Insecure:    !cfg.OTLPTLS,
		Stats:       st,
	})
	if err != nil {
		return Result{}, err
	}

	// Pre-create senders so a bad target fails fast, before timing starts.
	senders := make([]sender.Sender, 0, cfg.Workers)
	for i := 0; i < cfg.Workers; i++ {
		s, err := builder.New()
		if err != nil {
			for _, prev := range senders {
				_ = prev.Close()
			}
			return Result{}, fmt.Errorf("worker %d: %w", i, err)
		}
		senders = append(senders, s)
	}

	var deadline time.Time
	if cfg.Duration > 0 {
		deadline = time.Now().Add(cfg.Duration)
	}
	var remaining *atomic.Int64
	if cfg.Count > 0 {
		remaining = &atomic.Int64{}
		remaining.Store(cfg.Count)
	}
	var perWorkerInterval time.Duration
	if cfg.Rate > 0 {
		perWorkerInterval = time.Duration(float64(time.Second) * float64(cfg.Workers) / float64(cfg.Rate))
	}

	// Start the clock right before launching workers so setup isn't counted.
	st.Reset()

	var wg sync.WaitGroup
	for i := 0; i < cfg.Workers; i++ {
		wg.Add(1)
		go func(id int, s sender.Sender) {
			defer wg.Done()
			workerLoop(ctx, s, corpus, id, deadline, remaining, perWorkerInterval)
		}(i, senders[i])
	}

	finished := make(chan struct{})
	go func() { wg.Wait(); close(finished) }()

	// Reporter loop: emit snapshots until the workers finish.
	prev := snapshotNow(st)
	ticker := time.NewTicker(cfg.ReportInterval)
	defer ticker.Stop()
loop:
	for {
		select {
		case <-finished:
			break loop
		case <-ticker.C:
			cur := snapshotNow(st)
			prev = withRates(cur, prev)
			if onSnap != nil {
				onSnap(prev)
			}
		}
	}
	<-finished

	return finalResult(st, corpus), nil
}

// snapshotNow reads the counters into a Snapshot (rates left zero).
func snapshotNow(st *stats.Stats) Snapshot {
	return Snapshot{
		ElapsedSec: st.Elapsed().Seconds(),
		Messages:   st.Messages.Load(),
		Bytes:      st.Bytes.Load(),
		Errors:     st.Errors.Load(),
	}
}

// withRates fills instantaneous (vs prev) and running-average rates.
func withRates(cur, prev Snapshot) Snapshot {
	dt := cur.ElapsedSec - prev.ElapsedSec
	if dt <= 0 {
		dt = 1e-9
	}
	cur.InstEPS = float64(cur.Messages-prev.Messages) / dt
	cur.InstMBps = float64(cur.Bytes-prev.Bytes) / dt / (1024 * 1024)
	if cur.ElapsedSec > 0 {
		cur.AvgEPS = float64(cur.Messages) / cur.ElapsedSec
		cur.AvgMBps = float64(cur.Bytes) / cur.ElapsedSec / (1024 * 1024)
	}
	return cur
}

func finalResult(st *stats.Stats, corpus *loader.Corpus) Result {
	secs := st.Elapsed().Seconds()
	if secs <= 0 {
		secs = 1e-9
	}
	msgs := st.Messages.Load()
	bytes := st.Bytes.Load()
	var avgMsg float64
	if msgs > 0 {
		avgMsg = float64(bytes) / float64(msgs)
	}
	return Result{
		DurationSec: secs,
		Messages:    msgs,
		Bytes:       bytes,
		Errors:      st.Errors.Load(),
		AvgEPS:      float64(msgs) / secs,
		AvgMBps:     float64(bytes) / secs / (1024 * 1024),
		AvgMsgBytes: avgMsg,
		LinesLoaded: len(corpus.Lines),
	}
}

// workerLoop replays the corpus until a stop condition fires.
func workerLoop(ctx context.Context, s sender.Sender, corpus *loader.Corpus,
	startIdx int, deadline time.Time, remaining *atomic.Int64, interval time.Duration) {

	defer s.Close()

	n := len(corpus.Lines)
	idx := startIdx % n
	hasDeadline := !deadline.IsZero()
	const flushEvery = 512
	sinceFlush := 0
	next := time.Now()

	const checkMask = 0xFF
	iter := 0

	for {
		if ctx.Err() != nil {
			return
		}
		if remaining != nil && remaining.Add(-1) < 0 {
			return
		}
		if hasDeadline && iter&checkMask == 0 && time.Now().After(deadline) {
			return
		}
		iter++

		if interval > 0 {
			now := time.Now()
			if now.Before(next) {
				time.Sleep(next.Sub(now))
			}
			next = next.Add(interval)
		}

		line := corpus.Lines[idx]
		idx++
		if idx >= n {
			idx = 0
		}

		if err := s.Send(line, time.Now()); err != nil {
			return
		}
		if sinceFlush++; sinceFlush >= flushEvery {
			_ = s.Flush()
			sinceFlush = 0
		}
	}
}
