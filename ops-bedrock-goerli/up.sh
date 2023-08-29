#!/usr/bin/env bash

# This script starts a local devnet using Docker Compose. We have to use
# this more complicated Bash script rather than Compose's native orchestration
# tooling because we need to start each service in a specific order, and specify
# their configuration along the way. The order is:
#
# 1. Start L1.
# 2. Compile contracts.
# 3. Deploy the contracts to L1 if necessary.
# 4. Start L2, inserting the compiled contract artifacts into the genesis.
# 5. Get the genesis hashes and timestamps from L1/L2.
# 6. Generate the rollup driver's config using the genesis hashes and the
#    timestamps recovered in step 4 as well as the address of the OptimismPortal
#    contract deployed in step 3.
# 7. Start the rollup driver.
# 8. Start the L2 output submitter.
#
# The timestamps are critically important here, since the rollup driver will fill in
# empty blocks if the tip of L1 lags behind the current timestamp. This can lead to
# a perceived infinite loop. To get around this, we set the timestamp to the current
# time in this script.
#
# This script is safe to run multiple times. It stores state in `.devnet`, and
# contracts-bedrock/deployments/devnetL1.
#
# Don't run this script directly. Run it using the makefile, e.g. `make testnet-up`.
# To clean up your devnet, run `make testnet-clean`.

set -eu

L2_URL="http://localhost:8545"

OP_NODE="$PWD/op-node"
CONTRACTS_BEDROCK="$PWD/packages/contracts-bedrock"
DEPLOYMENT_CONFIG="$CONTRACTS_BEDROCK/deploy-config/getting-started.json"
L2OO_ADDRESS="0x26604E39cB38aC2567793968E19BD04586005Ed6"

# Set all the pkeys
KEYS_PATH=$PWD/data/keys.json
SEQ_KEY=$(cat $KEYS_PATH | jq -r ".Sequencer.PrivateKey")
PROPOSER_KEY=$(cat $KEYS_PATH | jq -r ".Proposer.PrivateKey")
BATCHER_KEY=$(cat $KEYS_PATH | jq -r ".Batcher.PrivateKey")

DA_ACCOUNT="abc.topgunbakugo.testnet"
DA_CONTRACT="da.topgunbakugo.testnet"

if [ -z "$SEQ_KEY" ]; then
  echo "SEQ_KEY not set"
  exit 1
fi
if [ -z "$PROPOSER_KEY" ]; then
  echo "PROPOSER_KEY not set"
  exit 1
fi
if [ -z "$BATCHER_KEY" ]; then
  echo "BATCHER_KEY not set"
  exit 1
fi

NETWORK=goerli
DATA="/mnt/data/.goerli"

COMPOSE="docker-compose"
COMPOSE="docker compose"



mkdir -p $DATA

# cast block finalized --rpc-url $L1_RPC | grep -E "(timestamp|hash|number)"

# Helper method that waits for a given URL to be up. Can't use
# cURL's built-in retry logic because connection reset errors
# are ignored unless you're using a very recent version of cURL
function wait_up {
  echo -n "Waiting for $1 to come up..."
  i=0
  until curl -s -f -o /dev/null "$1"
  do
    echo -n .
    sleep 0.25

    ((i=i+1))
    if [ "$i" -eq 300 ]; then
      echo " Timeout!" >&2
      exit 1
    fi
  done
  echo "Done!"
}

# function deployContracts() {
#     # Ensure contracts are deployed
#     # npx hardhat deploy --network getting-started
#     # npx hardhat etherscan-verify --network getting-started --sleep
# }

mkdir -p $DATA



# Regenerate the L1 genesis file if necessary. The existence of the genesis
# file is used to determine if we need to recreate the devnet's state folder.
if [ ! -f "$DATA/done" ]; then
  echo "Regenerating genesis files"

  mkdir -p $DATA/deploy
  (
    cd "$OP_NODE"

    # Ensure contracts are deployed, this should already be there
    # deployContracts

    go run cmd/main.go genesis l2 \
        --deploy-config $DEPLOYMENT_CONFIG \
        --deployment-dir "$CONTRACTS_BEDROCK/deployments/getting-started" \
        --outfile.l2 $DATA/genesis.json \
        --outfile.rollup $DATA/rollup.json \
        --l1-rpc $L1_RPC
    touch "$DATA/done"
  )
fi

echo "Building images..."
pushd ops-bedrock-goerli
L2OO_ADDRESS="$L2OO_ADDRESS" \
  SEQ_KEY="$SEQ_KEY" \
  PROPOSER_KEY="$PROPOSER_KEY" \
  BATCHER_KEY="$BATCHER_KEY" \
  DA_ACCOUNT="$DA_ACCOUNT" \
  DA_CONTRACT="$DA_CONTRACT" \
  L1_RPC="$L1_RPC" DOCKER_BUILDKIT=1 $COMPOSE build

echo "Bringing up blockscout..."
$COMPOSE up -d blockscout
popd

# # Bring up L2.
# (
#   cd ops-bedrock-goerli
#   echo "Bringing up L2..."
#   SEQ_KEY="$SEQ_KEY" \
#      $COMPOSE up -d l2
#   wait_up $L2_URL
# )


# # Bring up everything else.
(
  cd ops-bedrock-goerli
  echo "Bringing up devnet..."
  L2OO_ADDRESS="$L2OO_ADDRESS" \
  SEQ_KEY="$SEQ_KEY" \
  PROPOSER_KEY="$PROPOSER_KEY" \
  BATCHER_KEY="$BATCHER_KEY" \
  DA_ACCOUNT="$DA_ACCOUNT" \
  DA_CONTRACT="$DA_CONTRACT" \
  L1_RPC="$L1_RPC" \
      $COMPOSE up -d op-proposer op-batcher

  echo "Bringing up stateviz webserver..."
  $COMPOSE up -d stateviz
)

# echo "Testnet ready."
