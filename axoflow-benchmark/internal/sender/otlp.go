package sender

import (
	"context"
	"crypto/tls"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/proto"

	collogspb "go.opentelemetry.io/proto/otlp/collector/logs/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	logspb "go.opentelemetry.io/proto/otlp/logs/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"

	"git.nyrich.com/nyrich/axobench/internal/stats"
)

// otlpSender ships logs to an AxoRouter OpenTelemetry source over OTLP/gRPC.
// This is Axoflow's preferred high-throughput transport. Records are batched
// into one ExportLogsServiceRequest per BatchSize to amortise RPC overhead.
type otlpSender struct {
	conn      *grpc.ClientConn
	client    collogspb.LogsServiceClient
	batchSize int
	stats     *stats.Stats

	resLogs *logspb.ResourceLogs   // reused envelope
	records []*logspb.LogRecord    // current batch (also resLogs.ScopeLogs[0].LogRecords)
	req     *collogspb.ExportLogsServiceRequest
}

func newOTLPSender(cfg Config) (Sender, error) {
	var creds credentials.TransportCredentials
	if cfg.Insecure {
		creds = insecure.NewCredentials()
	} else {
		creds = credentials.NewTLS(&tls.Config{})
	}
	conn, err := grpc.NewClient(cfg.Addr, grpc.WithTransportCredentials(creds))
	if err != nil {
		return nil, fmt.Errorf("grpc client %s: %w", cfg.Addr, err)
	}

	svc := cfg.ServiceName
	if svc == "" {
		svc = "axobench"
	}
	resLogs := &logspb.ResourceLogs{
		Resource: &resourcepb.Resource{
			Attributes: []*commonpb.KeyValue{{
				Key:   "service.name",
				Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: svc}},
			}},
		},
		ScopeLogs: []*logspb.ScopeLogs{{
			Scope: &commonpb.InstrumentationScope{Name: "axoflow-benchmark"},
		}},
	}
	s := &otlpSender{
		conn:      conn,
		client:    collogspb.NewLogsServiceClient(conn),
		batchSize: cfg.BatchSize,
		stats:     cfg.Stats,
		resLogs:   resLogs,
		records:   make([]*logspb.LogRecord, 0, cfg.BatchSize),
		req:       &collogspb.ExportLogsServiceRequest{ResourceLogs: []*logspb.ResourceLogs{resLogs}},
	}
	return s, nil
}

func (s *otlpSender) Send(line []byte, now time.Time) error {
	ts := uint64(now.UnixNano())
	s.records = append(s.records, &logspb.LogRecord{
		TimeUnixNano:         ts,
		ObservedTimeUnixNano: ts,
		SeverityNumber:       logspb.SeverityNumber_SEVERITY_NUMBER_INFO,
		SeverityText:         "INFO",
		Body: &commonpb.AnyValue{
			Value: &commonpb.AnyValue_StringValue{StringValue: string(line)},
		},
	})
	if len(s.records) >= s.batchSize {
		return s.Flush()
	}
	return nil
}

func (s *otlpSender) Flush() error {
	n := len(s.records)
	if n == 0 {
		return nil
	}
	s.resLogs.ScopeLogs[0].LogRecords = s.records
	size := proto.Size(s.req)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	_, err := s.client.Export(ctx, s.req)
	cancel()

	// Reset the batch regardless of outcome so we don't resend on error.
	s.records = s.records[:0]
	s.resLogs.ScopeLogs[0].LogRecords = nil

	if err != nil {
		s.stats.AddErrN(n)
		return err
	}
	s.stats.AddOKN(n, size)
	return nil
}

func (s *otlpSender) Close() error {
	ferr := s.Flush()
	cerr := s.conn.Close()
	if ferr != nil {
		return ferr
	}
	return cerr
}
