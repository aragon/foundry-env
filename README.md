# Foundry ENV for OSx

**Standardized, network-ready Foundry setups for Aragon OSx projects.**

This repository provides a **reusable foundation** for all Aragon OSx projects built with Foundry. It delivers:

- A **pre-configured `base.mk` Makefile** that handles network switching, deployment, verification, and testing — no more copy-pasting boilerplate.
- **Network-specific `.env` files** for every supported chain (mainnet, sepolia, arbitrum, etc.) — with correct RPC URLs, chain IDs, Etherscan keys, and Aragon OSx contract addresses pre-filled.
- **Reference `foundry.toml` files** for each network
- **Consistent, functional configuration** across all your repos.
- A **one stop shop** to run commands.

### Why use this?

Most Aragon plugins need to:
- Be deployed to multiple networks
- Reference the same core Aragon OSx addresses
- Use consistent secrets and environment variables
<!--- Verify contracts on Etherscan-->

**This repo eliminates the repetitive discovery of network specific settings and workarounds.** Add it as a submodule and your project inherits a standard, multi-network toolkit with a single command shell.

### Get started

```sh
# Add the submodule
git submodule add https://github.com/aragon/foundry-env.git lib/foundry-env
```

Create a minimal `Makefile` on your project root:

```make
# Your overrides:

# The contract name of your deployment script (default)
DEPLOYMENT_SCRIPT ?= DeployTokenVoting

# .env is imported by base.mk
include lib/foundry-env/base.mk
```

Next, create the `.env` file with your secrets and settings:

```env
# Required
# ---------------------
DEPLOYMENT_PRIVATE_KEY="0x..."
ETHERSCAN_API_KEY="..."

# Optional
# ---------------------

# If the network's RPC_URL uses an Alchemy endpoint
ALCHEMY_API_KEY=""

# FORK_BLOCK_NUMBER=12345

# If using a burner wallet
REFUND_ADDRESS="0x..."
```

Include any additional settings that your scripts need:

```env
PLUGIN_REPO_ADDRESS="0x1AeD2BEb470aeFD65B43f905Bd5371b1E4749d18" # network dependent
PLUGIN_REPO_MAINTAINER_ADDRESS="0x051D2BEb470aeFD65B43f905Bd5371b1E4749d14" # network dependent

RELEASE_METADATA_URI="ipfs://QmWjZArvePnMPgbfKAMW3TidbqHEy68UV6SvRBhiaygGta"
BUILD_METADATA_URI="ipfs://QmfXUy5Lc4iqg8DvgWdSSD2ZhCmCGvE2WTdWYFE9sosCRc"

# PLUGIN_ENS_SUBDOMAIN=""
# PINATA_JWT=""
```

Finally, initialize your Foundry project with the appropriate network:

```sh
make init network=sepolia
```

## Universal task runner

With the project set up, you can run `make` and you will be greeted with a list of available tasks:

```
$ make
Available recipes:

  make init                 Prepare the project dependencies            [network="..."]
  make switch               Starts using the given network              [network="..."]
  make clean                Clean the compiler artifacts

Testing:

  make test                 Run all tests (local)
  make fork-test            Run all fork tests (exporting RPC_URL env)
  make test-coverage        Generate an HTML coverage report under ./report

Deployment:

  make predeploy            Simulate a plugin deployment
  make deploy               Deploy the plugin, verify the code and write to ./artifacts
  make resume               Retry a pending deployment, verify the code and write to ./artifacts

Other:

  make anvil                Starts a forked EVM, using RPC_URL   [optional: .env FORK_BLOCK_NUMBER]
  make refund               Transfer the balance left on the deployment account

  make help                 Show the main recipes
```

## Adding new commands

If your project needs custom commands, edit your `Makefile` and append them as follows:

```make
# .env is imported by base.mk
include lib/foundry-env/base.mk

# The (contract) name of your deployment script
DEPLOYMENT_SCRIPT := DeployTokenVoting

## Custom commands:

.PHONY: my-command
my-command: ## Description of my-command
	echo "Using $(RPC_URL)"

.PHONY: my-script
my-script: ## Running a script by name
	make run-script name=MyCustomScript
```

### Reusing common recipes

The main goal of `foundry-env` is to avoid figuring out the same settings many times for each network. To this end, several recipes are available for you to extend.

#### Running or simulating scripts

```make
.PHONY: preseed
preseed: ## Simulate calling SeedScript
	@echo "Simulating SeedScript"

	@make simulate-script name="SeedScript"

.PHONY: seed
seed: test ## Run the SeedScript and verify any new contracts
	@echo "Running SeedScript"
	@mkdir -p $(LOGS_FOLDER)

	@make run-script name="SeedScript" 2>&1 | tee -a $(LOGS_FOLDER)/seed.log
```

- Extending `make simulate-script` will do a dry run without bradcasting any transaction
- Extending `make run-script` will populate all the necessary settings for the chosen network and broadcast the transactions triggered by the script from the wallet associated to `DEPLOYMENT_PRIVATE_KEY`

#### Running your tests

```make
# Default value for `v` if no `v="..."` is specified
test-fork: v ?= **

.PHONY: test-unit
test-unit: ## Run unit tests
	@make run-test-local \
	    arg='--no-match-path "./test/**/fork/*.sol"'

.PHONY: test-fork
test-fork: ## Run fork tests                       [optional: v="v1_2_0"]
	@make run-test \
	    arg='--match-path "./test/$(v)/fork/*.sol" --rpc-url $(RPC_URL)'
```

Both test helpers provide useful defaults while allowing you to pass extra parameters via `args='...'`.

- Extending `make run-test-local` will unset `ETHERSCAN_API_KEY`, making local tests run faster
- Extending `make run-test` will run tests in default mode, allowing to run fork tests and similar

## Included settings

The `base.mk` file is in charge of *computing* the commands to run, given the network environment variables defined by `lib/foundry-env/.env`.

For every (supported) network, the following variable names are provided:

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

## Overriding default values

If the network's `.env` file provides a value that you need to override, you can do so in your own `.env` file at the project root.

Env variables are imported in this order:

1. Read `lib/foundry-env/networks/<network>/.env`
2. Read `.env.<network>` from the project root (if it exists)
3. Read your `.env` (this overrides any defaults from above)
4. Prepare the `make` commands and arguments

### Per-network project settings

If your project needs custom environment variables that change per network (e.g., contract addresses specific to your project), you can create `.env.<network>` files at the project root:

```env
# .env.mainnet
TAIKO_BRIDGE="0x..."
MY_TOKEN_ADDRESS="0x..."
```

```env
# .env.sepolia
TAIKO_BRIDGE="0x..."
MY_TOKEN_ADDRESS="0x..."
```

These files are automatically loaded when the corresponding network is active, so running `make switch network=mainnet` will pick up `.env.mainnet` without any manual changes.

You can also override `make` variables by passing them as CLI arguments:

```sh
make deploy RPC_URL="https://sepolia.drpc.org"
```

## Self documenting tasks

Using `make` or `make help` is the preferred way to get a useful summary of the available commands.

To expand `make help` with your custom commands, edit your `Makefile` and add comments starting by `##` as shown below:

```make
# This comment is ignored

my-internal-cmd:
	echo "Not part of make help"

# `make help` is triggered when using `##` comments

# The line below will appear as a section title
## My commands:

my-cmd: ## This will appear when running `make help`
	echo "Hi cmd"

# The empty comment below (##) will turn into a separator
##

my-script: dependency ## This will also appear when running `make help`
	echo "Hi script"
```

## Troubleshooting and helpers

While `make help` will show you the tasks with a `##` comment, there are additional troubleshooting helpers available.

Check that the wallet has enough balance:

```sh
$ make balance
Balance of 0x1147557Ed36d902E17b9180BFc144526518e148e (sepolia):
5.51998258705224007
```

Check for gas price spikes:

```sh
$ make gas-price
Gas price (sepolia):
1000015
```

Check the storage layout of a contract:

```sh
make storage-info
```

If some transactions get stuck, replace them by zero transfer's with a higher gas price:

```sh
# Show the current nonce
$ make nonce
```

```sh
# Submit a zero transfer replacement
$ make clean-nonce nonce=27
```

```sh
# Wipe multiple stuck transactions at once:
$ make clean-nonces nonces="2 3 4 5"
```

## Documentation & Support

- [Aragon OSx Docs](https://docs.aragon.org/osx/)
- [Foundry Book](https://getfoundry.sh/)

## Adding new networks

To add support for a new network, open a PR adding a `networks/<name>/.env` file to this repository.

## Contributing

Found a missing address or outdated config? Open an issue or PR!
