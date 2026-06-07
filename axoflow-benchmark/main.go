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
	"strings"
	"syscall"
	"time"

	"github.com/nyrich/axobench/internal/engine"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	var (
		cfg     engine.Config
		logsCSV string
	)
	flag.StringVar(&cfg.Target, "t", "", "target address host:port (AxoRouter source). Required.")
	flag.StringVar(&cfg.Target, "target", "", "target address host:port (alias of -t)")
	flag.StringVar(&cfg.Transport, "transport", "tcp", "transport: udp | tcp | otlp")
	flag.StringVar(&logsCSV, "logs", "testdata/logs", "comma-separated log file(s) or dir(s) to replay")
	flag.IntVar(&cfg.Workers, "w", runtime.NumCPU(), "number of concurrent workers/connections")
	flag.IntVar(&cfg.Workers, "workers", runtime.NumCPU(), "number of concurrent workers (alias of -w)")
	flag.DurationVar(&cfg.Duration, "d", 0, "run duration, e.g. 30s (0 = until -count or Ctrl-C)")
	flag.DurationVar(&cfg.Duration, "duration", 0, "run duration (alias of -d)")
	flag.Int64Var(&cfg.Count, "count", 0, "total messages to send (0 = unlimited)")
	flag.IntVar(&cfg.Rate, "rate", 0, "target total events/sec (0 = unbounded / max throughput)")
	flag.StringVar(&cfg.Format, "format", "rfc5424", "syslog wrapping: raw | rfc5424 | rfc3164")
	flag.StringVar(&cfg.Framing, "framing", "octet", "TCP stream framing: newline | octet")
	flag.IntVar(&cfg.Facility, "facility", 1, "syslog facility 0-23 (1 = user)")
	flag.IntVar(&cfg.Severity, "severity", 6, "syslog severity 0-7 (6 = info)")
	flag.StringVar(&cfg.Hostname, "hostname", "", "syslog HOSTNAME field (default: this host)")
	flag.StringVar(&cfg.AppName, "appname", "axobench", "syslog APP-NAME / tag")
	flag.IntVar(&cfg.Batch, "batch", 100, "OTLP log records per export request")
	flag.BoolVar(&cfg.OTLPTLS, "otlp-tls", false, "use TLS for OTLP/gRPC (default plaintext)")
	flag.StringVar(&cfg.Service, "service", "axobench", "OTLP service.name resource attribute")
	flag.DurationVar(&cfg.ReportInterval, "report-interval", time.Second, "live progress report cadence")
	flag.Parse()

	if cfg.Target == "" {
		flag.Usage()
		return fmt.Errorf("missing required -t/-target")
	}
	cfg.Logs = splitCSV(logsCSV)

	// Safety net: with no stop condition, default to a 30s run.
	if cfg.Duration == 0 && cfg.Count == 0 {
		cfg.Duration = 30 * time.Second
		fmt.Fprintln(os.Stderr, "note: no -d/-count given, defaulting to -d 30s")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	fmt.Printf("Hammering %s via %s with %d workers", cfg.Target, cfg.Transport, cfg.Workers)
	if cfg.Rate > 0 {
		fmt.Printf(" @ target %d eps", cfg.Rate)
	}
	if cfg.Duration > 0 {
		fmt.Printf(" for %s", cfg.Duration)
	}
	if cfg.Count > 0 {
		fmt.Printf(" (%d messages)", cfg.Count)
	}
	fmt.Print(" ...\n\n")

	eng := engine.New()
	onSnap := func(s engine.Snapshot) {
		fmt.Printf("[%6.1fs] sent=%-12d eps=%-12s avg_eps=%-12s %.2f MB/s errors=%d\n",
			s.ElapsedSec, s.Messages, humanRate(s.InstEPS), humanRate(s.AvgEPS), s.InstMBps, s.Errors)
	}

	res, err := eng.Run(ctx, cfg, onSnap)
	if err != nil {
		return err
	}
	printResult(res)
	if res.Errors > 0 {
		fmt.Fprintf(os.Stderr, "\nwarning: %d send errors (check target reachability/transport)\n", res.Errors)
	}
	return nil
}

func printResult(r engine.Result) {
	const bar = "────────────────────────────────────────────────"
	fmt.Println("\n" + bar)
	fmt.Println(" Axoflow Benchmark — Results")
	fmt.Println(bar)
	fmt.Printf(" Lines loaded     : %d\n", r.LinesLoaded)
	fmt.Printf(" Duration         : %.2f s\n", r.DurationSec)
	fmt.Printf(" Messages sent    : %d\n", r.Messages)
	fmt.Printf(" Bytes sent       : %.2f MB\n", float64(r.Bytes)/(1024*1024))
	fmt.Printf(" Avg message size : %.0f bytes\n", r.AvgMsgBytes)
	fmt.Printf(" Errors           : %d\n", r.Errors)
	fmt.Println(bar)
	fmt.Printf(" THROUGHPUT       : %s events/sec\n", humanRate(r.AvgEPS))
	fmt.Printf(" THROUGHPUT       : %.2f MB/sec\n", r.AvgMBps)
	fmt.Println(bar)
}

// humanRate formats a per-second rate with thousands separators.
func humanRate(r float64) string {
	if r < 0 {
		r = 0
	}
	s := fmt.Sprintf("%d", int64(r+0.5))
	out := make([]byte, 0, len(s)+len(s)/3)
	for i := 0; i < len(s); i++ {
		if i > 0 && (len(s)-i)%3 == 0 {
			out = append(out, ',')
		}
		out = append(out, s[i])
	}
	return string(out)
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
