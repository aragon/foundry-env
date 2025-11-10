# OSx Project Manager for Foundry

**Standardized, network-ready Foundry setups — zero configuration needed.**

This repository provides a **reusable foundation** for all Aragon OSx projects built with Foundry. It delivers:

- A **pre-configured `base.mk` Makefile** that handles network switching, deployment, verification, and testing — no more copy-pasting boilerplate.
- **Network-specific `.env` files** for every supported chain (mainnet, sepolia, arbitrum, etc.) — with correct RPC URLs, chain IDs, Etherscan keys, and Aragon OSx contract addresses pre-filled.
- **Consistent, battle-tested configuration** across all your repos.
- A **one stop shop** to run commands.

### Why use this?

Most Aragon plugins need to:
- Be deployed to multiple networks
- Verify contracts on Etherscan
- Reference the same core Aragon OSx addresses
- Use consistent secrets and environment variables

**This repo eliminates the repetitive, error-prone setup.** Just add it as a submodule and your project inherits a standard, multi-network toolkit.

### Get started

```sh
# Add the submodule
git submodule add git@github.com:aragon/foundry-env.git lib/foundry-env
```

Create a minimal `Makefile`:

```make
include .env
include lib/foundry-env/base.mk

# Define your main deployment script here
DEPLOYMENT_SCRIPT := DeployTokenVoting
```

Create an `.env` file with the following secrets:

```env
# Required
# ---------------------
DEPLOYMENT_PRIVATE_KEY="0x..."
ETHERSCAN_API_KEY="..."

# Optional
# ---------------------
ALCHEMY_API_KEY=""  # When the network's RPC_URL uses an Alchemy endpoint

# REFUND_ADDRESS="0x..."  # If using a burner wallet
# PINATA_JWT="" # If pinning data on IPFS
```

Include any additional settings that your scripts need:

```env
PLUGIN_REPO_ADDRESS="0x1AeD2BEb470aeFD65B43f905Bd5371b1E4749d18" # network dependent
PLUGIN_REPO_MAINTAINER_ADDRESS="0x051D2BEb470aeFD65B43f905Bd5371b1E4749d14" # network dependent
# PLUGIN_ENS_SUBDOMAIN=""

RELEASE_METADATA_URI="ipfs://QmWjZArvePnMPgbfKAMW3TidbqHEy68UV6SvRBhiaygGta"
BUILD_METADATA_URI="ipfs://QmfXUy5Lc4iqg8DvgWdSSD2ZhCmCGvE2WTdWYFE9sosCRc"
```

Finally, initialize your Foundry project with the appropriate network:

```sh
make init network=sepolia
```

## Task runner

With the project set up, you can run `make` and you will be greeted with a list of available tasks:

```
Available recipes:

  make init                 Prepare the project dependencies            [network="..."]
  make switch               Starts using the given network's .env       [network="..."]
  make clean                Clean the compiler artifacts

Testing:

  make test                 Run unit tests                       [optional: v="v1_2_0"]
  make test-integration     Run integration tests                [optional: v="v1_2_0"]
  make test-unint           Run unit + integration tests         [optional: v="v1_2_0"]
  make test-invariant       Run invariant tests                  [optional: v="v1_2_0"]
  make test-upgrades        Run regression/upgrade tests         [optional: v="v1_2_0"]

  make test-fork            Run fork tests (using RPC_URL)
  make test-fork-mint       Run fork tests (minting tokens)
  make test-fork-existing   Run fork tests (existing factory)
  make test-fork-exmint     Run fork tests (existing factory + minting tokens)
  make test-coverage        Generate an HTML test coverage report under ./report

Deployment:

  make predeploy            Simulate a plugin deployment
  make deploy               Deploy the plugin, verify the code and write to ./artifacts
  make resume               Retry a pending deployment, verify the code and write to ./artifacts

  make anvil                Starts a forked EVM, using RPC_URL   [optional: .env FORK_BLOCK_NUMBER]
  make refund               Transfer the balance left on the deployment account

  make help                 Show the main recipes

Custom commands:

  make my-command           Description of my-command

```

## Adding new commands

If your project needs custom commands, edit your `Makefile` and append a task as follows:

```make
include .env
include lib/foundry-env/base.mk

# Define your main deployment script here
DEPLOYMENT_SCRIPT := DeployTokenVoting

## Custom commands:

.PHONY: my-command
my-command: ## Description of my-command
	echo "This is $(@)"
```

## What's included

The `base.mk` file is in charge of *computing* the commands to run, given the environment variables defined.

For every (supported) network, the wollowing `make` and `env` variables are provided:

```env
# Used by Foundry
RPC_URL="https://eth-sepolia.g.alchemy.com/v2/__ALCHEMY_API_KEY__"
CHAIN_ID="11155111"

# Used for log file names
NETWORK_NAME="sepolia"

# Verification
VERIFIER="etherscan"
# BLOCKSCOUT_HOST_NAME="..."  # When applicable

# OSx deployment
DAO_FACTORY_ADDRESS="0xB815791c233807D39b7430127975244B36C19C8e"
PLUGIN_REPO_FACTORY_ADDRESS="0x399Ce2a71ef78bE6890EB628384dD09D4382a7f0"
PLUGIN_SETUP_PROCESSOR_ADDRESS="0xC24188a73dc09aA7C721f96Ad8857B469C01dC9f"

MANAGEMENT_DAO_ADDRESS="0xCa834B3F404c97273f34e108029eEd776144d324"
MANAGEMENT_DAO_MULTISIG_ADDRESS="0xfcEAd61339e3e73090B587968FcE8b090e0600EF"
```

For networks where the `RPC_URL` variable uses an Alchemy endpoint, make sure that your `.env` file includes the `ALCHEMY_API_KEY="..."` secret.

## I want to override a value

If the `.env` file for the current network provides a value that you would like to change, you have two options:

For ad-hoc situations, the simplest way is to edit `lib/foundry-env/networks/.../.env` directly. Changes will be lost when you check out the `foundry-env` subrepo again.

For a more general solution, you may create an overrides file and include it after `base.mk`:

```make
include .env
include lib/foundry-env/base.mk

# Add these lines:

# This will define `make` variables
include .env.override
# Export as environment variables for the commands launched
export RPC_URL:=$(RPC_URL)
export VERIFIER:=$(VERIFIER)

# ...
```

## Documentation & Support

- [Aragon OSx Docs](https://docs.aragon.org/osx/)
- [TokenVoting Plugin](https://github.com/aragon/token-voting-plugin)
- [Foundry Book](https://getfoundry.sh/)

## Contributing

Found a missing address or outdated config? Open an issue or PR!
