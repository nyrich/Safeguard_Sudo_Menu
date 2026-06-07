# Multi-stage build for the axobench CLI + mocksink. Produces a tiny static
# image (distroless) with real sample logs baked in, so it runs anywhere with
# no extra setup. The macOS GUI is NOT built here — Wails macOS apps require the
# native WebKit and must be built on a Mac (see gui/README.md).

############################
# Stage 1 — build + fetch  #
############################
FROM golang:1.25-bookworm AS build

WORKDIR /src

# Cache module downloads first.
COPY go.mod go.sum ./
RUN go mod download

# Build the static binaries.
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/axobench . \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/mocksink ./cmd/mocksink

# Fetch real sample logs from loghub at build time (network required here, not
# at runtime). Override or mount your own at runtime with -logs / a volume.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && bash scripts/fetch-logs.sh /out/logs \
 && rm -rf /var/lib/apt/lists/*

############################
# Stage 2 — runtime image  #
############################
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

WORKDIR /app
COPY --from=build /out/axobench  /usr/local/bin/axobench
COPY --from=build /out/mocksink  /usr/local/bin/mocksink
COPY --from=build /out/logs      /app/testdata/logs

USER nonroot:nonroot

# Default entrypoint is the load generator. Run mocksink by overriding it:
#   docker run --rm --entrypoint mocksink axobench -transport tcp -listen :5601
ENTRYPOINT ["axobench"]
CMD ["--help"]
