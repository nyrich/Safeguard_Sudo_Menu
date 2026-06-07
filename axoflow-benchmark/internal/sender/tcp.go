package sender

import (
	"bufio"
	"fmt"
	"net"
	"time"

	"git.nyrich.com/nyrich/axobench/internal/stats"
	"git.nyrich.com/nyrich/axobench/internal/syslogfmt"
)

// tcpSender streams framed syslog messages over a persistent TCP connection.
// Writes go through a bufio.Writer so many small messages coalesce into larger
// segments; the worker calls Flush to drain it. Framing is newline (514) or
// octet-counting per RFC6587 (601).
type tcpSender struct {
	conn    net.Conn
	bw      *bufio.Writer
	fmtr    *syslogfmt.Formatter
	framing syslogfmt.Framing
	stats   *stats.Stats
	scratch []byte // reused frame buffer
}

func newTCPSender(cfg Config) (Sender, error) {
	conn, err := net.DialTimeout("tcp", cfg.Addr, 10*time.Second)
	if err != nil {
		return nil, fmt.Errorf("dial tcp %s: %w", cfg.Addr, err)
	}
	if tc, ok := conn.(*net.TCPConn); ok {
		_ = tc.SetNoDelay(true)
	}
	return &tcpSender{
		conn:    conn,
		bw:      bufio.NewWriterSize(conn, 64*1024),
		fmtr:    cfg.newFormatter(),
		framing: cfg.Framing,
		stats:   cfg.Stats,
		scratch: make([]byte, 0, 2048),
	}, nil
}

func (s *tcpSender) Send(line []byte, now time.Time) error {
	msg := s.fmtr.Render(line, now)
	s.scratch = syslogfmt.Frame(s.scratch[:0], msg, s.framing)
	n, err := s.bw.Write(s.scratch)
	if err != nil {
		s.stats.AddErr()
		return err
	}
	s.stats.AddOK(n)
	return nil
}

func (s *tcpSender) Flush() error { return s.bw.Flush() }

func (s *tcpSender) Close() error {
	ferr := s.bw.Flush()
	cerr := s.conn.Close()
	if ferr != nil {
		return ferr
	}
	return cerr
}
