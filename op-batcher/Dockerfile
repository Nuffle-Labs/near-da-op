FROM --platform=$BUILDPLATFORM golang:1.19.0-alpine3.15 as builder

ARG VERSION=v0.0.0

RUN apk add --no-cache make gcc musl-dev linux-headers git jq bash

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

WORKDIR /app/op-batcher

RUN go mod download

ARG TARGETOS TARGETARCH

RUN make op-batcher VERSION="$VERSION" GOOS=$TARGETOS GOARCH=$TARGETARCH

RUN mv /app/op-batcher/bin/op-batcher /
RUN rm -rf /app

FROM alpine:3.15

COPY --from=builder /op-batcher /usr/local/bin

RUN mkdir -p /root/.near-credentials/testnet
RUN mkdir -p /root/.near-credentials/mainnet
RUN mkdir -p /root/.near-credentials/localnet

ENTRYPOINT ["op-batcher"]
