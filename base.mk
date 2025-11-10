# NOTE:
# This file is meant to be imported from the root folder of other repositories.
# Paths will be relative to the importing path

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Load the network's .env file as "make" variables (when possible)
FOUNDRY_ENV_DIR := $(dir $(filter %/base.mk,$(MAKEFILE_LIST)))
FOUNDRY_ENV_DIR := $(patsubst %/,%,${FOUNDRY_ENV_DIR})
-include $(FOUNDRY_ENV_DIR)/.env

# Load the .env file from the project root
-include .env

# CONSTANTS

SUPPORTED_VERIFIERS := etherscan blockscout sourcify zksync routescan-mainnet routescan-testnet
SUPPORTED_NETWORKS := $(shell ls $(FOUNDRY_ENV_DIR)/networks | xargs echo)
ARTIFACTS_FOLDER := ./artifacts
LOGS_FOLDER := ./logs

# Helper functions
trim_quotes = $(strip $(subst ',,$(subst ",,$1)))

# Remove quotes
VERIFIER := $(call trim_quotes,$(VERIFIER))
CHAIN_ID := $(call trim_quotes,$(CHAIN_ID))
NETWORK_NAME := $(call trim_quotes,$(NETWORK_NAME))
BLOCKSCOUT_HOST_NAME := $(call trim_quotes,$(BLOCKSCOUT_HOST_NAME))
DEPLOYMENT_PRIVATE_KEY := $(call trim_quotes,$(DEPLOYMENT_PRIVATE_KEY))

FORK_BLOCK_NUMBER := $(call trim_quotes,$(FORK_BLOCK_NUMBER))
DEPLOYMENT_SCRIPT := $(call trim_quotes,$(DEPLOYMENT_SCRIPT))

# Inject API keys (if available)
ifneq ($(ALCHEMY_API_KEY),)
    RPC_URL := $(subst __ALCHEMY_API_KEY__,$(call trim_quotes,$(ALCHEMY_API_KEY)),$(RPC_URL))
endif
ifneq ($(INFURA_API_KEY),)
    RPC_URL := $(subst __INFURA_API_KEY__,$(call trim_quotes,$(INFURA_API_KEY)),$(RPC_URL))
endif

# Compute the address (if possible)
ifneq ($(DEPLOYMENT_PRIVATE_KEY),)
    DEPLOYMENT_ADDRESS := $(shell cast wallet address --private-key $(DEPLOYMENT_PRIVATE_KEY) 2>/dev/null)
endif
DEPLOYMENT_LOG_FILE := $(LOGS_FOLDER)/deployment-$(NETWORK_NAME)-$(shell date +"%y-%m-%d-%H-%M").log

# Validation (if non-empty)

ifeq ($(network),) # CLI argument
else ifeq ($(filter $(network),$(SUPPORTED_NETWORKS)),)
    $(error Unsupported network: $(network). It can be one of: $(SUPPORTED_NETWORKS))
endif

ifeq ($(VERIFIER),) # .env variable
else ifeq ($(filter $(VERIFIER),$(SUPPORTED_VERIFIERS)),)
    $(error Unknown verifier: $(VERIFIER). It can be one of: $(SUPPORTED_VERIFIERS))
endif

# Conditional assignments

# Verification backend
ifeq ($(VERIFIER), etherscan)
	VERIFIER_URL := https://api.etherscan.io/api
	VERIFIER_API_KEY := $(ETHERSCAN_API_KEY)
	VERIFIER_PARAMS := --verifier $(VERIFIER) --etherscan-api-key $(ETHERSCAN_API_KEY)
else ifeq ($(VERIFIER), blockscout)
	VERIFIER_URL := https://$(BLOCKSCOUT_HOST_NAME)/api\?
	VERIFIER_API_KEY := ""
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url "$(VERIFIER_URL)"
else ifeq ($(VERIFIER), sourcify)
	# Inhibit it, so that Foundry doesn't switch to Etherscan, regardless
	export ETHERSCAN_API_KEY:=""
else ifeq ($(VERIFIER), zksync)
	ifeq ($(CHAIN_ID),300)
		VERIFIER_URL := https://explorer.sepolia.era.zksync.dev/contract_verification
	else ifeq ($(CHAIN_ID),324)
	    VERIFIER_URL := https://zksync2-mainnet-explorer.zksync.io/contract_verification
	endif
	VERIFIER_API_KEY := ""
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url "$(VERIFIER_URL)"
else ifneq ($(filter $(VERIFIER), routescan-mainnet routescan-testnet),)
	ifeq ($(VERIFIER), routescan-mainnet)
		VERIFIER_URL := https://api.routescan.io/v2/network/mainnet/evm/$(CHAIN_ID)/etherscan
	else
		VERIFIER_URL := https://api.routescan.io/v2/network/testnet/evm/$(CHAIN_ID)/etherscan
	endif

	VERIFIER := custom
	VERIFIER_API_KEY := "verifyContract"
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url '$(VERIFIER_URL)' --etherscan-api-key $(VERIFIER_API_KEY)
endif

# Chain-dependent parameters
ifeq ($(CHAIN_ID),88888)
	FORGE_SCRIPT_CUSTOM_PARAMS := --priority-gas-price 1000000000 --gas-price 5200000000000
else ifeq ($(CHAIN_ID),300)
	FORGE_SCRIPT_CUSTOM_PARAMS := --slow
	FORGE_BUILD_CUSTOM_PARAMS := --zksync
else ifeq ($(CHAIN_ID),324)
	FORGE_SCRIPT_CUSTOM_PARAMS := --slow
	FORGE_BUILD_CUSTOM_PARAMS := --zksync
endif

# Fork testing parameters
ifneq ($(FORK_BLOCK_NUMBER),)
	FORK_TEST_PARAMS := --fork-block-number $(FORK_BLOCK_NUMBER)
endif

# Exported env variables

export DAO_FACTORY_ADDRESS:=$(call trim_quotes,$(DAO_FACTORY_ADDRESS))
export PLUGIN_REPO_FACTORY_ADDRESS:=$(call trim_quotes,$(PLUGIN_REPO_FACTORY_ADDRESS))
export PLUGIN_SETUP_PROCESSOR_ADDRESS:=$(call trim_quotes,$(PLUGIN_SETUP_PROCESSOR_ADDRESS))
export MANAGEMENT_DAO_ADDRESS:=$(call trim_quotes,$(MANAGEMENT_DAO_ADDRESS))
export MANAGEMENT_DAO_MULTISIG_ADDRESS:=$(call trim_quotes,$(MANAGEMENT_DAO_MULTISIG_ADDRESS))

# TARGETS

.PHONY: init
init: ## Prepare the project dependencies            [network="..."]
	@if [ ! -f $(FOUNDRY_ENV_DIR)/.env ] && [ "$(network)" == "" ]; then \
		echo "Please, select the network to use:"; \
		echo "  $$ make init network=sepolia"; \
		echo; \
		exit 1; \
	fi
	@if [ "$(network)" != "" ]; then \
		make switch network=$(network) ; \
	fi
	@which forge > /dev/null || make install-foundry
	@make init-keystore
	forge build $(FORGE_BUILD_CUSTOM_PARAMS) --sizes

.PHONY: switch
switch: ## Starts using the given network's .env       [network="..."]
	@if [ "$(network)" == "" ]; then \
		echo "Usage:" ; \
		echo "  $$ make switch network=<name>" ; \
		echo ; \
		echo "Supported networks:" ; \
		echo -n "  " ; \
		ls $(FOUNDRY_ENV_DIR)/networks/ | xargs echo ; \
		echo ; \
		exit 1 ; \
	fi
	rm -f $(FOUNDRY_ENV_DIR)/.env
	ln -s ./networks/$(network)/.env  $(FOUNDRY_ENV_DIR)/.env

.PHONY: clean
clean: ## Clean the compiler artifacts
	forge clean
	rm -Rf ./out ./zkout lcov.info* ./report

## Testing:

# Giving a default value to the inline filters:
# - make test             =>  v = "**"
# - make test v="v1_2_0"  =>  v = "v1_2_0"

test: v ?= **
test-unint: v ?= **
test-invariant: v ?= **
test-upgrades: v ?= **

.PHONY: test
test: ## Run unit tests                       [optional: v="v1_2_0"]
	@make local-test path="test/$(v)/unit/**/*.sol"

.PHONY: test-integration
test-integration: ## Run integration tests                [optional: v="v1_2_0"]
	@make local-test path="test/$(v)/integration/**/*.sol"

.PHONY: test-unint
test-unint: ## Run unit + integration tests         [optional: v="v1_2_0"]
	@make local-test path="test/$(v)/{unit,integration}/**/*.sol"

.PHONY: test-invariant
test-invariant: ## Run invariant tests                  [optional: v="v1_2_0"]
	@make local-test path="test/$(v)/invariant/**/*.sol" extra_args="--show-progress"

.PHONY: test-upgrades
test-upgrades: ## Run regression/upgrade tests         [optional: v="v1_2_0"]
	@make local-test path="test/$(v)/upgrade/**/*.sol" extra_args="--force --ffi"

##

.PHONY: test-fork
test-fork: ## Run fork tests (using RPC_URL)
	forge test $(FORGE_BUILD_CUSTOM_PARAMS) --rpc-url $(RPC_URL) --match-path './test/*/fork/*.sol'

.PHONY: test-fork-mint
test-fork-mint: ## Run fork tests (minting tokens)
	@MINT_TEST_TOKENS=true ; make test-fork

.PHONY: test-fork-existing
test-fork-existing: ## Run fork tests (existing factory)
	@FORK_TEST_MODE='existing-factory' ; make test-fork

.PHONY: test-fork-exmint
test-fork-exmint: ## Run fork tests (existing factory + minting tokens)
	@MINT_TEST_TOKENS=true; FORK_TEST_MODE='existing-factory' ; make test-fork

.PHONY: test-coverage
test-coverage: report/index.html ## Generate an HTML test coverage report under ./report
	@which lcov > /dev/null || (echo "Note: lcov can be installed by running 'sudo apt install lcov'" ; exit 1)
	@echo "Skipping test, script, src/escrow/increasing/delegation and proxylib from the coverage report"
	forge coverage --match-path "test/v1_4_0/unit/escrow/queue/**/*.sol" --report lcov && \
		lcov --remove ./lcov.info -o ./lcov.info.pruned \
			'test/**/*.sol' 'script/**/*.sol' 'test/*.sol' \
			'script/*.sol' 'src/escrow/increasing/delegation/*.sol' \
			'src/libs/ProxyLib.sol' && \
		genhtml lcov.info.pruned -o report --branch-coverage
	@which open > /dev/null && open report/index.html || true
	@which xdg-open > /dev/null && xdg-open report/index.html || true

## Deployment:

.PHONY: predeploy
predeploy: ## Simulate a plugin deployment
	@echo "Simulating the deployment"

	@make simulate-script name="$(DEPLOYMENT_SCRIPT)"

.PHONY: deploy
deploy: test ## Deploy the plugin, verify the code and write to ./artifacts
	@echo "Starting the deployment"
	@mkdir -p $(LOGS_FOLDER) $(ARTIFACTS_FOLDER)

	@make run-script name="$(DEPLOYMENT_SCRIPT)" \
	    2>&1 | tee -a $(DEPLOYMENT_LOG_FILE)

	echo "Logs saved in $(DEPLOYMENT_LOG_FILE)"

.PHONY: resume
resume: test ## Retry a pending deployment, verify the code and write to ./artifacts
	@echo "Retrying the deployment"
	@mkdir -p $(LOGS_FOLDER) $(ARTIFACTS_FOLDER)

	@make run-script name="$(DEPLOYMENT_SCRIPT)" \
		extra_args="--resume" \
	    2>&1 | tee -a $(DEPLOYMENT_LOG_FILE)

	echo "Logs saved in $(DEPLOYMENT_LOG_FILE)"

##

anvil: ## Starts a forked EVM, using RPC_URL   [optional: .env FORK_BLOCK_NUMBER]
	anvil -f $(RPC_URL) $(FORK_TEST_PARAMS)


refund: export DEPLOYMENT_PRIVATE_KEY:=$(DEPLOYMENT_PRIVATE_KEY)

.PHONY: refund
refund: ## Transfer the balance left on the deployment account
	@echo "Refunding the balance left on $(DEPLOYMENT_ADDRESS)"
	@if [ -z $(REFUND_ADDRESS) -o $(REFUND_ADDRESS) = "0x0000000000000000000000000000000000000000" ]; then \
		echo "- The refund address is empty" ; exit 1; \
	fi
	@BALANCE=$(shell cast balance $(DEPLOYMENT_ADDRESS) --rpc-url $(RPC_URL)) && \
		GAS_PRICE=$(shell cast gas-price --rpc-url $(RPC_URL)) && \
		SPENDABLE=$$(echo "$$BALANCE - $$GAS_PRICE * 50000" | bc) && \
		ENOUGH_BALANCE=$$(echo "$$SPENDABLE > 0" | bc) && \
		\
		if [ "$$ENOUGH_BALANCE" = "0" ]; then \
			echo -e "- Cannot refund:   $$BALANCE wei\n- Minimum balance: $${SPENDABLE:1} wei" ; exit 1; \
		fi ; \
		\
		echo -n -e "Summary:\n- Refunding:  $$SPENDABLE (wei)\n- Recipient:  $(REFUND_ADDRESS)\n\nContinue? (y/N) " && \
		\
		read CONFIRM && \
		if [ "$$CONFIRM" != "y" ]; then echo "Aborting" ; exit 1; fi ; \
		\
		cast send --private-key $$DEPLOYMENT_PRIVATE_KEY \
			--rpc-url $(RPC_URL) \
			--value $$SPENDABLE \
			$(REFUND_ADDRESS)

##

ACCENT := \e[33m
LIGHTER := \e[37m
NORMAL := \e[0m
COLUMN_START := 20

.PHONY: help
help: ## Show the main recipes
	@echo -e "Available recipes:\n"
	@cat lib/foundry-env/base.mk Makefile | while IFS= read -r line; do \
		if [[ "$$line" == "##" ]]; then \
			echo "" ; \
		elif [[ "$$line" =~ ^##\ (.*)$$ ]]; then \
			printf "\n$${BASH_REMATCH[1]}\n\n" ; \
		elif [[ "$$line" =~ ^([^:#]+):(.*)##\ (.*)$$ ]]; then \
			printf "  make $(ACCENT)%-*s$(LIGHTER) %s$(NORMAL)\n" $(COLUMN_START) "$${BASH_REMATCH[1]}" "$${BASH_REMATCH[3]}" ; \
		fi ; \
	done

# Troubleshooting helpers

.PHONY: gas-price
gas-price:
	@echo "Gas price ($(NETWORK_NAME)):"
	@cast gas-price --rpc-url $(RPC_URL)

.PHONY: balance
balance:
	@echo "Balance of $(DEPLOYMENT_ADDRESS) ($(NETWORK_NAME)):"
	@BALANCE=$$(cast balance $(DEPLOYMENT_ADDRESS) --rpc-url $(RPC_URL)) && \
		cast --to-unit $$BALANCE ether

.PHONY: clean-nonces
clean-nonces: # make clean-nonces nonces="2 3 4 5"
	for nonce in $(nonces); do \
	  make clean-nonce nonce=$$nonce ; \
	done

clean-nonce: export DEPLOYMENT_PRIVATE_KEY:=$(DEPLOYMENT_PRIVATE_KEY)

.PHONY: clean-nonce
clean-nonce: # make clean-nonce nonce=3
	@cast send --private-key $$DEPLOYMENT_PRIVATE_KEY \
		--rpc-url $(RPC_URL) \
		--value 0 \
		--nonce $(nonce) \
		$(DEPLOYMENT_ADDRESS)

# Internal helpers

# Running the following tests faster, unsetting the API key
local-test: export ETHERSCAN_API_KEY:=""

.PHONY: local-test
local-test:
	@echo ETHERSCAN_API_KEY=\"\"
	forge test $(FORGE_BUILD_CUSTOM_PARAMS) --match-path "$(path)" $(extra_args)


# Set the SIMULATE variable so that launched scripts can skip writing deployment artifacts
simulate-script: export SIMULATION:=true

# Example:
# make simulate-script name="MyScriptName"
.PHONY: simulate-script
simulate-script:
	@echo "SIMULATION=true"
	forge script $(name) \
		--rpc-url $(RPC_URL) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS)

# Example:
# make run-script name="MyScriptName"
# make run-script name="MyScriptName" extra_args="--resume"
.PHONY: run-script
run-script: test
	forge script $(name) \
		--rpc-url $(RPC_URL) \
		--retries 10 \
		--delay 10 \
		--broadcast \
		--verify \
		$(VERIFIER_PARAMS) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(extra_args)

.PHONY: install-foundry
install-foundry:
	@echo "Installing Foundry..."
	curl -L https://foundry.paradigm.xyz | bash

# .PHONY: init-keystore
# init-keystore:
# 	@# DEV (no password)
# 	@if $$(cast wallet list | grep "Develop" > /dev/null) ; then \
# 	    echo "Develop keystore: ready" ; \
# 	else \
# 		echo "Enter the private key of your development wallet (keystore):" ; \
# 		read PRIV_K ; \
# 		cast wallet import "Develop" --private-key "$$PRIV_K" --unsafe-password "" ; \
# 	fi
# 	@# PROD (password protected)
# 	@if $$(cast wallet list | grep "Deploy" > /dev/null) ; then \
# 	    echo "Deploy keystore: ready" ; \
# 	else \
# 		echo "Enter the private key of your deployment wallet (keystore):" ; \
# 		read PRIV_K ; \
# 		cast wallet import "Deploy" --private-key "$$PRIV_K" ; \
# 	fi
