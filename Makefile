COMPOSEFLAGS=-d
ITESTS_L2_HOST=http://localhost:9545
BEDROCK_TAGS_REMOTE?=origin

build: build-go build-ts
.PHONY: build

build-go: submodules op-node op-proposer op-batcher
.PHONY: build-go

build-ts: submodules
	if [ -n "$$NVM_DIR" ]; then \
		. $$NVM_DIR/nvm.sh && nvm use; \
	fi
	yarn install
	yarn build
.PHONY: build-ts

submodules:
	# CI will checkout submodules on its own (and fails on these commands)
	if [ -z "$$GITHUB_ENV" ]; then \
		git submodule init; \
		git submodule update; \
	fi
.PHONY: submodules

private-module:
	# Set the GOPRIVATE env var to allow private modules to be fetched
	go env -w GOPRIVATE="github.com/near/rollup-data-availability"

op-bindings:
	make -C ./op-bindings
.PHONY: op-bindings

op-node: private-module
	make -C ./op-node op-node
.PHONY: op-node

op-batcher: private-module
	make -C ./op-batcher op-batcher
.PHONY: op-batcher

op-proposer: private-module
	make -C ./op-proposer op-proposer
.PHONY: op-proposer

op-program:
	make -C ./op-program op-program
.PHONY: op-program

mod-tidy:
	# Below GOPRIVATE line allows mod-tidy to be run immediately after
	# releasing new versions. This bypasses the Go modules proxy, which
	# can take a while to index new versions.
	#
	# See https://proxy.golang.org/ for more info.
	export GOPRIVATE="github.com/ethereum-optimism" && go mod tidy
.PHONY: mod-tidy

clean:
	rm -rf ./bin
.PHONY: clean

nuke: clean devnet-clean
	git clean -Xdf
.PHONY: nuke

devnet-genesis:
	@bash ./ops-bedrock/devnet-genesis-entrypoint.sh

devnet-up:
	@bash ./ops-bedrock/devnet-up.sh
.PHONY: devnet-up

testnet-up:
	@bash ./ops-bedrock/testnet-up.sh
.PHONY: testnet-up

goerli-up:
	@bash ./ops-bedrock-goerli/up.sh
.PHONY: goerli-up

upgrade-near-components:
	go get github.com/dndll/near-openrpc@near

devnet-up-deploy:
	PYTHONPATH=./bedrock-devnet python3 ./bedrock-devnet/main.py --monorepo-dir=.
.PHONY: devnet-up-deploy

devnet-down:
	@(cd ./ops-bedrock && GENESIS_TIMESTAMP=$(shell date +%s) docker compose -f docker-compose-devnet.yml stop)
.PHONY: devnet-down

testnet-down:
	@(cd ./ops-bedrock && GENESIS_TIMESTAMP=$(shell date +%s) docker compose -f docker-compose-testnet.yml stop)
.PHONY: testnet-down

goerli-down:
	@(cd ./ops-bedrock-goerli && GENESIS_TIMESTAMP=$(shell date +%s) docker compose stop)
.PHONY: goerli-down

devnet-clean:
	rm -rf ./packages/contracts-bedrock/deployments/devnetL1
	rm -rf ./.devnet
	cd ./ops-bedrock && docker compose -f docker-compose-devnet.yml down
	docker image ls 'ops-bedrock*' --format='{{.Repository}}' | xargs -r docker rmi
	docker volume ls --filter name=ops-bedrock --format='{{.Name}}' | xargs -r docker volume rm
.PHONY: devnet-clean

testnet-clean:
	rm -rf ./packages/contracts-bedrock/deployments/devnetL1
	rm -rf ./.devnet
	cd ./ops-bedrock && docker compose -f docker-compose-testnet.yml down
	docker image ls 'ops-bedrock*' --format='{{.Repository}}' | xargs -r docker rmi
	docker volume ls --filter name=ops-bedrock --format='{{.Name}}' | xargs -r docker volume rm
.PHONY: testnet-clean

goerli-clean:
	rm -rf ./.goerli
	cd ./ops-bedrock-goerli && docker compose down
	docker image ls 'ops-bedrock*' --format='{{.Repository}}' | xargs -r docker rmi
	docker volume ls --filter name=ops-bedrock --format='{{.Name}}' | xargs -r docker volume rm
.PHONY: goerli-clean

devnet-logs:
	# @(cd ./ops-bedrock && docker-compose -f docker-compose-devnet.yml logs -f)
	@(cd ./ops-bedrock && docker compose -f docker-compose-devnet.yml logs -f)
	.PHONY: devnet-logs

testnet-logs:
	@(cd ./ops-bedrock && docker compose -f docker-compose-testnet.yml logs -f)
	.PHONY: testnet-logs

test-unit:
	make -C ./op-node test
	make -C ./op-proposer test
	make -C ./op-batcher test
	make -C ./op-e2e test
	yarn test
.PHONY: test-unit

test-integration:
	bash ./ops-bedrock/test-integration.sh \
		./packages/contracts-bedrock/deployments/devnetL1
.PHONY: test-integration

# Remove the baseline-commit to generate a base reading & show all issues
semgrep:
	$(eval DEV_REF := $(shell git rev-parse develop))
	SEMGREP_REPO_NAME=ethereum-optimism/optimism semgrep ci --baseline-commit=$(DEV_REF)
.PHONY: semgrep

clean-node-modules:
	rm -rf node_modules
	rm -rf packages/**/node_modules

tag-bedrock-go-modules:
	./ops/scripts/tag-bedrock-go-modules.sh $(BEDROCK_TAGS_REMOTE) $(VERSION)
.PHONY: tag-bedrock-go-modules

update-op-geth:
	./ops/scripts/update-op-geth.py
.PHONY: update-op-geth

TAG_PREFIX := us-docker.pkg.dev/pagoda-solutions-dev/rollup-data-availability
IMAGE_TAG := 0.1.0

op-devnet-genesis-docker:
	DOCKER_BUILDKIT=1 docker build --progress=plain -t $(TAG_PREFIX)/op-genesis-builder:$(IMAGE_TAG) -f ops-bedrock/Dockerfile.genesis ./
	docker tag $(TAG_PREFIX)/op-genesis-builder:$(IMAGE_TAG) $(TAG_PREFIX)/op-genesis-builder:latest
.PHONY: op-devnet-genesis-docker

op-devnet-genesis:
	docker run -it --rm --platform linux/arm64 -v ${PWD}:/work -w /work $(TAG_PREFIX)/op-genesis-builder make devnet-genesis
.PHONY: op-devnet-genesis

op-devnet-da-logs:
	docker compose -f ops-bedrock/docker-compose-devnet.yml logs op-batcher | grep NEAR
	docker compose -f ops-bedrock/docker-compose-devnet.yml logs op-node | grep NEAR

COMMAND = docker buildx build -t
bedrock-images:
	$(COMMAND) "$(TAG_PREFIX)/op-node:$(IMAGE_TAG)" -f op-node/Dockerfile .
	docker tag "$(TAG_PREFIX)/op-node:$(IMAGE_TAG)" "$(TAG_PREFIX)/op-node:latest"

	$(COMMAND) "$(TAG_PREFIX)/op-batcher:$(IMAGE_TAG)" -f op-batcher/Dockerfile .
	docker tag "$(TAG_PREFIX)/op-batcher:$(IMAGE_TAG)" "$(TAG_PREFIX)/op-batcher:latest"

	$(COMMAND) "$(TAG_PREFIX)/op-proposer:$(IMAGE_TAG)" -f op-proposer/Dockerfile .
	docker tag "$(TAG_PREFIX)/op-proposer:$(IMAGE_TAG)" "$(TAG_PREFIX)/op-proposer:latest"

	$(COMMAND) "$(TAG_PREFIX)/op-l1:$(IMAGE_TAG)" -f ops-bedrock/Dockerfile.l1 ops-bedrock
	docker tag "$(TAG_PREFIX)/op-l1:$(IMAGE_TAG)" "$(TAG_PREFIX)/op-l1:latest"

	$(COMMAND) "$(TAG_PREFIX)/op-l2:$(IMAGE_TAG)" -f ops-bedrock/Dockerfile.l2 ops-bedrock
	docker tag "$(TAG_PREFIX)/op-l2:$(IMAGE_TAG)" "$(TAG_PREFIX)/op-l2:latest"

	$(COMMAND) "$(TAG_PREFIX)/op-stateviz:$(IMAGE_TAG)" -f ops-bedrock/Dockerfile.stateviz  .
	docker tag "$(TAG_PREFIX)/op-stateviz:$(IMAGE_TAG)" "$(TAG_PREFIX)/op-stateviz:latest"
.PHONY: bedrock-images

push-bedrock-images:
	docker push "$(TAG_PREFIX)/op-node:$(IMAGE_TAG)"
	docker push "$(TAG_PREFIX)/op-batcher:$(IMAGE_TAG)"
	docker push "$(TAG_PREFIX)/op-proposer:$(IMAGE_TAG)"
	docker push "$(TAG_PREFIX)/op-l1:$(IMAGE_TAG)"
	docker push "$(TAG_PREFIX)/op-l2:$(IMAGE_TAG)"
	docker push "$(TAG_PREFIX)/op-stateviz:$(IMAGE_TAG)"
.PHONY: push-bedrock-images


