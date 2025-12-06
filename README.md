# ERC20 Interoperability Project

This project demonstrates ERC20 token interoperability between Solidity and Rust/WASM implementations on the Fluent blockchain. It showcases how both traditional Solidity smart contracts and modern WebAssembly-based contracts can coexist and interact within the same ecosystem.

## Project Overview

This repository contains a complete ERC20 token ecosystem with:

- **Solidity ERC20 Token** (`MyToken.sol`) - Traditional Solidity implementation using OpenZeppelin contracts
- **Rust/WASM ERC20 Token** (`rust-token/`) - Modern WebAssembly implementation using the FluentBase SDK
- **Basic AMM Contract** (`BasicAMM.sol`) - Constant product AMM implementation for token swapping and liquidity provision
- **Deployment Scripts** - Automated deployment of both token types and AMM
- **Bootstrapping Script** (`BootstrapAMM.s.sol`) - Automated setup of liquidity pools and test accounts for benchmarking

## Project Structure

```
src/
├── MyToken.sol                   # Solidity ERC20 implementation
├── TokenFactory.sol              # Solidity factory for creating ERC20 tokens
├── BasicAMM.sol                  # Basic AMM implementation for token swapping
├── rust-token/                   # Original Rust/WASM ERC20 implementation
│   ├── Cargo.toml
│   └── src/lib.rs
├── configurable-rust-token/      # Parameterized Rust ERC20 token
│   ├── Cargo.toml
│   └── src/lib.rs
├── rust-token-factory/           # Rust/WASM factory for creating tokens
│   ├── Cargo.toml
│   └── src/lib.rs
└── RUST_FACTORY_README.md        # Rust factory documentation

script/
├── DeployTokens.s.sol            # Deployment script for both tokens
├── DeployTokenFactory.s.sol      # Deployment script for Solidity TokenFactory
├── DeployRustFactory.s.sol       # Deployment script for Rust TokenFactory
├── DeployAMM.s.sol               # Deployment script for AMM contract
└── BootstrapAMM.s.sol            # Bootstrapping script for liquidity and testing

test/
└── TokenFactory.t.sol            # Solidity TokenFactory test suite
```

## Deployed Contracts

> **View Live Contracts**: You can check out the deployed versions of these tokens on the [Fluent Testnet Explorer](https://testnet.fluentscan.xyz) using the contract addresses below.

The deployment script will output the addresses of both deployed tokens:

- **RustyToken (RUST)**: [0x3785F7f6046f4401b6a7cC94397ecb42A26C7fD5](https://testnet.fluentscan.xyz/address/0x3785F7f6046f4401b6a7cC94397ecb42A26C7fD5)
- **SolToken (SOLT)**: [0xa37f1A5eedfb1D4e81AbE78c4B4b28c91744D1ab](https://testnet.fluentscan.xyz/address/0xa37f1A5eedfb1D4e81AbE78c4B4b28c91744D1ab)

## Features

### Solidity Token (MyToken.sol)

- Standard ERC20 functionality (transfer, approve, transferFrom)
- OpenZeppelin-based implementation with Ownable access control
- Minting and burning capabilities for token owners
- Configurable name, symbol, and initial supply

### Rust/WASM Token (rust-token)

- Full ERC20 compliance implemented in Rust
- Compiled to WebAssembly for blockchain execution
- Uses FluentBase SDK for blockchain integration
- Optimized for gas efficiency and performance
- Fixed supply of 1,000,000 tokens with 18 decimals

### Basic AMM (BasicAMM.sol)

- Constant product AMM implementation (x * y = k)
- Token swapping functionality with 0.3% fee
- Liquidity provision and removal
- LP token minting and burning
- Gas usage tracking for benchmarking
- Reentrancy protection and access control

## Prerequisites

- [Foundry](https://getfoundry.sh/) - For Solidity development and testing
- [Rust](https://rustup.rs/) - For WASM contract development
- [Fluent CLI (gblend)](https://docs.fluent.xyz/gblend/installation) - For deployment and interaction
- [Node.js](https://nodejs.org/) - For JavaScript client usage (optional)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tmsdkeys/fluent-dual-erc20-with-AMM.git
cd fluent-dual-erc20
```

2. Install Foundry dependencies:
```bash
forge install
```

3. (Optional) Install JavaScript client dependencies:
```bash
cd js-client
npm install
```

## Usage

### Building

Build both Solidity and WASM contracts:
```bash
# Will compile all Solidity and WASM contracts in src/ (including nested)
gblend build
```

> Note: You'll need Docker daemon running for this!

### Deployment

#### Deploy Complete Ecosystem (Recommended)

```bash
# 1. Deploy both tokens
gblend script script/DeployTokens.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast

# 2. Deploy AMM contract
gblend script script/DeployAMM.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast

# 3. Bootstrap AMM with liquidity and test accounts
gblend script script/BootstrapAMM.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast
```

#### Deploy Individual Components

**Deploy Rust/WASM Token:**

```bash
gblend create RustToken.wasm \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --wasm \
    --verifier blockscout \
    --verifier-url https://testnet.fluentscan.xyz/api/
```

**Deploy Solidity Token:**

```bash
gblend create src/MyToken.sol:MyToken \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --constructor-args $(cast abi-encode "constructor(string,string,uint256,address)" "SolToken" "SOLT" 5000000 $MY_ADDRESS)
```

**Deploy Basic AMM:**

```bash
gblend create src/BasicAMM.sol:BasicAMM \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --constructor-args $(cast abi-encode "constructor(address,address,string,string)" $SOLT_TOKEN_ADDRESS $RUST_TOKEN_ADDRESS "Basic AMM SOLTRUST LP Token" "SOLTRUST-LP")
```

### Bootstrapping

The `BootstrapAMM.s.sol` script automatically sets up your deployed contracts for testing and benchmarking:

- **Initial Liquidity**: Adds 10,000 tokens of each type to the AMM pool
- **Test Accounts**: Creates three test accounts (Alice, Bob, Charlie) with token balances
- **Verification**: Confirms all setup is complete and ready for testing

```bash
gblend script script/BootstrapAMM.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast
```

**What the bootstrap script does:**

1. **Loads deployed contracts** from `deployments/testnet.json`
2. **Creates test accounts** with deterministic addresses for consistency
3. **Adds initial liquidity** to the AMM pool (10,000 tokens each)
4. **Funds test accounts**:
   - Alice: 5,000 tokens of each type (liquidity provider)
   - Bob: 5,000 tokens of each type (swapper)
   - Charlie: 2,500 tokens of each type (additional tester)
5. **Verifies setup** and displays final balances

**Note for JavaScript developers**: You can also use the js-client to bootstrap and test the AMM:
- `npm run bootstrap` - Bootstrap the AMM with liquidity and test accounts
- `npm run test-basic` - Test the AMM functionality
- Add your private key in `config.js` before running these commands

### Verification

**Verify Rust/WASM Token:**

```bash
gblend verify-contract $RUST_TOKEN_ADDRESS RustToken.wasm \
    --wasm \
    --verifier blockscout \
    --verifier-url https://testnet.fluentscan.xyz/api/
```

**Verify Solidity Token:**

```bash
gblend verify-contract $SOLT_TOKEN_ADDRESS src/MyToken.sol:MyToken \
    --verifier blockscout \
    --verifier-url https://testnet.fluentscan.xyz/api/ \
    --constructor-args $(cast abi-encode "constructor(string,string,uint256,address)" "SolToken" "SOLT" 5000000 $MY_ADDRESS)
```

**Verify Basic AMM:**

```bash
gblend verify-contract $BASIC_AMM_ADDRESS src/BasicAMM.sol:BasicAMM \
    --verifier blockscout \
    --verifier-url https://testnet.fluentscan.xyz/api/ \
    --constructor-args $(cast abi-encode "constructor(address,address,string,string)" $SOLT_TOKEN_ADDRESS $RUST_TOKEN_ADDRESS "Basic AMM SOLTRUST LP Token" "SOLTRUST-LP")
```

## Environment Variables

Set the following environment variables before deployment:

```bash
export PRIVATE_KEY="your_private_key_here"
export MY_ADDRESS="your_wallet_address_here"
```

## Development

### Testing the AMM

After bootstrapping, you can test the AMM functionality:

1. **Add Liquidity**: Use Alice's account to add more liquidity
2. **Swap Tokens**: Use Bob's account to perform token swaps
3. **Remove Liquidity**: Test LP token burning and liquidity removal
4. **Gas Benchmarking**: Monitor gas usage for different operations

### Using TokenFactory to Create Custom Tokens

The TokenFactory allows you to easily create new ERC20 tokens with custom parameters without writing any Solidity code.

**Quick Start**: See [QUICKSTART.md](QUICKSTART.md) for quick reference commands.

#### Deploy TokenFactory

```bash
export PRIVATE_KEY="your_private_key_here"

gblend script script/DeployTokenFactory.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast
```

#### Create a Token via Factory

**Using Cast CLI:**
```bash
cast send $FACTORY_ADDRESS \
    "createToken(string,string,uint256,address)" \
    "MyToken" "MTK" 1000000 $OWNER_ADDRESS \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY
```

**Using Solidity:**
```solidity
TokenFactory factory = TokenFactory(FACTORY_ADDRESS);

address newToken = factory.createToken(
    "MyToken",      // Token name
    "MTK",          // Token symbol
    1000000,        // Initial supply (scaled by 10^18)
    msg.sender      // Token owner
);
```

**Using JavaScript (ethers.js):**
```javascript
const factory = new ethers.Contract(factoryAddress, factoryABI, signer);

const tx = await factory.createToken("MyToken", "MTK", 1000000, ownerAddress);
const receipt = await tx.wait();

// Get created token address from event
const event = receipt.events?.find(e => e.event === 'TokenCreated');
const tokenAddress = event.args.tokenAddress;
```

#### Query Factory

```bash
# Get total tokens created
cast call $FACTORY_ADDRESS "getTokenCount()" --rpc-url https://rpc.testnet.fluent.xyz

# Get token at specific index
cast call $FACTORY_ADDRESS "getTokenAtIndex(uint256)" 0 --rpc-url https://rpc.testnet.fluent.xyz

# Get all tokens created by an address
cast call $FACTORY_ADDRESS "getTokensByCreator(address)" $CREATOR_ADDRESS --rpc-url https://rpc.testnet.fluent.xyz
```

#### Run Factory Tests

```bash
gblend test --match-contract TokenFactoryTest -vv
```

For more details and examples, see the [TokenFactory Quick Start Guide](QUICKSTART.md).

### Using Rust Token Factory (Phase 3)

The Rust Token Factory allows you to create Rust/WASM ERC20 tokens with custom parameters.

**Documentation**: See [src/RUST_FACTORY_README.md](src/RUST_FACTORY_README.md) for detailed Rust factory documentation.

#### Deploy Rust Factory

```bash
export PRIVATE_KEY="your_private_key_here"

gblend script script/DeployRustFactory.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast
```

#### Create a Rust Token

```bash
# After factory is deployed and bytecode is set
cast send $RUST_FACTORY_ADDRESS \
    "createToken(bytes,bytes,uint256,uint256,address)" \
    $(cast --from-utf8 "MyRustToken") \
    $(cast --from-utf8 "MRT") \
    18 \
    1000000000000000000000000 \
    $OWNER_ADDRESS \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY
```

#### Key Differences: Solidity vs Rust Factory

| Feature | Solidity Factory | Rust Factory |
|---------|-----------------|--------------|
| Language | Solidity | Rust/WASM |
| Deployment | `new` keyword | WASM bytecode |
| Initialization | Constructor | Separate `initialize()` call |
| Gas Cost | Higher | Lower (optimized) |
| Flexibility | Standard | Custom WASM logic |

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

- [Fluent Documentation](https://docs.fluent.xyz/)
- [Foundry Book](https://getfoundry.sh/forge/overview)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Rust Book](https://doc.rust-lang.org/book/)
- [WebAssembly](https://webassembly.org/)
