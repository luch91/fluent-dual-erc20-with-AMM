# TokenRegistry - Unified Token Registry

The **TokenRegistry** is a Rust/WASM smart contract that serves as a unified registry for ALL tokens created by both the Solidity TokenFactory and Rust TokenFactory. This completes the **BONUS requirement** of the workshop challenge.

## Overview

The TokenRegistry acts as a **single source of truth** for all tokens in the ecosystem, regardless of whether they were created in Solidity or Rust/WASM.

### Key Features

- ✅ **Unified Registry**: Tracks both Solidity and Rust tokens in one place
- ✅ **Authorization System**: Only approved factories can register tokens
- ✅ **Comprehensive Queries**: Query by address, creator, type, or index
- ✅ **Ownership Management**: Admin can authorize/revoke factories
- ✅ **Event Emission**: All actions emit events for off-chain indexing
- ✅ **Type Distinction**: Clearly identifies Solidity vs Rust tokens

---

## Architecture

```
┌─────────────────────┐         ┌──────────────────────┐
│  Solidity Factory   │         │   Rust Factory       │
│   (TokenFactory)    │         │ (RustTokenFactory)   │
└──────────┬──────────┘         └──────────┬───────────┘
           │                               │
           │ registerToken()               │ registerToken()
           │ (type=0)                      │ (type=1)
           │                               │
           ▼                               ▼
      ┌────────────────────────────────────────────┐
      │        TokenRegistry (Rust/WASM)           │
      │                                            │
      │  Storage:                                  │
      │  - Token metadata (name, symbol, etc.)     │
      │  - Creator → Tokens mapping                │
      │  - Type → Tokens mapping                   │
      │  - Global index                            │
      │  - Authorized factories                    │
      └────────────────────────────────────────────┘
                        ▲
                        │ Query functions
                        │
                   ┌────┴─────┐
                   │  Users   │
                   │  DApps   │
                   └──────────┘
```

---

## API Reference

### Admin Functions

#### `authorizeFactory(address factory) -> uint256`
Authorize a factory to register tokens.
- **Access**: Owner only
- **Parameters**:
  - `factory`: Address of the factory to authorize
- **Returns**: 1 on success
- **Events**: `FactoryAuthorized`

#### `revokeFactory(address factory) -> uint256`
Revoke a factory's authorization.
- **Access**: Owner only
- **Parameters**:
  - `factory`: Address of the factory to revoke
- **Returns**: 1 on success
- **Events**: `FactoryRevoked`

#### `isAuthorizedFactory(address factory) -> uint256`
Check if a factory is authorized.
- **Parameters**:
  - `factory`: Address to check
- **Returns**: 1 if authorized, 0 otherwise

#### `getOwner() -> address`
Get the current owner address.
- **Returns**: Owner address

#### `transferOwnership(address newOwner) -> uint256`
Transfer ownership to a new address.
- **Access**: Owner only
- **Parameters**:
  - `newOwner`: Address of the new owner
- **Returns**: 1 on success
- **Events**: `OwnershipTransferred`

### Registration Functions

#### `registerToken(address tokenAddress, bytes name, bytes symbol, uint256 decimals, address creator, uint256 tokenType) -> uint256`
Register a new token in the registry.
- **Access**: Authorized factories only
- **Parameters**:
  - `tokenAddress`: Address of the token contract
  - `name`: Token name (as bytes)
  - `symbol`: Token symbol (as bytes)
  - `decimals`: Number of decimals
  - `creator`: Address that created the token
  - `tokenType`: 0 for Solidity, 1 for Rust
- **Returns**: 1 on success
- **Events**: `TokenRegistered`
- **Reverts if**:
  - Caller is not authorized
  - Token already registered
  - Invalid parameters

### Query Functions

#### `getTokenCount() -> uint256`
Get the total number of registered tokens.
- **Returns**: Total token count

#### `getTokenByAddress(address token) -> (address, bytes, bytes, uint256, address, address, uint256, uint256)`
Get token metadata by address.
- **Parameters**:
  - `token`: Token address
- **Returns**: Tuple containing:
  - `address`: Token address
  - `bytes`: Token name
  - `bytes`: Token symbol
  - `uint256`: Decimals
  - `address`: Creator address
  - `address`: Factory address
  - `uint256`: Token type (0=Solidity, 1=Rust)
  - `uint256`: Timestamp

#### `getTokenByIndex(uint256 index) -> (address, bytes, bytes, uint256, address, address, uint256, uint256)`
Get token metadata by global index.
- **Parameters**:
  - `index`: Index in the global token array
- **Returns**: Same tuple as `getTokenByAddress`

#### `isRegistered(address token) -> uint256`
Check if a token is registered.
- **Parameters**:
  - `token`: Token address to check
- **Returns**: 1 if registered, 0 otherwise

#### `getTokensCountByCreator(address creator) -> uint256`
Get the number of tokens created by a specific address.
- **Parameters**:
  - `creator`: Creator address
- **Returns**: Number of tokens created by this address

#### `getTokenByCreatorIndex(address creator, uint256 index) -> address`
Get token address by creator and index.
- **Parameters**:
  - `creator`: Creator address
  - `index`: Index in the creator's token array
- **Returns**: Token address

#### `getTokensCountByType(uint256 tokenType) -> uint256`
Get the number of tokens of a specific type.
- **Parameters**:
  - `tokenType`: 0 for Solidity, 1 for Rust
- **Returns**: Number of tokens of this type

#### `getTokenByTypeIndex(uint256 tokenType, uint256 index) -> address`
Get token address by type and index.
- **Parameters**:
  - `tokenType`: 0 for Solidity, 1 for Rust
  - `index`: Index in the type's token array
- **Returns**: Token address

---

## Storage Layout

```rust
// Ownership and authorization
Owner: Address
AuthorizedFactories: mapping(Address => U256)

// Global indexing
TokenCount: U256
TokenByIndex: mapping(U256 => Address)

// Token metadata
TokenName: mapping(Address => Bytes)
TokenSymbol: mapping(Address => Bytes)
TokenDecimals: mapping(Address => U256)
TokenCreator: mapping(Address => Address)
TokenFactory: mapping(Address => Address)
TokenType: mapping(Address => U256)
TokenTimestamp: mapping(Address => U256)
IsRegistered: mapping(Address => U256)

// Creator indexing
CreatorTokenCount: mapping(Address => U256)
CreatorTokenByIndex: mapping(Address => mapping(U256 => Address))

// Type indexing
TypeTokenCount: mapping(U256 => U256)
TypeTokenByIndex: mapping(U256 => mapping(U256 => Address))
```

---

## Events

### `TokenRegistered`
```solidity
event TokenRegistered(
    address indexed tokenAddress,
    string name,
    string symbol,
    uint256 decimals,
    address indexed creator,
    address indexed factory,
    uint256 tokenType,
    uint256 timestamp
)
```

### `FactoryAuthorized`
```solidity
event FactoryAuthorized(
    address indexed factory,
    uint256 timestamp
)
```

### `FactoryRevoked`
```solidity
event FactoryRevoked(
    address indexed factory,
    uint256 timestamp
)
```

### `OwnershipTransferred`
```solidity
event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
)
```

---

## Usage Examples

### Deploy and Setup

```bash
# 1. Deploy TokenRegistry
gblend create out/TokenRegistry.wasm --rpc-url $RPC --private-key $PK --broadcast

# 2. Authorize Solidity factory
cast send $REGISTRY_ADDRESS \
    "authorizeFactory(address)" $SOLIDITY_FACTORY \
    --rpc-url $RPC --private-key $PK

# 3. Authorize Rust factory
cast send $REGISTRY_ADDRESS \
    "authorizeFactory(address)" $RUST_FACTORY \
    --rpc-url $RPC --private-key $PK
```

### Query Registry

```bash
# Get total tokens
cast call $REGISTRY_ADDRESS "getTokenCount()" --rpc-url $RPC

# Get token by index
cast call $REGISTRY_ADDRESS "getTokenByIndex(uint256)" 0 --rpc-url $RPC

# Get tokens created by an address
cast call $REGISTRY_ADDRESS "getTokensCountByCreator(address)" $CREATOR --rpc-url $RPC

# Get Solidity tokens count (type 0)
cast call $REGISTRY_ADDRESS "getTokensCountByType(uint256)" 0 --rpc-url $RPC

# Get Rust tokens count (type 1)
cast call $REGISTRY_ADDRESS "getTokensCountByType(uint256)" 1 --rpc-url $RPC
```

### Integration with Factories

Both factories automatically register tokens when they're created (if registry is set):

**Solidity Factory:**
```solidity
// When createToken() is called, it automatically calls:
registry.registerToken(
    tokenAddress,
    bytes(name),
    bytes(symbol),
    18,           // decimals
    msg.sender,   // creator
    0             // type: Solidity
);
```

**Rust Factory:**
```rust
// When create_token() is called, it automatically calls:
registry.register_token(
    token_address,
    name,
    symbol,
    decimals,
    creator,
    1  // type: Rust
);
```

---

## Security Considerations

### Authorization
- Only authorized factories can register tokens
- Owner must explicitly authorize each factory
- Unauthorized calls to `registerToken` will revert

### Validation
- All inputs are validated before registration
- Cannot register zero addresses
- Cannot register empty names/symbols
- Cannot re-register existing tokens

### Access Control
- Only owner can authorize/revoke factories
- Only owner can transfer ownership
- Token registration is permissionless from authorized factories

---

## Comparison: Before vs After Registry

### Before (Phase 3)
```
User: "How many tokens exist?"
- Must query Solidity factory → 5 tokens
- Must query Rust factory → 3 tokens
- Manual addition → 8 total tokens
```

### After (Phase 4)
```
User: "How many tokens exist?"
- Query TokenRegistry → 8 tokens ✅
- One call, unified answer!
```

### Before (Phase 3)
```
User: "Show me all tokens created by Alice"
- Query Solidity factory → [token1, token3]
- Query Rust factory → [token5]
- Manual merge → [token1, token3, token5]
```

### After (Phase 4)
```
User: "Show me all tokens created by Alice"
- Query TokenRegistry by creator → [token1, token3, token5] ✅
- One call, complete list!
```

---

## Query Patterns

### Get All Tokens
```bash
# 1. Get count
TOTAL=$(cast call $REGISTRY "getTokenCount()")

# 2. Loop through all tokens
for i in $(seq 0 $((TOTAL-1))); do
    cast call $REGISTRY "getTokenByIndex(uint256)" $i
done
```

### Get Tokens by Creator
```bash
# 1. Get count for creator
COUNT=$(cast call $REGISTRY "getTokensCountByCreator(address)" $CREATOR)

# 2. Get each token
for i in $(seq 0 $((COUNT-1))); do
    cast call $REGISTRY "getTokenByCreatorIndex(address,uint256)" $CREATOR $i
done
```

### Get Tokens by Type
```bash
# Get all Solidity tokens (type 0)
COUNT=$(cast call $REGISTRY "getTokensCountByType(uint256)" 0)
for i in $(seq 0 $((COUNT-1))); do
    cast call $REGISTRY "getTokenByTypeIndex(uint256,uint256)" 0 $i
done

# Get all Rust tokens (type 1)
COUNT=$(cast call $REGISTRY "getTokensCountByType(uint256)" 1)
for i in $(seq 0 $((COUNT-1))); do
    cast call $REGISTRY "getTokenByTypeIndex(uint256,uint256)" 1 $i
done
```

---

## Frontend Integration Example

```javascript
const registry = new ethers.Contract(registryAddress, registryABI, provider);

// Get all tokens
const totalCount = await registry.getTokenCount();
const allTokens = [];

for (let i = 0; i < totalCount; i++) {
    const tokenData = await registry.getTokenByIndex(i);
    allTokens.push({
        address: tokenData[0],
        name: ethers.utils.toUtf8String(tokenData[1]),
        symbol: ethers.utils.toUtf8String(tokenData[2]),
        decimals: tokenData[3],
        creator: tokenData[4],
        factory: tokenData[5],
        type: tokenData[6] === 0 ? 'Solidity' : 'Rust',
        timestamp: tokenData[7]
    });
}

// Filter Solidity tokens
const solidityTokens = allTokens.filter(t => t.type === 'Solidity');

// Filter Rust tokens
const rustTokens = allTokens.filter(t => t.type === 'Rust');

// Get tokens by specific creator
const creatorCount = await registry.getTokensCountByCreator(creatorAddress);
const creatorTokens = [];

for (let i = 0; i < creatorCount; i++) {
    const tokenAddress = await registry.getTokenByCreatorIndex(creatorAddress, i);
    const tokenData = await registry.getTokenByAddress(tokenAddress);
    creatorTokens.push(/* parse tokenData */);
}
```

---

## Testing

### Manual Testing Steps

1. **Deploy Registry**
   ```bash
   gblend create out/TokenRegistry.wasm --broadcast
   ```

2. **Authorize Factories**
   ```bash
   cast send $REGISTRY "authorizeFactory(address)" $SOL_FACTORY
   cast send $REGISTRY "authorizeFactory(address)" $RUST_FACTORY
   ```

3. **Create Tokens**
   ```bash
   # Create Solidity token
   cast send $SOL_FACTORY "createToken(string,string,uint256,address)" ...

   # Create Rust token
   cast send $RUST_FACTORY "createToken(bytes,bytes,uint256,uint256,address)" ...
   ```

4. **Verify Registry**
   ```bash
   # Check total count
   cast call $REGISTRY "getTokenCount()"

   # Check Solidity tokens
   cast call $REGISTRY "getTokensCountByType(uint256)" 0

   # Check Rust tokens
   cast call $REGISTRY "getTokensCountByType(uint256)" 1
   ```

---

## Troubleshooting

### "caller is not an authorized factory"
- Ensure factory is authorized: `cast call $REGISTRY "isAuthorizedFactory(address)" $FACTORY`
- If not authorized, call: `cast send $REGISTRY "authorizeFactory(address)" $FACTORY`

### "token already registered"
- Token can only be registered once
- Check: `cast call $REGISTRY "isRegistered(address)" $TOKEN`

### "only owner can authorize factories"
- Only the registry owner can authorize factories
- Check owner: `cast call $REGISTRY "getOwner()"`

---

## Resources

- [FluentBase SDK](https://github.com/fluentlabs-xyz/fluentbase)
- [Workshop Challenge](../README.md)
- [Solidity Factory Docs](../src/TokenFactory.sol)
- [Rust Factory Docs](../src/RUST_FACTORY_README.md)
