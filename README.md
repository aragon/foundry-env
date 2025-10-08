# Aragon Foundry `.env` templates

**A repository for standardized `.env` templates** used in Foundry-based Solidity projects.
Save time. Avoid misconfigurations.

## Overview

This repository provides pre-configured `.env` and `foundry.toml` files for Foundry projects interacting with the Aragon OSx protocol. It centralizes:

- Network configuration (RPC URLs, chain IDs, explorers)
- Source code verification parameters for Etherscan and other block explorers
- Commonly used Aragon OSx contract addresses (DAOFactory, PluginRepoFactory, PluginSetupProcessor)
- Example environment variables for the **TokenVoting plugin**

Use these templates to bootstrap your Aragon OSx repository quickly — no more redundant searches or copying from old repos!

## Included Files

Every supported network has a template env file located on the [./networks/](./networks) folder.

💡 Use `cp networks/mainnet/.env path/to/project/.env` to start a new project. Then define the private values as needed.

## Key Variables

### Configuration

```env
# NETWORK AND ACCOUNT(s)
# ---------------------------------------------------
DEPLOYMENT_PRIVATE_KEY="" # REQUIRED
REFUND_ADDRESS=""

# Used by Foundry
RPC_URL="https://eth-mainnet.g.alchemy.com/v2/__API_KEY__"
CHAIN_ID="1"

# Used for log file names
NETWORK_NAME="mainnet"

# SOURCE VERIFICATION (https://etherscan.io/)
# ---------------------------------------------------
VERIFIER="etherscan"

ETHERSCAN_API_KEY="" # REQUIRED

# DEPLOYED DEPENDENCIES (OSX)
# ---------------------------------------------------
# Used to deploy the contracts and to run fork tests.
#
# Pick the right addresses from:
# https://github.com/aragon/osx/blob/main/packages/artifacts/src/addresses.json
# https://github.com/aragon/token-voting-plugin/blob/main/npm-artifacts/src/addresses.json

DAO_FACTORY_ADDRESS="0x246503df057A9a85E0144b6867a828c99676128B"
PLUGIN_REPO_FACTORY_ADDRESS="0xcf59C627b7a4052041C4F16B4c635a960e29554A"
PLUGIN_SETUP_PROCESSOR_ADDRESS="0xE978942c691e43f65c1B7c7F8f1dc8cDF061B13f"

# DEPLOYMENT PARAMETERS
# ---------------------------------------------------

# Existing repo (new build)
PLUGIN_REPO_ADDRESS="0xb7401cD221ceAFC54093168B814Cc3d42579287f"  # Example for TokenVoting
MANAGEMENT_DAO_MULTISIG_ADDRESS="0x0673c13D48023efA609C20E5E351763B99Dd67DE"

# New plugin repo (first build)
PLUGIN_ENS_SUBDOMAIN="" # A random value is used if empty
PLUGIN_REPO_MAINTAINER_ADDRESS=""

RELEASE_METADATA_URI="ipfs://QmWjZArvePnMPgbfKAMW3TidbqHEy68UV6SvRBhiaygGta"  # Example for TokenVoting
BUILD_METADATA_URI="ipfs://QmfXUy5Lc4iqg8DvgWdSSD2ZhCmCGvE2WTdWYFE9sosCRc"  # Example for TokenVoting

# Other

PINATA_JWT=""
```

## Documentation & Support

- [Aragon OSx Docs](https://docs.aragon.org/osx/)
- [TokenVoting Plugin](https://github.com/aragon/token-voting-plugin)
- [Foundry Book](https://getfoundry.sh/)

## Contributing

Found a missing address or outdated config? Open an issue or PR!

