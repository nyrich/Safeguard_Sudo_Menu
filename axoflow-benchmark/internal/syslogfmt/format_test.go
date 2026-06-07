package syslogfmt

import (
	"strings"
	"testing"
	"time"
)

func TestRenderRFC5424(t *testing.T) {
	f := New(RFC5424, 1, 6, "host1", "app1")
	now := time.Date(2026, 6, 7, 12, 0, 0, 0, time.UTC)
	got := string(f.Render([]byte("hello world"), now))
	// PRI = facility*8 + severity = 1*8 + 6 = 14
	if !strings.HasPrefix(got, "<14>1 ") {
		t.Fatalf("bad PRI/version prefix: %q", got)
	}
	if !strings.Contains(got, " host1 app1 - - - hello world") {
		t.Fatalf("bad header/msg: %q", got)
	}
}

func TestRenderRFC3164(t *testing.T) {
	f := New(RFC3164, 1, 6, "host1", "app1")
	now := time.Date(2026, 6, 7, 12, 0, 0, 0, time.UTC)
	got := string(f.Render([]byte("hello"), now))
	if !strings.HasPrefix(got, "<14>Jun  7 12:00:00 host1 app1: hello") {
		t.Fatalf("unexpected rfc3164 render: %q", got)
	}
}

func TestRenderRaw(t *testing.T) {
	f := New(Raw, 1, 6, "h", "a")
	got := string(f.Render([]byte("untouched"), time.Now()))
	if got != "untouched" {
		t.Fatalf("raw should pass through, got %q", got)
	}
}

func TestFrameOctetCount(t *testing.T) {
	got := string(Frame(nil, []byte("abc"), FramingOctetCount))
	if got != "3 abc" {
		t.Fatalf("octet framing: got %q want %q", got, "3 abc")
	}
}

func TestFrameNewline(t *testing.T) {
	got := string(Frame(nil, []byte("abc"), FramingNewline))
	if got != "abc\n" {
		t.Fatalf("newline framing: got %q want %q", got, "abc\\n")
	}
}

func TestRenderReusesBuffer(t *testing.T) {
	// Two renders should not alias each other's content once copied.
	f := New(RFC5424, 1, 6, "h", "a")
	a := string(f.Render([]byte("first"), time.Now()))
	b := string(f.Render([]byte("second"), time.Now()))
	if !strings.HasSuffix(a, "first") || !strings.HasSuffix(b, "second") {
		t.Fatalf("buffer reuse corrupted output: a=%q b=%q", a, b)
	}
}
