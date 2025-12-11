#![cfg_attr(not(feature = "std"), no_std, no_main)]
#![allow(dead_code)]
extern crate alloc;
extern crate fluentbase_sdk;

use alloc::vec::Vec;
use alloy_sol_types::{sol, SolEvent};
use fluentbase_sdk::{
    basic_entrypoint,
    derive::{router, solidity_storage, Contract},
    Address, Bytes, ContextReader, SharedAPI, B256, U256,
};

/// Token Registry API - Unified registry for both Solidity and Rust tokens
pub trait TokenRegistryAPI {
    // Admin functions
    fn authorize_factory(&mut self, factory: Address) -> U256;
    fn revoke_factory(&mut self, factory: Address) -> U256;
    fn is_authorized_factory(&self, factory: Address) -> U256;
    fn get_owner(&self) -> Address;
    fn transfer_ownership(&mut self, new_owner: Address) -> U256;

    // Registration functions (only authorized factories)
    fn register_token(
        &mut self,
        token_address: Address,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        creator: Address,
        token_type: U256,
    ) -> U256;

    // Query functions
    fn get_token_count(&self) -> U256;
    fn get_token_by_address(&self, token: Address) -> (Address, Bytes, Bytes, U256, Address, Address, U256, U256);
    fn get_token_by_index(&self, index: U256) -> (Address, Bytes, Bytes, U256, Address, Address, U256, U256);
    fn is_registered(&self, token: Address) -> U256;
    fn get_tokens_count_by_creator(&self, creator: Address) -> U256;
    fn get_token_by_creator_index(&self, creator: Address, index: U256) -> Address;
    fn get_tokens_count_by_type(&self, token_type: U256) -> U256;
    fn get_token_by_type_index(&self, token_type: U256, index: U256) -> Address;
}

// Define events
sol! {
    event TokenRegistered(
        address indexed tokenAddress,
        string name,
        string symbol,
        uint256 decimals,
        address indexed creator,
        address indexed factory,
        uint256 tokenType,
        uint256 timestamp
    );
    event FactoryAuthorized(address indexed factory, uint256 timestamp);
    event FactoryRevoked(address indexed factory, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
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

/// Token metadata structure
/// Storage layout for token data
solidity_storage! {
    // Owner and authorization
    Address Owner;
    mapping(Address => U256) AuthorizedFactories;

    // Token count and indexing
    U256 TokenCount;
    mapping(U256 => Address) TokenByIndex;

    // Token metadata by address
    mapping(Address => Bytes) TokenName;
    mapping(Address => Bytes) TokenSymbol;
    mapping(Address => U256) TokenDecimals;
    mapping(Address => Address) TokenCreator;
    mapping(Address => Address) TokenFactory;
    mapping(Address => U256) TokenType;       // 0 = Solidity, 1 = Rust
    mapping(Address => U256) TokenTimestamp;
    mapping(Address => U256) IsRegistered;

    // Indexing by creator
    mapping(Address => U256) CreatorTokenCount;
    mapping(Address => mapping(U256 => Address)) CreatorTokenByIndex;

    // Indexing by type
    mapping(U256 => U256) TypeTokenCount;
    mapping(U256 => mapping(U256 => Address)) TypeTokenByIndex;
}

/// The main TokenRegistry contract
#[derive(Contract, Default)]
struct TokenRegistry<SDK> {
    sdk: SDK,
}

#[router(mode = "solidity")]
impl<SDK: SharedAPI> TokenRegistryAPI for TokenRegistry<SDK> {
    // ============ Admin Functions ============

    fn authorize_factory(&mut self, factory: Address) -> U256 {
        let caller = self.sdk.context().contract_caller();
        let owner = Owner::get(&self.sdk);

        if caller != owner {
            panic!("only owner can authorize factories");
        }

        if factory == Address::ZERO {
            panic!("cannot authorize zero address");
        }

        AuthorizedFactories::set(&mut self.sdk, factory, U256::from(1));

        let timestamp = U256::from(self.sdk.context().block_timestamp());
        emit_event(
            &mut self.sdk,
            FactoryAuthorized { factory, timestamp },
        );

        U256::from(1)
    }

    fn revoke_factory(&mut self, factory: Address) -> U256 {
        let caller = self.sdk.context().contract_caller();
        let owner = Owner::get(&self.sdk);

        if caller != owner {
            panic!("only owner can revoke factories");
        }

        AuthorizedFactories::set(&mut self.sdk, factory, U256::from(0));

        let timestamp = U256::from(self.sdk.context().block_timestamp());
        emit_event(&mut self.sdk, FactoryRevoked { factory, timestamp });

        U256::from(1)
    }

    fn is_authorized_factory(&self, factory: Address) -> U256 {
        AuthorizedFactories::get(&self.sdk, factory)
    }

    fn get_owner(&self) -> Address {
        Owner::get(&self.sdk)
    }

    fn transfer_ownership(&mut self, new_owner: Address) -> U256 {
        let caller = self.sdk.context().contract_caller();
        let current_owner = Owner::get(&self.sdk);

        if caller != current_owner {
            panic!("only owner can transfer ownership");
        }

        if new_owner == Address::ZERO {
            panic!("new owner cannot be zero address");
        }

        Owner::set(&mut self.sdk, new_owner);

        emit_event(
            &mut self.sdk,
            OwnershipTransferred {
                previousOwner: current_owner,
                newOwner: new_owner,
            },
        );

        U256::from(1)
    }

    // ============ Registration Functions ============

    fn register_token(
        &mut self,
        token_address: Address,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        creator: Address,
        token_type: U256,
    ) -> U256 {
        let caller = self.sdk.context().contract_caller();

        // Check authorization
        let is_authorized = AuthorizedFactories::get(&self.sdk, caller);
        if is_authorized == U256::from(0) {
            panic!("caller is not an authorized factory");
        }

        // Check if already registered
        let already_registered = IsRegistered::get(&self.sdk, token_address);
        if already_registered != U256::from(0) {
            panic!("token already registered");
        }

        // Validate inputs
        if token_address == Address::ZERO {
            panic!("token address cannot be zero");
        }
        if name.len() == 0 {
            panic!("name cannot be empty");
        }
        if symbol.len() == 0 {
            panic!("symbol cannot be empty");
        }
        if creator == Address::ZERO {
            panic!("creator cannot be zero address");
        }

        // Store token metadata
        TokenName::set(&mut self.sdk, token_address, name.clone());
        TokenSymbol::set(&mut self.sdk, token_address, symbol.clone());
        TokenDecimals::set(&mut self.sdk, token_address, decimals);
        TokenCreator::set(&mut self.sdk, token_address, creator);
        TokenFactory::set(&mut self.sdk, token_address, caller);
        TokenType::set(&mut self.sdk, token_address, token_type);

        let timestamp = U256::from(self.sdk.context().block_timestamp());
        TokenTimestamp::set(&mut self.sdk, token_address, timestamp);
        IsRegistered::set(&mut self.sdk, token_address, U256::from(1));

        // Add to global index
        let current_count = TokenCount::get(&self.sdk);
        TokenByIndex::set(&mut self.sdk, current_count, token_address);
        TokenCount::set(&mut self.sdk, current_count + U256::from(1));

        // Add to creator index
        let creator_count = CreatorTokenCount::get(&self.sdk, creator);
        CreatorTokenByIndex::set(&mut self.sdk, creator, creator_count, token_address);
        CreatorTokenCount::set(&mut self.sdk, creator, creator_count + U256::from(1));

        // Add to type index
        let type_count = TypeTokenCount::get(&self.sdk, token_type);
        TypeTokenByIndex::set(&mut self.sdk, token_type, type_count, token_address);
        TypeTokenCount::set(&mut self.sdk, token_type, type_count + U256::from(1));

        // Emit event
        emit_event(
            &mut self.sdk,
            TokenRegistered {
                tokenAddress: token_address,
                name: alloc::string::String::from_utf8_lossy(&name).to_string(),
                symbol: alloc::string::String::from_utf8_lossy(&symbol).to_string(),
                decimals,
                creator,
                factory: caller,
                tokenType: token_type,
                timestamp,
            },
        );

        U256::from(1)
    }

    // ============ Query Functions ============

    fn get_token_count(&self) -> U256 {
        TokenCount::get(&self.sdk)
    }

    fn get_token_by_address(
        &self,
        token: Address,
    ) -> (Address, Bytes, Bytes, U256, Address, Address, U256, U256) {
        let is_registered = IsRegistered::get(&self.sdk, token);
        if is_registered == U256::from(0) {
            panic!("token not registered");
        }

        (
            token,
            TokenName::get(&self.sdk, token),
            TokenSymbol::get(&self.sdk, token),
            TokenDecimals::get(&self.sdk, token),
            TokenCreator::get(&self.sdk, token),
            TokenFactory::get(&self.sdk, token),
            TokenType::get(&self.sdk, token),
            TokenTimestamp::get(&self.sdk, token),
        )
    }

    fn get_token_by_index(
        &self,
        index: U256,
    ) -> (Address, Bytes, Bytes, U256, Address, Address, U256, U256) {
        let count = TokenCount::get(&self.sdk);
        if index >= count {
            panic!("index out of bounds");
        }

        let token = TokenByIndex::get(&self.sdk, index);
        self.get_token_by_address(token)
    }

    fn is_registered(&self, token: Address) -> U256 {
        IsRegistered::get(&self.sdk, token)
    }

    fn get_tokens_count_by_creator(&self, creator: Address) -> U256 {
        CreatorTokenCount::get(&self.sdk, creator)
    }

    fn get_token_by_creator_index(&self, creator: Address, index: U256) -> Address {
        let count = CreatorTokenCount::get(&self.sdk, creator);
        if index >= count {
            panic!("index out of bounds");
        }

        CreatorTokenByIndex::get(&self.sdk, creator, index)
    }

    fn get_tokens_count_by_type(&self, token_type: U256) -> U256 {
        TypeTokenCount::get(&self.sdk, token_type)
    }

    fn get_token_by_type_index(&self, token_type: U256, index: U256) -> Address {
        let count = TypeTokenCount::get(&self.sdk, token_type);
        if index >= count {
            panic!("index out of bounds");
        }

        TypeTokenByIndex::get(&self.sdk, token_type, index)
    }
}

/// Deploy function - initializes the registry
impl<SDK: SharedAPI> TokenRegistry<SDK> {
    pub fn deploy(&mut self) {
        let deployer = self.sdk.context().contract_caller();

        // Set deployer as owner
        Owner::set(&mut self.sdk, deployer);

        // Initialize counters
        TokenCount::set(&mut self.sdk, U256::from(0));
    }
}

basic_entrypoint!(TokenRegistry);
