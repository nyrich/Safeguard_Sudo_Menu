// Package stats holds the atomic throughput counters shared across all worker
// goroutines. Reporting/aggregation lives in the engine package.
package stats

import (
	"sync/atomic"
	"time"
)

// Stats holds atomic counters shared across all worker goroutines.
type Stats struct {
	Messages atomic.Int64 // successfully sent messages (events)
	Bytes    atomic.Int64 // payload bytes sent
	Errors   atomic.Int64 // send errors
	start    time.Time
}

// New creates a Stats with the start clock running now.
func New() *Stats {
	return &Stats{start: time.Now()}
}

// Reset zeroes the counters and restarts the clock. Call this immediately
// before launching workers so connection setup time isn't counted.
func (s *Stats) Reset() {
	s.Messages.Store(0)
	s.Bytes.Store(0)
	s.Errors.Store(0)
	s.start = time.Now()
}

// Elapsed returns the time since the clock last started (New or Reset).
func (s *Stats) Elapsed() time.Duration { return time.Since(s.start) }

// AddOK records a successful send of n bytes.
func (s *Stats) AddOK(bytes int) {
	s.Messages.Add(1)
	s.Bytes.Add(int64(bytes))
}

// AddOKN records a successful send of n messages totalling bytes (batch path).
func (s *Stats) AddOKN(n, bytes int) {
	s.Messages.Add(int64(n))
	s.Bytes.Add(int64(bytes))
}

// AddErr records a failed send.
func (s *Stats) AddErr() { s.Errors.Add(1) }

// AddErrN records n failed sends.
func (s *Stats) AddErrN(n int) { s.Errors.Add(int64(n)) }
