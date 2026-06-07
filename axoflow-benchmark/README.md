# axobench — Axoflow log benchmark tester

A high-throughput load generator that hammers **real sample logs** at an
[Axoflow](https://axoflow.com) / **AxoRouter** instance and measures how many
**events per second (EPS)** it can ingest.

It speaks the protocols AxoRouter accepts:

| Transport | Default port | Notes |
|-----------|--------------|-------|
| **Syslog UDP**  | 514  | Fire-and-forget; highest raw send rate, lossy. Good for peak-rate stress. |
| **Syslog TCP**  | 514 / 601 | Reliable stream; newline or RFC6587 octet-counting framing. Best for sustained EPS. |
| **OTLP/gRPC**   | 4317 | OpenTelemetry logs — Axoflow's preferred high-performance path. Batched exports. |

Real log lines come from [**loghub**](https://github.com/logpai/loghub), a large
curated collection of real production/system logs (Linux, OpenSSH, Apache, HDFS,
Zookeeper, macOS, HealthApp). `scripts/fetch-logs.sh` pulls the 2k-line samples
loghub hosts on GitHub.

> Built in Go for true concurrency and a single static binary. Validated
> end-to-end against the bundled `mocksink` for all three transports.

**Two front-ends, one engine:**
- **CLI** (`axobench`) — scriptable, headless, ideal for CI and remote hosts.
- **Desktop GUI** (`gui/`, macOS & Windows) — a [Wails](https://wails.io) app with
  live events/sec + MB/s charts and form-driven config. See **[gui/README.md](gui/README.md)**.

Both drive the same `internal/engine`, so they report identical numbers.

---

## Quick start

```bash
# 1. Build the binaries (-> ./bin/axobench, ./bin/mocksink)
make build

# 2. Download real sample logs (-> testdata/logs/*.log)
make logs

# 3. Point it at your AxoRouter and measure EPS
./bin/axobench -t YOUR_AXOROUTER:514 -transport tcp -d 30s -w 8
```

No Axoflow handy? Smoke-test against the bundled mock receiver:

```bash
# terminal 1 — fake ingest endpoint that counts what it receives
./bin/mocksink -transport tcp -listen :5601

# terminal 2 — hammer it
./bin/axobench -t 127.0.0.1:5601 -transport tcp -framing octet -d 10s -w 8
```

---

## Usage

```
axobench -t HOST:PORT [flags]

  -t, -target string     target address host:port (AxoRouter source). Required.
  -transport string      udp | tcp | otlp                       (default "tcp")
  -logs string           log file(s) or dir(s) to replay   (default "testdata/logs")
  -w, -workers int       concurrent workers / connections   (default: NUM_CPUS)
  -d, -duration dur      run duration, e.g. 30s (0 = until -count or Ctrl-C)
  -count int             total messages to send (0 = unlimited)
  -rate int              target total events/sec (0 = max throughput)
  -format string         syslog wrapping: raw | rfc5424 | rfc3164 (default "rfc5424")
  -framing string        TCP framing: newline | octet            (default "octet")
  -facility int          syslog facility 0-23                     (default 1)
  -severity int          syslog severity 0-7                      (default 6)
  -hostname string       syslog HOSTNAME field (default: this host)
  -appname string        syslog APP-NAME / tag                    (default "axobench")
  -batch int             OTLP log records per export request      (default 100)
  -otlp-tls              use TLS for OTLP/gRPC (default plaintext)
  -service string        OTLP service.name attribute              (default "axobench")
  -report-interval dur   live progress cadence                    (default 1s)
```

If neither `-d` nor `-count` is given, it defaults to a 30s run so it never
hammers forever by accident.

### Examples

```bash
# Max-throughput sustained TCP test on port 601 (octet framing)
axobench -t axorouter:601 -transport tcp -framing octet -d 60s -w 16

# UDP peak-rate stress, RFC3164 (legacy BSD) framing
axobench -t axorouter:514 -transport udp -format rfc3164 -d 30s -w 8

# OTLP/gRPC with large batches (often the highest EPS path)
axobench -t axorouter:4317 -transport otlp -batch 1000 -d 60s -w 8

# Capacity check: can it hold a steady 100k eps?
axobench -t axorouter:514 -transport tcp -rate 100000 -d 120s

# Replay only specific datasets
axobench -t axorouter:514 -logs testdata/logs/openssh.log,testdata/logs/apache.log -d 30s
```

---

## Reading the output

```
[  10.0s] sent=63821044   eps=6,401,233   avg_eps=6,382,104   1083.40 MB/s errors=0
...
────────────────────────────────────────────────
 Axoflow Benchmark — Results
────────────────────────────────────────────────
 Duration         : 60.00 s
 Messages sent    : 383,000,000
 ...
 THROUGHPUT       : 6,383,333 events/sec
 THROUGHPUT       : 1081.20 MB/sec
────────────────────────────────────────────────
```

- **eps** — instantaneous events/sec for the last interval.
- **avg_eps** — running average since start.
- **THROUGHPUT (events/sec)** — the headline number: total messages ÷ duration.
- **MB/s** — wire payload throughput (syslog frame bytes; serialized proto bytes for OTLP).
- **errors** — failed sends (connection reset, refused, etc.).

### Methodology notes

- The corpus is loaded fully into memory before timing starts; workers replay it
  in a loop, so disk I/O never bottlenecks the hot path.
- The clock starts **after** all connections are established, so TCP/gRPC
  handshake time isn't counted.
- For a true ceiling, run on a host close to AxoRouter (same network/region) and
  scale `-w` up until EPS stops increasing. NIC/CPU on the sender can become the
  limit — compare against `mocksink` on the same box to see the sender's own cap.
- **UDP** is lossy by design: `axobench` reports what it *sent*; the receiver may
  count fewer. Use TCP or OTLP when you need delivery guarantees in the number.

---

## Project layout

```
axoflow-benchmark/
├── main.go                  # CLI, flag parsing, output formatting
├── cmd/mocksink/            # local fake AxoRouter (udp/tcp/otlp) for testing
├── internal/
│   ├── engine/              # shared benchmark core (worker pool, pacing, snapshots)
│   ├── loader/              # load sample logs into memory
│   ├── syslogfmt/           # RFC3164/RFC5424 rendering + RFC6587 framing
│   ├── sender/              # udp / tcp / otlp transports
│   └── stats/               # atomic throughput counters
├── gui/                     # Wails desktop app (macOS & Windows) — see gui/README.md
│   ├── main.go              #   thin Wails shell (the only file importing Wails)
│   ├── app/                 #   binding logic (pure Go, unit-tested)
│   └── frontend/            #   Vite + Chart.js dashboard
├── scripts/fetch-logs.sh    # download real logs from loghub
└── testdata/logs/           # sample logs land here (gitignored)
```

## Credits

Sample logs: [loghub](https://github.com/logpai/loghub) (research dataset).
Target system: [Axoflow / AxoSyslog](https://axoflow.com/docs/).
