.PHONY: all build logs test vet clean run-sink-udp run-sink-tcp run-sink-otlp

all: build

## build: compile axobench and mocksink into ./bin
build:
	go build -o bin/axobench .
	go build -o bin/mocksink ./cmd/mocksink

## logs: download real sample logs from loghub into testdata/logs
logs:
	./scripts/fetch-logs.sh

## vet: run go vet
vet:
	go vet ./...

## test: run unit tests
test:
	go test ./...

## clean: remove built binaries
clean:
	rm -rf bin

## run-sink-udp: start a local UDP mock receiver on :5514
run-sink-udp: build
	./bin/mocksink -transport udp -listen :5514

## run-sink-tcp: start a local TCP mock receiver on :5601
run-sink-tcp: build
	./bin/mocksink -transport tcp -listen :5601

## run-sink-otlp: start a local OTLP/gRPC mock receiver on :4317
run-sink-otlp: build
	./bin/mocksink -transport otlp -listen :4317
