.PHONY: all build logs test vet clean run-sink-udp run-sink-tcp run-sink-otlp gui-dev gui-build docker-build docker-demo docker-sink

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

## gui-dev: run the desktop app in dev mode (needs Wails CLI + platform webview)
gui-dev:
	cd gui && wails dev

## gui-build: build the desktop app bundle (.app on macOS, .exe on Windows)
gui-build:
	cd gui && wails build

## docker-build: build the static CLI/mocksink image (axobench:latest)
docker-build:
	docker build -t axobench:latest .

## docker-demo: run mocksink + axobench together in Docker (self-test)
docker-demo:
	docker compose up --build --abort-on-container-exit

## docker-sink: run a standalone mock receiver on :5601 (override transport/port as needed)
docker-sink: docker-build
	docker run --rm -p 5601:5601 --entrypoint mocksink axobench:latest -transport tcp -listen :5601

## run-sink-udp: start a local UDP mock receiver on :5514
run-sink-udp: build
	./bin/mocksink -transport udp -listen :5514

## run-sink-tcp: start a local TCP mock receiver on :5601
run-sink-tcp: build
	./bin/mocksink -transport tcp -listen :5601

## run-sink-otlp: start a local OTLP/gRPC mock receiver on :4317
run-sink-otlp: build
	./bin/mocksink -transport otlp -listen :4317
