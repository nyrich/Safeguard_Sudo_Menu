// Package syslogfmt wraps raw log lines into syslog protocol frames so they are
// accepted by AxoRouter's syslog source (RFC3164/RFC5424 on UDP/TCP 514, TCP 601).
package syslogfmt

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Format selects how a raw log line is rendered onto the wire.
type Format int

const (
	// Raw sends the line unchanged (the corpus lines are already real logs).
	Raw Format = iota
	// RFC5424 wraps the line as the MSG of a modern IETF syslog frame.
	RFC5424
	// RFC3164 wraps the line as the MSG of a legacy BSD syslog frame.
	RFC3164
)

// ParseFormat maps a CLI string to a Format.
func ParseFormat(s string) (Format, error) {
	switch s {
	case "raw":
		return Raw, nil
	case "rfc5424":
		return RFC5424, nil
	case "rfc3164":
		return RFC3164, nil
	default:
		return Raw, fmt.Errorf("unknown format %q (want raw|rfc5424|rfc3164)", s)
	}
}

// Framing selects how a complete message is delimited on a stream (TCP).
type Framing int

const (
	// FramingNewline appends '\n' (non-transparent framing, common on 514/TCP).
	FramingNewline Framing = iota
	// FramingOctetCount prefixes "<len> " per RFC6587 (used on port 601).
	FramingOctetCount
)

// ParseFraming maps a CLI string to a Framing.
func ParseFraming(s string) (Framing, error) {
	switch s {
	case "newline", "lf":
		return FramingNewline, nil
	case "octet", "octet-count", "octet-counting":
		return FramingOctetCount, nil
	default:
		return FramingNewline, fmt.Errorf("unknown framing %q (want newline|octet)", s)
	}
}

// Formatter renders raw log lines into syslog messages. It is not safe for
// concurrent use by multiple goroutines; give each worker its own Formatter
// (they are cheap) so the reusable buffer doesn't race.
type Formatter struct {
	format   Format
	facility int
	severity int
	hostname string
	appName  string
	buf      []byte
}

// New builds a Formatter. facility (0-23) and severity (0-7) form the PRI value.
func New(format Format, facility, severity int, hostname, appName string) *Formatter {
	if hostname == "" {
		if hn, err := os.Hostname(); err == nil {
			hostname = hn
		} else {
			hostname = "axobench"
		}
	}
	if appName == "" {
		appName = "axobench"
	}
	return &Formatter{
		format:   format,
		facility: facility,
		severity: severity,
		hostname: hostname,
		appName:  appName,
		buf:      make([]byte, 0, 1024),
	}
}

// pri returns the syslog priority value.
func (f *Formatter) pri() int { return f.facility*8 + f.severity }

// Render returns a wire-ready message for the given raw log line and timestamp.
// The returned slice is owned by the Formatter and is valid only until the next
// call to Render; callers must copy it if they need to retain it.
func (f *Formatter) Render(line []byte, now time.Time) []byte {
	f.buf = f.buf[:0]
	switch f.format {
	case Raw:
		f.buf = append(f.buf, line...)
	case RFC5424:
		// <PRI>1 TIMESTAMP HOSTNAME APP-NAME PROCID MSGID STRUCTURED-DATA MSG
		f.buf = append(f.buf, '<')
		f.buf = strconv.AppendInt(f.buf, int64(f.pri()), 10)
		f.buf = append(f.buf, ">1 "...)
		f.buf = now.AppendFormat(f.buf, time.RFC3339Nano)
		f.buf = append(f.buf, ' ')
		f.buf = append(f.buf, f.hostname...)
		f.buf = append(f.buf, ' ')
		f.buf = append(f.buf, f.appName...)
		f.buf = append(f.buf, " - - - "...) // PROCID MSGID STRUCTURED-DATA
		f.buf = append(f.buf, line...)
	case RFC3164:
		// <PRI>Mmm dd hh:mm:ss HOSTNAME TAG: MSG
		f.buf = append(f.buf, '<')
		f.buf = strconv.AppendInt(f.buf, int64(f.pri()), 10)
		f.buf = append(f.buf, '>')
		f.buf = now.AppendFormat(f.buf, "Jan _2 15:04:05")
		f.buf = append(f.buf, ' ')
		f.buf = append(f.buf, f.hostname...)
		f.buf = append(f.buf, ' ')
		f.buf = append(f.buf, f.appName...)
		f.buf = append(f.buf, ": "...)
		f.buf = append(f.buf, line...)
	}
	return f.buf
}

// Frame applies stream framing to a rendered message, appending into dst and
// returning the extended slice. Used only for stream transports (TCP).
func Frame(dst, msg []byte, framing Framing) []byte {
	switch framing {
	case FramingOctetCount:
		dst = strconv.AppendInt(dst, int64(len(msg)), 10)
		dst = append(dst, ' ')
		dst = append(dst, msg...)
	default: // FramingNewline
		dst = append(dst, msg...)
		dst = append(dst, '\n')
	}
	return dst
}
