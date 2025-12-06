# Rust Token Factory Implementation

This directory contains the Rust/WASM implementation of the token factory system.

## Components

### 1. ConfigurableERC20 (`configurable-rust-token/`)

A parameterized ERC20 token implementation in Rust that can be initialized with custom parameters after deployment.

**Features:**
- Full ERC20 compliance (transfer, approve, transferFrom, etc.)
- Configurable name, symbol, decimals, and initial supply
- Initialization guard to prevent re-initialization
- Event emission for all state changes

**Key Functions:**
```rust
// ERC20 standard functions
fn name() -> Bytes
fn symbol() -> Bytes
fn decimals() -> U256
fn total_supply() -> U256
fn balance_of(account: Address) -> U256
fn transfer(to: Address, value: U256) -> U256
fn approve(spender: Address, value: U256) -> U256
fn transfer_from(from: Address, to: Address, value: U256) -> U256
fn allowance(owner: Address, spender: Address) -> U256

// Initialization
fn initialize(
    name: Bytes,
    symbol: Bytes,
    decimals: U256,
    initial_supply: U256,
    owner: Address
) -> U256

fn is_initialized() -> U256
```

**Storage Layout:**
```rust
// ERC20 core
Balance: mapping(Address => U256)
Allowance: mapping(Address => mapping(Address => U256))

// Metadata
Name: Bytes
Symbol: Bytes
Decimals: U256
TotalSupply: U256
Initialized: U256  // 0 = not initialized, 1 = initialized
```

### 2. RustTokenFactory (`rust-token-factory/`)

Factory contract for deploying and initializing ConfigurableERC20 tokens.

**Features:**
- Deploy new Rust ERC20 tokens with custom parameters
- Track all deployed tokens
- Track tokens by creator
- Registry integration support
- Token bytecode management

**Key Functions:**
```rust
fn create_token(
    name: Bytes,
    symbol: Bytes,
    decimals: U256,
    initial_supply: U256,
    owner: Address
) -> Address

fn get_token_count() -> U256
fn get_token_at_index(index: U256) -> Address
fn is_token_from_factory(token: Address) -> U256
fn get_registry() -> Address
fn set_token_bytecode(bytecode: Bytes) -> U256
```

**Storage Layout:**
```rust
Registry: Address              // TokenRegistry address
TokenBytecode: Bytes           // WASM bytecode for ConfigurableERC20
TokenCount: U256               // Total tokens created
TokenAtIndex: mapping(U256 => Address)
IsFromFactory: mapping(Address => U256)
CreatorTokenCount: mapping(Address => U256)
CreatorTokens: mapping(Address => mapping(U256 => Address))
```

## Building

### Prerequisites
- Rust toolchain
- Docker (for WASM compilation)
- gblend CLI

### Build Commands

```bash
# Build all contracts including Rust/WASM
gblend build

# Build specific Rust contract
cd src/configurable-rust-token
cargo build --release --target wasm32-unknown-unknown

cd ../rust-token-factory
cargo build --release --target wasm32-unknown-unknown
```

## Deployment

### Step 1: Deploy Factory and Template

```bash
export PRIVATE_KEY="your_private_key"

gblend script script/DeployRustFactory.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast
```

This deploys:
1. ConfigurableERC20 template contract
2. RustTokenFactory contract

### Step 2: Set Token Bytecode

After deployment, you need to set the token bytecode in the factory:

```bash
# This would be done via a contract call
# The bytecode is the WASM bytes of ConfigurableERC20
cast send $FACTORY_ADDRESS \
    "setTokenBytecode(bytes)" \
    $TOKEN_BYTECODE \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY
```

### Step 3: Create Tokens

```bash
# Create a new Rust ERC20 token
cast send $FACTORY_ADDRESS \
    "createToken(bytes,bytes,uint256,uint256,address)" \
    $(cast --from-utf8 "MyRustToken") \
    $(cast --from-utf8 "MRT") \
    18 \
    1000000000000000000000000 \
    $OWNER_ADDRESS \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY
```

## Usage Example

### Create a Token

```rust
// In a Rust contract or script
let factory = RustTokenFactory::at(factory_address);

let token_address = factory.create_token(
    Bytes::from("MyToken"),
    Bytes::from("MTK"),
    U256::from(18),
    U256::from(1000000) * U256::from(10).pow(U256::from(18)),
    owner_address
);
```

### Query Factory

```rust
// Get total tokens created
let count = factory.get_token_count();

// Get token at index
let token = factory.get_token_at_index(U256::from(0));

// Check if token is from factory
let is_from_factory = factory.is_token_from_factory(token_address);
```

## Important Notes

### Initialization Pattern

Unlike traditional Solidity contracts, Rust WASM contracts follow a two-step deployment:

1. **Deploy**: Contract bytecode is deployed to blockchain
2. **Initialize**: Contract state is set up with parameters

This is necessary because WASM contracts cannot receive constructor parameters directly.

### Token Bytecode Management

The factory stores the WASM bytecode for ConfigurableERC20. This bytecode is used to deploy new token instances. The bytecode must be set before creating tokens.

### Cross-Contract Calls

The factory makes cross-contract calls to:
1. Initialize newly deployed tokens
2. Register tokens with TokenRegistry (Phase 4)

These calls use FluentBase SDK's contract call functionality.

## Comparison: Solidity vs Rust Factory

| Feature | Solidity Factory | Rust Factory |
|---------|-----------------|--------------|
| Deployment | Direct `new` keyword | WASM bytecode deployment |
| Initialization | Constructor parameters | Separate initialize call |
| Token Type | Solidity ERC20 | Rust/WASM ERC20 |
| Gas Cost | Higher per token | Lower per token (optimized WASM) |
| Flexibility | Standard Solidity | Custom WASM logic |

## Security Considerations

1. **Initialization Guard**: ConfigurableERC20 prevents re-initialization
2. **Input Validation**: Factory validates all parameters before deployment
3. **Bytecode Verification**: Token bytecode should be verified before setting
4. **Access Control**: Consider adding admin controls for bytecode updates

## Testing

Tests for Rust contracts would typically be written in Rust:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_token() {
        // Test token creation
    }

    #[test]
    fn test_initialization() {
        // Test token initialization
    }
}
```

For integration testing with Solidity contracts, use Foundry tests that interact with deployed WASM contracts.

## Troubleshooting

### Contract Deployment Fails
- Ensure Docker is running
- Check WASM bytecode size limits
- Verify gblend CLI version

### Initialization Fails
- Check that token bytecode is set in factory
- Verify all parameters are valid
- Ensure owner address is not zero

### Token Not Found
- Verify factory address is correct
- Check that createToken was successful
- Query factory token count

## Future Improvements

1. **Gas Optimization**: Further optimize WASM bytecode size
2. **Batch Operations**: Create multiple tokens in one transaction
3. **Token Templates**: Support multiple token templates
4. **Upgrade Mechanism**: Add token upgrade functionality
5. **Pauseable**: Add emergency pause functionality

## Resources

- [FluentBase SDK Documentation](https://github.com/fluentlabs-xyz/fluentbase)
- [Alloy Types](https://github.com/alloy-rs/core)
- [WASM Specification](https://webassembly.github.io/spec/)
- [Rust Book](https://doc.rust-lang.org/book/)
