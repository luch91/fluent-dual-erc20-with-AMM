# TokenFactory Quick Start Guide

## What Was Built

A **Solidity TokenFactory** that allows anyone to create custom ERC20 tokens by simply calling one function with their desired parameters.

---

## Key Files

| File | Description |
|------|-------------|
| [src/TokenFactory.sol](src/TokenFactory.sol) | Main factory contract |
| [test/TokenFactory.t.sol](test/TokenFactory.t.sol) | Comprehensive test suite (25+ tests) |
| [script/DeployTokenFactory.s.sol](script/DeployTokenFactory.s.sol) | Deployment script |

---

## Quick Commands

### Deploy Factory
```bash
export PRIVATE_KEY="your_key"

gblend script script/DeployTokenFactory.s.sol \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### Run Tests
```bash
gblend test --match-contract TokenFactoryTest -vv
```

### Create a Token
```bash
cast send $FACTORY_ADDRESS \
    "createToken(string,string,uint256,address)" \
    "MyToken" "MTK" 1000000 $OWNER_ADDRESS \
    --rpc-url https://rpc.testnet.fluent.xyz \
    --private-key $PRIVATE_KEY
```

---

## Usage Example

### In Solidity
```solidity
// Deploy or get existing factory
TokenFactory factory = TokenFactory(0x...);

// Create a new token
address myToken = factory.createToken(
    "CoolToken",      // Token name
    "COOL",           // Token symbol
    5000000,          // Initial supply (scaled by 10^18)
    msg.sender        // Token owner
);

// Query factory
uint256 count = factory.getTokenCount();
address[] memory myTokens = factory.getTokensByCreator(msg.sender);
```

### In JavaScript (ethers.js)
```javascript
const factory = new ethers.Contract(factoryAddress, factoryABI, signer);

// Create token
const tx = await factory.createToken(
    "CoolToken",
    "COOL",
    1000000,
    ownerAddress
);
const receipt = await tx.wait();

// Get created token address from event
const event = receipt.events?.find(e => e.event === 'TokenCreated');
const tokenAddress = event.args.tokenAddress;

// Query factory
const count = await factory.getTokenCount();
const tokens = await factory.getTokensByCreator(creatorAddress);
```

---

- Check test suite for usage examples
- Review original [README.md](README.md) for project background
