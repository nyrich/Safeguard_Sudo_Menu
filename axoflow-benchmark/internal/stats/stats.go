// Package stats tracks throughput counters and renders live + final reports.
package stats

import (
	"fmt"
	"io"
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

// Snapshot is an immutable view of counters at a moment in time.
type Snapshot struct {
	Messages int64
	Bytes    int64
	Errors   int64
	Elapsed  time.Duration
}

func (s *Stats) snapshot() Snapshot {
	return Snapshot{
		Messages: s.Messages.Load(),
		Bytes:    s.Bytes.Load(),
		Errors:   s.Errors.Load(),
		Elapsed:  time.Since(s.start),
	}
}

// Reporter prints a live throughput line on the given interval until stopped.
// It reports the instantaneous EPS (delta since the previous tick) as well as
// the running average since start.
func (s *Stats) Reporter(w io.Writer, interval time.Duration, stop <-chan struct{}) {
	t := time.NewTicker(interval)
	defer t.Stop()
	var prev Snapshot
	prev = s.snapshot()
	for {
		select {
		case <-stop:
			return
		case <-t.C:
			cur := s.snapshot()
			dt := (cur.Elapsed - prev.Elapsed).Seconds()
			if dt <= 0 {
				dt = interval.Seconds()
			}
			instEPS := float64(cur.Messages-prev.Messages) / dt
			instMBs := float64(cur.Bytes-prev.Bytes) / dt / (1024 * 1024)
			avgEPS := float64(cur.Messages) / cur.Elapsed.Seconds()
			fmt.Fprintf(w, "[%6.1fs] sent=%-12d eps=%-12s avg_eps=%-12s %.2f MB/s errors=%d\n",
				cur.Elapsed.Seconds(), cur.Messages,
				humanRate(instEPS), humanRate(avgEPS), instMBs, cur.Errors)
			prev = cur
		}
	}
}

// FinalReport prints the summary block once the run is complete.
func (s *Stats) FinalReport(w io.Writer) Snapshot {
	cur := s.snapshot()
	secs := cur.Elapsed.Seconds()
	if secs <= 0 {
		secs = 1e-9
	}
	eps := float64(cur.Messages) / secs
	mbs := float64(cur.Bytes) / secs / (1024 * 1024)
	var avgLine float64
	if cur.Messages > 0 {
		avgLine = float64(cur.Bytes) / float64(cur.Messages)
	}

	fmt.Fprintln(w, "\n────────────────────────────────────────────────")
	fmt.Fprintln(w, " Axoflow Benchmark — Results")
	fmt.Fprintln(w, "────────────────────────────────────────────────")
	fmt.Fprintf(w, " Duration         : %.2f s\n", secs)
	fmt.Fprintf(w, " Messages sent    : %d\n", cur.Messages)
	fmt.Fprintf(w, " Bytes sent       : %.2f MB\n", float64(cur.Bytes)/(1024*1024))
	fmt.Fprintf(w, " Avg message size : %.0f bytes\n", avgLine)
	fmt.Fprintf(w, " Errors           : %d\n", cur.Errors)
	fmt.Fprintln(w, "────────────────────────────────────────────────")
	fmt.Fprintf(w, " THROUGHPUT       : %s events/sec\n", humanRate(eps))
	fmt.Fprintf(w, " THROUGHPUT       : %.2f MB/sec\n", mbs)
	fmt.Fprintln(w, "────────────────────────────────────────────────")
	return cur
}

// humanRate formats a per-second rate with thousands separators.
func humanRate(r float64) string {
	if r < 0 {
		r = 0
	}
	n := int64(r + 0.5)
	s := fmt.Sprintf("%d", n)
	// insert thousands separators
	out := make([]byte, 0, len(s)+len(s)/3)
	for i, c := range []byte(s) {
		if i > 0 && (len(s)-i)%3 == 0 {
			out = append(out, ',')
		}
		out = append(out, c)
	}
	return string(out)
}
