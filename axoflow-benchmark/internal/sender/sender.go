// Package sender defines the pluggable transports that ship log events to
// Axoflow/AxoRouter and a Builder that mints one Sender per worker goroutine.
package sender

import (
	"fmt"
	"time"

	"github.com/nyrich/axobench/internal/stats"
	"github.com/nyrich/axobench/internal/syslogfmt"
)

// Sender ships log events over a single connection. A Sender is owned by one
// worker goroutine and is NOT safe for concurrent use.
type Sender interface {
	// Send transmits (or buffers, for batching transports) a single raw log
	// line stamped at now. Implementations update stats themselves.
	Send(line []byte, now time.Time) error
	// Flush transmits any buffered events.
	Flush() error
	// Close flushes and releases the connection.
	Close() error
}

// Config carries the shared settings used to build per-worker Senders.
type Config struct {
	Transport string // "udp" | "tcp" | "otlp"
	Addr      string // host:port

	// Syslog framing/formatting (udp, tcp).
	Format   syslogfmt.Format
	Framing  syslogfmt.Framing
	Facility int
	Severity int
	Hostname string
	AppName  string

	// OTLP options.
	BatchSize   int
	ServiceName string
	Insecure    bool // plaintext gRPC (no TLS)

	Stats *stats.Stats
}

// Builder validates a Config and produces fresh Senders.
type Builder struct{ cfg Config }

// NewBuilder validates cfg and returns a Builder.
func NewBuilder(cfg Config) (*Builder, error) {
	switch cfg.Transport {
	case "udp", "tcp", "otlp":
	default:
		return nil, fmt.Errorf("unknown transport %q (want udp|tcp|otlp)", cfg.Transport)
	}
	if cfg.Addr == "" {
		return nil, fmt.Errorf("empty target address")
	}
	if cfg.Stats == nil {
		return nil, fmt.Errorf("nil stats")
	}
	if cfg.Transport == "otlp" && cfg.BatchSize < 1 {
		cfg.BatchSize = 100
	}
	return &Builder{cfg: cfg}, nil
}

// New creates one Sender (its own connection + formatter) for a worker.
func (b *Builder) New() (Sender, error) {
	switch b.cfg.Transport {
	case "udp":
		return newUDPSender(b.cfg)
	case "tcp":
		return newTCPSender(b.cfg)
	case "otlp":
		return newOTLPSender(b.cfg)
	default:
		return nil, fmt.Errorf("unknown transport %q", b.cfg.Transport)
	}
}

// newFormatter builds a per-worker syslog formatter from the config.
func (c Config) newFormatter() *syslogfmt.Formatter {
	return syslogfmt.New(c.Format, c.Facility, c.Severity, c.Hostname, c.AppName)
}
