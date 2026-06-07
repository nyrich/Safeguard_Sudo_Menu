// Command axobench is a load generator that hammers real sample logs at an
// Axoflow / AxoRouter instance over syslog (UDP/TCP) or OTLP/gRPC and reports
// the sustained throughput in events per second.
//
// Example:
//
//	axobench -t 127.0.0.1:514  -transport udp  -d 30s -w 8
//	axobench -t 127.0.0.1:601  -transport tcp  -framing octet -d 30s
//	axobench -t 127.0.0.1:4317 -transport otlp -batch 500 -d 30s
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/nyrich/axoflow-benchmark/internal/loader"
	"github.com/nyrich/axoflow-benchmark/internal/sender"
	"github.com/nyrich/axoflow-benchmark/internal/stats"
	"github.com/nyrich/axoflow-benchmark/internal/syslogfmt"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

type options struct {
	target    string
	transport string
	logs      string
	workers   int
	duration  time.Duration
	count     int64
	rate      int
	format    string
	framing   string
	facility  int
	severity  int
	hostname  string
	appName   string
	batch     int
	otlpTLS   bool
	service   string
	interval  time.Duration
}

func parseFlags() options {
	var o options
	flag.StringVar(&o.target, "t", "", "target address host:port (AxoRouter source). Required.")
	flag.StringVar(&o.target, "target", "", "target address host:port (alias of -t)")
	flag.StringVar(&o.transport, "transport", "tcp", "transport: udp | tcp | otlp")
	flag.StringVar(&o.logs, "logs", "testdata/logs", "comma-separated log file(s) or dir(s) to replay")
	flag.IntVar(&o.workers, "w", runtime.NumCPU(), "number of concurrent workers/connections")
	flag.IntVar(&o.workers, "workers", runtime.NumCPU(), "number of concurrent workers (alias of -w)")
	flag.DurationVar(&o.duration, "d", 0, "run duration, e.g. 30s (0 = until -count or Ctrl-C)")
	flag.DurationVar(&o.duration, "duration", 0, "run duration (alias of -d)")
	flag.Int64Var(&o.count, "count", 0, "total messages to send (0 = unlimited)")
	flag.IntVar(&o.rate, "rate", 0, "target total events/sec (0 = unbounded / max throughput)")
	flag.StringVar(&o.format, "format", "rfc5424", "syslog wrapping: raw | rfc5424 | rfc3164")
	flag.StringVar(&o.framing, "framing", "octet", "TCP stream framing: newline | octet")
	flag.IntVar(&o.facility, "facility", 1, "syslog facility 0-23 (1 = user)")
	flag.IntVar(&o.severity, "severity", 6, "syslog severity 0-7 (6 = info)")
	flag.StringVar(&o.hostname, "hostname", "", "syslog HOSTNAME field (default: this host)")
	flag.StringVar(&o.appName, "appname", "axobench", "syslog APP-NAME / tag")
	flag.IntVar(&o.batch, "batch", 100, "OTLP log records per export request")
	flag.BoolVar(&o.otlpTLS, "otlp-tls", false, "use TLS for OTLP/gRPC (default plaintext)")
	flag.StringVar(&o.service, "service", "axobench", "OTLP service.name resource attribute")
	flag.DurationVar(&o.interval, "report-interval", time.Second, "live progress report cadence")
	flag.Parse()
	return o
}

func run() error {
	o := parseFlags()
	if o.target == "" {
		flag.Usage()
		return fmt.Errorf("missing required -t/-target")
	}
	if o.workers < 1 {
		o.workers = 1
	}
	// Safety net: if no stop condition is given, default to a 30s run so we
	// don't accidentally hammer forever.
	if o.duration == 0 && o.count == 0 {
		o.duration = 30 * time.Second
		fmt.Fprintln(os.Stderr, "note: no -d/-count given, defaulting to -d 30s")
	}

	format, err := syslogfmt.ParseFormat(o.format)
	if err != nil {
		return err
	}
	framing, err := syslogfmt.ParseFraming(o.framing)
	if err != nil {
		return err
	}

	// Load the corpus of real log lines into memory.
	corpus, err := loader.Load(splitCSV(o.logs))
	if err != nil {
		return err
	}
	fmt.Printf("Loaded %d log lines (avg %.0f bytes) from %s\n",
		len(corpus.Lines), corpus.AvgLineBytes(), o.logs)

	st := stats.New()
	builder, err := sender.NewBuilder(sender.Config{
		Transport:   o.transport,
		Addr:        o.target,
		Format:      format,
		Framing:     framing,
		Facility:    o.facility,
		Severity:    o.severity,
		Hostname:    o.hostname,
		AppName:     o.appName,
		BatchSize:   o.batch,
		ServiceName: o.service,
		Insecure:    !o.otlpTLS,
		Stats:       st,
	})
	if err != nil {
		return err
	}

	// Pre-create all senders so a bad target fails fast before we start timing.
	senders := make([]sender.Sender, 0, o.workers)
	for i := 0; i < o.workers; i++ {
		s, err := builder.New()
		if err != nil {
			for _, prev := range senders {
				_ = prev.Close()
			}
			return fmt.Errorf("worker %d: %w", i, err)
		}
		senders = append(senders, s)
	}

	// Stop on SIGINT/SIGTERM.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	fmt.Printf("Hammering %s via %s with %d workers", o.target, o.transport, o.workers)
	if o.rate > 0 {
		fmt.Printf(" @ target %d eps", o.rate)
	}
	if o.duration > 0 {
		fmt.Printf(" for %s", o.duration)
	}
	if o.count > 0 {
		fmt.Printf(" (%d messages)", o.count)
	}
	fmt.Print(" ...\n\n")

	// Reset the clock right before workers start so setup time isn't counted.
	// Senders hold this same *Stats pointer, so Reset (not a new instance) is
	// what keeps their counters and the reporter in sync.
	st.Reset()

	var deadline time.Time
	if o.duration > 0 {
		deadline = time.Now().Add(o.duration)
	}
	var remaining *atomic.Int64
	if o.count > 0 {
		remaining = &atomic.Int64{}
		remaining.Store(o.count)
	}
	var perWorkerInterval time.Duration
	if o.rate > 0 {
		perWorkerInterval = time.Duration(float64(time.Second) * float64(o.workers) / float64(o.rate))
	}

	// Live reporter.
	repStop := make(chan struct{})
	go st.Reporter(os.Stdout, o.interval, repStop)

	var wg sync.WaitGroup
	for i := 0; i < o.workers; i++ {
		wg.Add(1)
		go func(id int, s sender.Sender) {
			defer wg.Done()
			workerLoop(ctx, s, corpus, id, deadline, remaining, perWorkerInterval)
		}(i, senders[i])
	}
	wg.Wait()
	close(repStop)

	snap := st.FinalReport(os.Stdout)
	if snap.Errors > 0 {
		fmt.Fprintf(os.Stderr, "\nwarning: %d send errors (check target reachability/transport)\n", snap.Errors)
	}
	return nil
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

	// Check the deadline only every so often to keep the hot loop tight.
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
			// Transport down (e.g. server gone). Stop this worker; the error
			// is already recorded in stats.
			return
		}
		if sinceFlush++; sinceFlush >= flushEvery {
			_ = s.Flush()
			sinceFlush = 0
		}
	}
}

func splitCSV(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == ',' {
			if seg := trim(s[start:i]); seg != "" {
				out = append(out, seg)
			}
			start = i + 1
		}
	}
	if seg := trim(s[start:]); seg != "" {
		out = append(out, seg)
	}
	return out
}

func trim(s string) string {
	for len(s) > 0 && (s[0] == ' ' || s[0] == '\t') {
		s = s[1:]
	}
	for len(s) > 0 && (s[len(s)-1] == ' ' || s[len(s)-1] == '\t') {
		s = s[:len(s)-1]
	}
	return s
}
