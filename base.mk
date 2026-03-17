# NOTE:
# This file is meant to be imported from the root folder of other repositories.
# Paths will be relative to the importing project's root path

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Load the network's .env file as "make" variables (when possible)
FOUNDRY_ENV_DIR := $(dir $(filter %/base.mk,$(MAKEFILE_LIST)))
FOUNDRY_ENV_DIR := $(patsubst %/,%,${FOUNDRY_ENV_DIR})
-include $(FOUNDRY_ENV_DIR)/.env

# Helper functions
trim_quotes = $(strip $(subst ',,$(subst ",,$1)))

# Load project-specific network overrides (e.g., .env.mainnet, .env.sepolia)
-include .env.$(call trim_quotes,$(NETWORK_NAME))

# Load the .env file from the project root
-include .env


# CONSTANTS

SUPPORTED_VERIFIERS := etherscan blockscout sourcify zksync routescan-mainnet routescan-testnet
SUPPORTED_NETWORKS := $(shell ls $(FOUNDRY_ENV_DIR)/networks | xargs echo)
TEST_COVERAGE_SOURCES := $(wildcard test/*.sol test/**/*.sol src/*.sol src/**/*.sol)
ARTIFACTS_FOLDER := ./artifacts
LOGS_FOLDER := ./logs
VERBOSITY ?= -vvv

# Clean constants (env)
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


# VALIDATION (when non-empty)

ifeq ($(network),) # CLI argument
else ifeq ($(filter $(network),$(SUPPORTED_NETWORKS)),)
    $(error Unsupported network: $(network). It can be one of: $(SUPPORTED_NETWORKS))
endif

ifeq ($(VERIFIER),) # .env variable
else ifeq ($(filter $(VERIFIER),$(SUPPORTED_VERIFIERS)),)
    $(error Unknown verifier: $(VERIFIER). It can be one of: $(SUPPORTED_VERIFIERS))
endif


# CONDITIONAL ASSIGNMENTS

# Verification backend
ifeq ($(VERIFIER), etherscan)
	VERIFIER_URL := https://api.etherscan.io/v2/api
	VERIFIER_API_KEY := $(ETHERSCAN_API_KEY)
	VERIFIER_PARAMS := --verifier $(VERIFIER) --etherscan-api-key $(ETHERSCAN_API_KEY)
else ifeq ($(VERIFIER), blockscout)
	VERIFIER_URL := https://$(BLOCKSCOUT_HOST_NAME)/api\?
	VERIFIER_API_KEY := ""
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url "$(VERIFIER_URL)"
else ifeq ($(VERIFIER), sourcify)
	# Inhibit it, so that Foundry doesn't switch to Etherscan, regardless
	export ETHERSCAN_API_KEY:=
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
export NETWORK_NAME:=$(NETWORK_NAME)
export CHAIN_ID:=$(CHAIN_ID)

# PUBLIC TARGETS

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
	forge build $(FORGE_BUILD_CUSTOM_PARAMS) --sizes

.PHONY: switch
switch: ## Starts using the given network              [network="..."]
	@if [ "$(network)" == "" ]; then \
		echo "Usage:" ; \
		echo "  $$ make switch network=<name>" ; \
		echo ; \
		echo "Supported networks:" ; \
		echo -n "  " ; \
		echo "$(SUPPORTED_NETWORKS)" ; \
		echo ; \
		exit 1 ; \
	fi
	@rm -f $(FOUNDRY_ENV_DIR)/.env
	@ln -s ./networks/$(network)/.env $(FOUNDRY_ENV_DIR)/.env
	@if [ -f ".env.$(network)" ]; then \
		echo "Using network: $(network) (with .env.$(network) overrides)" ; \
	else \
		echo "Using network: $(network)" ; \
	fi

.PHONY: clean
clean: ## Clean the compiler artifacts
	forge clean
	rm -Rf ./out ./zkout lcov.info* ./report

## Testing:

test-fork: export RPC_URL:=$(RPC_URL)
test-coverage: export RPC_URL:=$(RPC_URL)

.PHONY: test
test: ## Run all tests (local)
	@make run-test-local \
	    args='--no-match-path "./test/*fork*/*.sol"'

.PHONY: test-fork
test-fork: ## Run all fork tests (exporting RPC_URL env)
	@make run-test \
	    args='--match-path "./test/*fork*/*.sol" --rpc-url $(RPC_URL)'

test-coverage: report/index.html ## Generate an HTML coverage report under ./report
	@which open > /dev/null && open report/index.html || true
	@which xdg-open > /dev/null && xdg-open report/index.html || true

report/index.html: lcov.info.pruned
	@which lcov > /dev/null || (echo "Note: lcov can be installed by running 'sudo apt install lcov'" ; exit 1)
	genhtml $(^) -o report

lcov.info.pruned: lcov.info
	lcov --remove $(^) -o $(@) \
		'test/**/*.sol' 'test/*.sol' 'script/**/*.sol' 'script/*.sol'

lcov.info: $(TEST_COVERAGE_SOURCES)
	forge coverage --report lcov

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
resume: test ## Continue a pending deployment, verify the code and write to ./artifacts
	@echo "Retrying the deployment"
	@mkdir -p $(LOGS_FOLDER) $(ARTIFACTS_FOLDER)

	@make run-script name="$(DEPLOYMENT_SCRIPT)" \
		args="--resume" \
	    2>&1 | tee -a $(DEPLOYMENT_LOG_FILE)

	echo "Logs saved in $(DEPLOYMENT_LOG_FILE)"

## General:

anvil: ## Starts a forked EVM, using RPC_URL   [optional: .env FORK_BLOCK_NUMBER]
	anvil -f $(RPC_URL) $(FORK_TEST_PARAMS)

refund: export DEPLOYMENT_PRIVATE_KEY:=$(DEPLOYMENT_PRIVATE_KEY)

.PHONY: storage-info
storage-info: ## Show the storage layout of a contract
	@if [ -z "$(src)" ] ; then \
		printf "Usage:\n   $$ make $(@) src=./MyContract.t.sol\n" ; \
		exit 1 ; \
	fi
	forge inspect $(src) storageLayout

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


# TROUBLESHOOTING HELPERS

ENV_FILES = $(wildcard $(FOUNDRY_ENV_DIR)/.env .env.$(NETWORK_NAME) .env)

.PHONY: env
env: ## Show the current environment variables
	@if [ -z "$(ENV_FILES)" ]; then echo "No env files found"; exit 1; fi
	@awk -f $(FOUNDRY_ENV_DIR)/scripts/show-env.awk $(ENV_FILES)

.PHONY: gas-price
gas-price:
	@echo "Gas price ($(NETWORK_NAME)):"
	@cast gas-price --rpc-url $(RPC_URL)

.PHONY: balance
balance:
	@echo "Balance of $(DEPLOYMENT_ADDRESS) ($(NETWORK_NAME)):"
	@BALANCE=$$(cast balance $(DEPLOYMENT_ADDRESS) --rpc-url $(RPC_URL)) && \
		cast --to-unit $$BALANCE ether

.PHONY: nonce
nonce:
	cast nonce $(DEPLOYMENT_ADDRESS) --rpc-url $(RPC_URL)

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


# INTERNAL HELPERS

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
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(VERBOSITY)

# Example:
# make run-script name="MyScriptName"
# make run-script name="MyScriptName" args="--resume"
.PHONY: run-script
run-script:
	forge script $(name) \
		--rpc-url $(RPC_URL) \
		--retries 10 \
		--delay 10 \
		--broadcast \
		--verify \
		$(VERIFIER_PARAMS) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(VERBOSITY) $(args)

# Running local tests faster, unsetting the API key
run-test-local: export ETHERSCAN_API_KEY:=

.PHONY: run-test-local
run-test-local:
	@echo ETHERSCAN_API_KEY=\"\"
	forge test $(FORGE_BUILD_CUSTOM_PARAMS) $(VERBOSITY) $(args)

# Test targets (fork ready)
.PHONY: run-test
run-test:
	forge test $(FORGE_BUILD_CUSTOM_PARAMS) $(VERBOSITY) $(args)

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
