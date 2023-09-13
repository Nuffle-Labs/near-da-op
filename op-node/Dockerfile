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

# build op-node with the shared go.mod & go.sum files
COPY ./op-node /app/op-node
COPY ./op-celestia /app/op-celestia
COPY ./op-chain-ops /app/op-chain-ops
COPY ./op-service /app/op-service
COPY ./op-bindings /app/op-bindings
COPY ./go.mod /app/go.mod
COPY ./go.sum /app/go.sum

COPY --from=rust /app/lib/ /app/lib/
RUN mv /app/lib/libnear-da-op-rpc-sys.h /app/lib/libnear-da-op-rpc.h
RUN cat /app/lib/libnear-da-op-rpc.h

COPY ./.git /app/.git

WORKDIR /app/op-node

RUN go mod download

ARG TARGETOS TARGETARCH

RUN make op-node VERSION="$VERSION" GOOS=$TARGETOS GOARCH=$TARGETARCH

RUN mv /app/op-node/bin/op-node /
RUN mv /app/lib /libs
RUN rm -rf /app

FROM debian:bookworm-slim

COPY --from=builder /op-node /usr/local/bin
COPY --from=builder /libs /usr/local/lib/

RUN mkdir -p /root/.near-credentials/testnet
RUN mkdir -p /root/.near-credentials/mainnet
RUN mkdir -p /root/.near-credentials/localnet

CMD ["op-node"]
