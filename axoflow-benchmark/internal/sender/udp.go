package sender

import (
	"fmt"
	"net"
	"time"

	"github.com/nyrich/axoflow-benchmark/internal/stats"
	"github.com/nyrich/axoflow-benchmark/internal/syslogfmt"
)

// udpSender sends one syslog datagram per event. UDP is fire-and-forget: a
// successful WriteTo only means the datagram left the host, not that AxoRouter
// received it — ideal for measuring peak send rate.
type udpSender struct {
	conn  *net.UDPConn
	fmtr  *syslogfmt.Formatter
	stats *stats.Stats
}

func newUDPSender(cfg Config) (Sender, error) {
	raddr, err := net.ResolveUDPAddr("udp", cfg.Addr)
	if err != nil {
		return nil, fmt.Errorf("resolve udp %s: %w", cfg.Addr, err)
	}
	conn, err := net.DialUDP("udp", nil, raddr)
	if err != nil {
		return nil, fmt.Errorf("dial udp %s: %w", cfg.Addr, err)
	}
	return &udpSender{conn: conn, fmtr: cfg.newFormatter(), stats: cfg.Stats}, nil
}

func (s *udpSender) Send(line []byte, now time.Time) error {
	msg := s.fmtr.Render(line, now)
	n, err := s.conn.Write(msg)
	if err != nil {
		s.stats.AddErr()
		return err
	}
	s.stats.AddOK(n)
	return nil
}

func (s *udpSender) Flush() error { return nil }

func (s *udpSender) Close() error { return s.conn.Close() }
