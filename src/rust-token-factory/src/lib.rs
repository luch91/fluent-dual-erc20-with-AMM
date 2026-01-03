#![cfg_attr(not(feature = "std"), no_std, no_main)]
#![allow(dead_code)]
extern crate alloc;
extern crate fluentbase_sdk;

use alloc::string::ToString;
use alloc::vec::Vec;
use alloy_sol_types::{sol, SolEvent};
use fluentbase_sdk::{
    basic_entrypoint,
    derive::{router, solidity_storage, Contract},
    Address, Bytes, ContextReader, SharedAPI, B256, U256,
};

/// Factory interface for creating Rust ERC20 tokens
pub trait RustTokenFactoryAPI {
    fn create_token(
        &mut self,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        initial_supply: U256,
        owner: Address,
    ) -> Address;
    fn get_token_count(&self) -> U256;
    fn get_token_at_index(&self, index: U256) -> Address;
    fn is_token_from_factory(&self, token: Address) -> U256;
    fn get_registry(&self) -> Address;
    fn set_registry(&mut self, registry: Address) -> U256;
    fn set_token_bytecode(&mut self, bytecode: Bytes) -> U256;
}

// Define events
sol! {
    event TokenCreated(
        address indexed tokenAddress,
        string name,
        string symbol,
        uint256 decimals,
        uint256 initialSupply,
        address indexed owner,
        address indexed creator,
        uint256 timestamp
    );
    event TokenBytecodeSet(uint256 bytecodeLength);
}

/// Helper function to emit events
fn emit_event<SDK: SharedAPI, T: SolEvent>(sdk: &mut SDK, event: T) {
    let data = event.encode_data();
    let topics: Vec<B256> = event
        .encode_topics()
        .iter()
        .map(|v| B256::from(v.0))
        .collect();
    sdk.emit_log(&topics, &data);
}

/// Storage layout for the factory
solidity_storage! {
    // Registry address for cross-contract calls
    Address Registry;

    // WASM bytecode for ConfigurableERC20
    Bytes TokenBytecode;

    // Token tracking
    U256 TokenCount;
    mapping(U256 => Address) TokenAtIndex;
    mapping(Address => U256) IsFromFactory;
    mapping(Address => U256) CreatorTokenCount;
    mapping(Address => mapping(U256 => Address)) CreatorTokens;
}

/// The main RustTokenFactory contract
#[derive(Contract, Default)]
struct RustTokenFactory<SDK> {
    sdk: SDK,
}

#[router(mode = "solidity")]
impl<SDK: SharedAPI> RustTokenFactoryAPI for RustTokenFactory<SDK> {
    fn create_token(
        &mut self,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        initial_supply: U256,
        owner: Address,
    ) -> Address {
        // Input validation
        if name.len() == 0 {
            panic!("name cannot be empty");
        }
        if symbol.len() == 0 {
            panic!("symbol cannot be empty");
        }
        if owner == Address::ZERO {
            panic!("owner cannot be zero address");
        }
        if initial_supply == U256::from(0) {
            panic!("initial supply must be greater than 0");
        }

        // Get token bytecode
        let bytecode = TokenBytecode::get(&self.sdk);
        if bytecode.len() == 0 {
            panic!("token bytecode not set");
        }

        // Deploy new token contract
        // Note: This is a simplified version - actual deployment would use SDK's deploy functionality
        let token_address = self.deploy_token_contract(&bytecode);

        // Initialize the token
        self.initialize_token(token_address, name.clone(), symbol.clone(), decimals, initial_supply, owner);

        // Track the token
        let current_count = TokenCount::get(&self.sdk);
        TokenAtIndex::set(&mut self.sdk, current_count, token_address);
        IsFromFactory::set(&mut self.sdk, token_address, U256::from(1));
        TokenCount::set(&mut self.sdk, current_count + U256::from(1));

        // Track by creator
        let creator = self.sdk.context().contract_caller();
        let creator_count = CreatorTokenCount::get(&self.sdk, creator);
        CreatorTokens::set(&mut self.sdk, creator, creator_count, token_address);
        CreatorTokenCount::set(&mut self.sdk, creator, creator_count + U256::from(1));

        // Register with registry if available
        let registry = Registry::get(&self.sdk);
        if registry != Address::ZERO {
            self.register_token(registry, token_address, name.clone(), symbol.clone(), decimals, creator);
        }

        // Emit event
        let timestamp = U256::from(self.sdk.context().block_timestamp());
        emit_event(
            &mut self.sdk,
            TokenCreated {
                tokenAddress: token_address,
                name: alloc::string::String::from_utf8_lossy(&name).to_string(),
                symbol: alloc::string::String::from_utf8_lossy(&symbol).to_string(),
                decimals,
                initialSupply: initial_supply,
                owner,
                creator,
                timestamp,
            },
        );

        token_address
    }

    fn get_token_count(&self) -> U256 {
        TokenCount::get(&self.sdk)
    }

    fn get_token_at_index(&self, index: U256) -> Address {
        let count = TokenCount::get(&self.sdk);
        if index >= count {
            panic!("index out of bounds");
        }
        TokenAtIndex::get(&self.sdk, index)
    }

    fn is_token_from_factory(&self, token: Address) -> U256 {
        IsFromFactory::get(&self.sdk, token)
    }

    fn get_registry(&self) -> Address {
        Registry::get(&self.sdk)
    }

    fn set_registry(&mut self, registry: Address) -> U256 {
        Registry::set(&mut self.sdk, registry);
        U256::from(1)
    }

    fn set_token_bytecode(&mut self, bytecode: Bytes) -> U256 {
        if bytecode.len() == 0 {
            panic!("bytecode cannot be empty");
        }
        TokenBytecode::set(&mut self.sdk, bytecode.clone());

        emit_event(
            &mut self.sdk,
            TokenBytecodeSet {
                bytecodeLength: U256::from(bytecode.len()),
            },
        );

        U256::from(1)
    }
}

/// Internal helper functions
impl<SDK: SharedAPI> RustTokenFactory<SDK> {
    /// Deploy a new token contract from bytecode
    /// Note: This is a placeholder - actual implementation depends on FluentBase SDK capabilities
    fn deploy_token_contract(&mut self, _bytecode: &Bytes) -> Address {
        // In a real implementation, this would use the SDK's contract deployment functionality
        // For now, we'll simulate with a deterministic address generation

        // This would be replaced with actual SDK deployment:
        // let token_address = self.sdk.deploy_contract(bytecode);

        // Placeholder: generate a pseudo-random address based on current state
        let count = TokenCount::get(&self.sdk);
        let caller = self.sdk.context().contract_caller();

        // Create a deterministic but unique address
        // In production, this would be the actual deployed contract address
        let mut addr_bytes = [0u8; 20];
        let count_bytes = count.to_be_bytes::<32>();
        let caller_bytes = caller.as_slice();

        for i in 0..20 {
            addr_bytes[i] = count_bytes[i + 12] ^ caller_bytes[i];
        }

        Address::from(addr_bytes)
    }

    /// Initialize the deployed token
    fn initialize_token(
        &mut self,
        token_address: Address,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        initial_supply: U256,
        owner: Address,
    ) {
        // Call the initialize function on the deployed token
        // This would use the SDK's contract call functionality

        // Encode the initialize call
        // initialize(bytes name, bytes symbol, uint256 decimals, uint256 initialSupply, address owner)

        // In production:
        // self.sdk.call_contract(
        //     token_address,
        //     "initialize(bytes,bytes,uint256,uint256,address)",
        //     &[name, symbol, decimals, initial_supply, owner]
        // );

        // For now, this is a placeholder
        // The actual implementation would make a cross-contract call
    }

    /// Register token with the registry
    fn register_token(
        &mut self,
        registry: Address,
        token_address: Address,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        creator: Address,
    ) {
        // Call registry's registerToken function
        // registerToken(address tokenAddress, bytes name, bytes symbol, uint256 decimals, address creator, uint256 tokenType)

        // In production:
        // self.sdk.call_contract(
        //     registry,
        //     "registerToken(address,bytes,bytes,uint256,address,uint256)",
        //     &[token_address, name, symbol, decimals, creator, U256::from(1)] // token_type: 1 for Rust
        // );

        // For now, this is a placeholder
    }
}

/// Deploy function - sets up the factory
impl<SDK: SharedAPI> RustTokenFactory<SDK> {
    pub fn deploy(&mut self) {
        // Initialize factory state
        // Registry will be set separately or passed as zero for now
        Registry::set(&mut self.sdk, Address::ZERO);
        TokenCount::set(&mut self.sdk, U256::from(0));

        // TokenBytecode will be set separately via set_token_bytecode
    }
}

basic_entrypoint!(RustTokenFactory);
