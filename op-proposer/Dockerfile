FROM --platform=$BUILDPLATFORM us-docker.pkg.dev/pagoda-solutions-dev/rollup-data-availability/op-rpc:latest as rust

RUN ls /app/lib

FROM --platform=$BUILDPLATFORM golang:1.19 as builder

ARG VERSION=v0.0.0

RUN apt-get update && apt-get install -y \
    git \
    jq \
    make \
    bash \
    openssl \
    libssl-dev \
    protobuf-compiler \
    pkg-config \
    cbindgen \
    clang

COPY --from=rust /app/lib/ /app/lib/
RUN mv /app/lib/libnear-da-op-rpc-sys.h /app/lib/libnear-da-op-rpc.h
RUN cat /app/lib/libnear-da-op-rpc.h

# build op-proposer with the shared go.mod & go.sum files
COPY ./optimism/op-proposer /app/op-proposer
COPY ./optimism/op-celestia /app/op-celestia
COPY ./optimism/op-bindings /app/op-bindings
COPY ./optimism/op-node /app/op-node
COPY ./optimism/op-service /app/op-service
COPY ./optimism/op-signer /app/op-signer
COPY ./optimism/go.mod /app/go.mod
COPY ./optimism/go.sum /app/go.sum
COPY ./optimism/.git /app/.git

# Copy da rpc
COPY ./optimism/go.work /app/go.work
COPY ./da-rpc /da-rpc
RUN mkdir -p /da-rpc/lib

COPY --from=rust /app/lib/libnear-da-op-rpc-sys.h /da-rpc/lib/
COPY --from=rust /app/lib/libnear_da_op_rpc_sys.so /da-rpc/lib/
RUN cat /da-rpc/lib/libnear-da-op-rpc-sys.h
RUN ls /da-rpc/lib -l

WORKDIR /app/op-proposer

RUN go mod download

ARG TARGETOS TARGETARCH

RUN make op-proposer VERSION="$VERSION" GOOS=$TARGETOS GOARCH=$TARGETARCH

RUN mv /app/op-proposer/bin/op-proposer /

FROM debian:bookworm-slim

COPY --from=builder /op-proposer /usr/local/bin
COPY --from=builder /da-rpc/lib /usr/local/lib/

RUN apt-get update && apt-get install -y \
    openssl \
    libssl-dev \
    ca-certificates \
    protobuf-compiler

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

CMD ["op-proposer"]
