FROM --platform=$BUILDPLATFORM near/op-rpc:bullseye as rust

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

# build op-batcher with the shared go.mod & go.sum files
COPY ./op-batcher /app/op-batcher
COPY ./op-celestia /app/op-celestia
COPY ./op-bindings /app/op-bindings
COPY ./op-node /app/op-node
COPY ./op-service /app/op-service
COPY ./op-signer /app/op-signer
COPY ./go.mod /app/go.mod
COPY ./go.sum /app/go.sum

COPY --from=rust /app/lib/ /app/lib/
RUN mv /app/lib/libnear-da-op-rpc-sys.h /app/lib/libnear-da-op-rpc.h
RUN cat /app/lib/libnear-da-op-rpc.h

COPY ./.git /app/.git

WORKDIR /app/op-batcher

RUN go mod download

ARG TARGETOS TARGETARCH

RUN make op-batcher VERSION="$VERSION" GOOS=$TARGETOS GOARCH=$TARGETARCH

RUN mv /app/op-batcher/bin/op-batcher /
RUN mv /app/lib /libs

RUN rm -rf /app

FROM alpine:3.15

COPY --from=builder /op-batcher /usr/local/bin
COPY --from=builder /libs /usr/local/lib/

RUN mkdir -p /root/.near-credentials/testnet
RUN mkdir -p /root/.near-credentials/mainnet
RUN mkdir -p /root/.near-credentials/localnet

ENTRYPOINT ["op-batcher"]
