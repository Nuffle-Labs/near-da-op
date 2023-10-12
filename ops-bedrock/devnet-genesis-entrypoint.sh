#!/usr/bin/env bash
set -eu

# Source environment variables from .env
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "Sourcing environment variables from $SCRIPT_DIR/.env"
source "$SCRIPT_DIR"/.env

DEVNET=$SCRIPT_DIR/../.devnet
mkdir -p "$DEVNET"


echo "exporting LD_LIBRARY_PATH"
export LD_LIBRARY_PATH=$SCRIPT_DIR/../../../gopkg/da-rpc/lib

if [ ! -f "$DEVNET/done" ]; then
  echo "Regenerating genesis files, target: $DEVNET"

  TIMESTAMP=$(date +%s | xargs printf '0x%x')
  cat "$CONTRACTS_BEDROCK/deploy-config/devnetL1.json" | jq -r ".l1GenesisBlockTimestamp = \"$TIMESTAMP\"" > /tmp/bedrock-devnet-deploy-config.json

  (
    cd "$OP_NODE"
    echo "Compiling contracts to $DEVNET"
    go run cmd/main.go genesis devnet \
        --deploy-config /tmp/bedrock-devnet-deploy-config.json \
        --outfile.l1 $DEVNET/genesis-l1.json \
        --outfile.l2 $DEVNET/genesis-l2.json \
        --outfile.rollup $DEVNET/rollup.json
    touch "$DEVNET/done"
  )
fi