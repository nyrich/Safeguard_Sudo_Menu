// Command mocksink is a tiny stand-in for an Axoflow/AxoRouter ingest endpoint.
// It accepts syslog over UDP/TCP and logs over OTLP/gRPC, counts what it
// receives, and prints the receive-side throughput. Use it to smoke-test
// axobench when you don't have a real Axoflow instance handy.
//
//	mocksink -transport udp  -listen :5514
//	mocksink -transport tcp  -listen :5601
//	mocksink -transport otlp -listen :4317
package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"google.golang.org/grpc"

	collogspb "go.opentelemetry.io/proto/otlp/collector/logs/v1"
	logspb "go.opentelemetry.io/proto/otlp/logs/v1"
)

var (
	msgs  atomic.Int64
	bytesRecv atomic.Int64
)

func main() {
	transport := flag.String("transport", "tcp", "udp | tcp | otlp")
	listen := flag.String("listen", ":5514", "listen address")
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	start := time.Now()
	go report(ctx, start)

	var err error
	switch *transport {
	case "udp":
		err = serveUDP(ctx, *listen)
	case "tcp":
		err = serveTCP(ctx, *listen)
	case "otlp":
		err = serveOTLP(ctx, *listen)
	default:
		err = fmt.Errorf("unknown transport %q", *transport)
	}
	if err != nil && ctx.Err() == nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}

	total := msgs.Load()
	secs := time.Since(start).Seconds()
	fmt.Printf("\nReceived %d messages in %.2fs = %.0f eps, %.2f MB\n",
		total, secs, float64(total)/secs, float64(bytesRecv.Load())/(1024*1024))
}

func report(ctx context.Context, start time.Time) {
	t := time.NewTicker(time.Second)
	defer t.Stop()
	var prev int64
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			cur := msgs.Load()
			fmt.Printf("[recv] total=%d eps=%d\n", cur, cur-prev)
			prev = cur
		}
	}
}

func serveUDP(ctx context.Context, addr string) error {
	pc, err := net.ListenPacket("udp", addr)
	if err != nil {
		return err
	}
	defer pc.Close()
	fmt.Printf("mocksink udp listening on %s\n", addr)
	go func() { <-ctx.Done(); pc.Close() }()
	buf := make([]byte, 65536)
	for {
		n, _, err := pc.ReadFrom(buf)
		if err != nil {
			return err
		}
		msgs.Add(1)
		bytesRecv.Add(int64(n))
	}
}

func serveTCP(ctx context.Context, addr string) error {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	defer ln.Close()
	fmt.Printf("mocksink tcp listening on %s\n", addr)
	go func() { <-ctx.Done(); ln.Close() }()
	for {
		conn, err := ln.Accept()
		if err != nil {
			return err
		}
		go handleTCP(conn)
	}
}

// handleTCP counts framed syslog messages, auto-detecting the framing from the
// first byte: a leading digit means RFC6587 octet-counting ("<len> msg..."),
// anything else means newline-delimited.
func handleTCP(conn net.Conn) {
	defer conn.Close()
	br := bufio.NewReaderSize(conn, 64*1024)

	first, err := br.Peek(1)
	if err != nil {
		return
	}
	if first[0] >= '0' && first[0] <= '9' {
		readOctetCounted(br)
		return
	}
	sc := bufio.NewScanner(br)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		msgs.Add(1)
		bytesRecv.Add(int64(len(sc.Bytes()) + 1))
	}
}

// readOctetCounted parses a stream of "<length> <message>" frames (RFC6587).
func readOctetCounted(br *bufio.Reader) {
	for {
		// Read the ASCII length up to the separating space.
		n := 0
		gotDigit := false
		for {
			b, err := br.ReadByte()
			if err != nil {
				return
			}
			if b == ' ' {
				break
			}
			if b < '0' || b > '9' {
				return // malformed frame
			}
			n = n*10 + int(b-'0')
			gotDigit = true
		}
		if !gotDigit || n <= 0 {
			return
		}
		if _, err := br.Discard(n); err != nil {
			return
		}
		msgs.Add(1)
		bytesRecv.Add(int64(n))
	}
}

type logsServer struct {
	collogspb.UnimplementedLogsServiceServer
}

func (logsServer) Export(_ context.Context, req *collogspb.ExportLogsServiceRequest) (*collogspb.ExportLogsServiceResponse, error) {
	var n int64
	for _, rl := range req.GetResourceLogs() {
		for _, sl := range rl.GetScopeLogs() {
			n += int64(len(sl.GetLogRecords()))
		}
	}
	msgs.Add(n)
	return &collogspb.ExportLogsServiceResponse{}, nil
}

var _ logspb.LogRecord // keep logspb import for clarity of what we receive

func serveOTLP(ctx context.Context, addr string) error {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	srv := grpc.NewServer()
	collogspb.RegisterLogsServiceServer(srv, logsServer{})
	fmt.Printf("mocksink otlp/grpc listening on %s\n", addr)
	go func() { <-ctx.Done(); srv.GracefulStop() }()
	return srv.Serve(ln)
}
