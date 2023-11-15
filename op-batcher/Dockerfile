FROM --platform=$BUILDPLATFORM ghcr.io/near/rollup-data-availability/da-rpc:latest as rust

RUN ls /lib
RUN ls /gopkg/da-rpc

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

# build op-batcher with the shared go.mod & go.sum files
COPY ./op-batcher /app/op-batcher
COPY ./op-celestia /app/op-celestia
COPY ./op-bindings /app/op-bindings
COPY ./op-node /app/op-node
COPY ./op-service /app/op-service
COPY ./op-signer /app/op-signer
COPY ./go.mod /app/go.mod
COPY ./go.sum /app/go.sum
COPY ./.git /app/.git

# Copy da rpc
COPY --from=rust /gopkg/da-rpc/lib/ /usr/local/lib

COPY ./go.work /app/go.work

WORKDIR /app
COPY ./Makefile /app/Makefile

WORKDIR /app/op-batcher

RUN go mod download

ARG TARGETOS TARGETARCH

RUN make op-batcher VERSION="$VERSION" GOOS=$TARGETOS GOARCH=$TARGETARCH

RUN mv /app/op-batcher/bin/op-batcher /

FROM debian:bookworm-slim

COPY --from=rust /gopkg/da-rpc/lib/ /usr/local/lib
COPY --from=builder /op-batcher /usr/local/bin

RUN apt-get update && apt-get install -y \
    openssl \
    libssl-dev \
    ca-certificates \
    protobuf-compiler

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

ENTRYPOINT ["op-batcher"]
