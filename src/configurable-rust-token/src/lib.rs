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

/// Combined ERC20 and Configurable Token API
pub trait ConfigurableERC20API {
    // ERC20 standard functions
    fn symbol(&self) -> Bytes;
    fn name(&self) -> Bytes;
    fn decimals(&self) -> U256;
    fn total_supply(&self) -> U256;
    fn balance_of(&self, account: Address) -> U256;
    fn transfer(&mut self, to: Address, value: U256) -> U256;
    fn allowance(&self, owner: Address, spender: Address) -> U256;
    fn approve(&mut self, spender: Address, value: U256) -> U256;
    fn transfer_from(&mut self, from: Address, to: Address, value: U256) -> U256;

    // Initialization functions
    fn initialize(
        &mut self,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        initial_supply: U256,
        owner: Address,
    ) -> U256;
    fn is_initialized(&self) -> U256;
}

// Define ERC20 events
sol! {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokenInitialized(address indexed owner, string name, string symbol, uint256 decimals, uint256 totalSupply);
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

solidity_storage! {
    // ERC20 core storage
    mapping(Address => U256) Balance;
    mapping(Address => mapping(Address => U256)) Allowance;

    // Configurable metadata storage
    Bytes Name;
    Bytes Symbol;
    U256 Decimals;
    U256 TotalSupply;
    U256 Initialized;  // 0 = not initialized, 1 = initialized
}

/// Helper methods for Balance storage
impl Balance {
    fn add<SDK: SharedAPI>(
        sdk: &mut SDK,
        address: Address,
        amount: U256,
    ) -> Result<(), &'static str> {
        let current_balance = Self::get(sdk, address);
        let new_balance = current_balance + amount;
        Self::set(sdk, address, new_balance);
        Ok(())
    }

    fn subtract<SDK: SharedAPI>(
        sdk: &mut SDK,
        address: Address,
        amount: U256,
    ) -> Result<(), &'static str> {
        let current_balance = Self::get(sdk, address);
        if current_balance < amount {
            return Err("insufficient balance");
        }
        let new_balance = current_balance - amount;
        Self::set(sdk, address, new_balance);
        Ok(())
    }
}

/// Helper methods for Allowance storage
impl Allowance {
    fn subtract<SDK: SharedAPI>(
        sdk: &mut SDK,
        owner: Address,
        spender: Address,
        amount: U256,
    ) -> Result<(), &'static str> {
        let current_allowance = Self::get(sdk, owner, spender);
        if current_allowance < amount {
            return Err("insufficient allowance");
        }
        let new_allowance = current_allowance - amount;
        Self::set(sdk, owner, spender, new_allowance);
        Ok(())
    }
}

/// The main ConfigurableERC20 contract
#[derive(Contract, Default)]
struct ConfigurableERC20<SDK> {
    sdk: SDK,
}

/// Combined implementation of all contract functions
#[router(mode = "solidity")]
impl<SDK: SharedAPI> ConfigurableERC20API for ConfigurableERC20<SDK> {
    // ERC20 standard functions
    fn symbol(&self) -> Bytes {
        Symbol::get(&self.sdk)
    }

    fn name(&self) -> Bytes {
        Name::get(&self.sdk)
    }

    fn decimals(&self) -> U256 {
        Decimals::get(&self.sdk)
    }

    fn total_supply(&self) -> U256 {
        TotalSupply::get(&self.sdk)
    }

    fn balance_of(&self, account: Address) -> U256 {
        Balance::get(&self.sdk, account)
    }

    fn transfer(&mut self, to: Address, value: U256) -> U256 {
        let from = self.sdk.context().contract_caller();

        Balance::subtract(&mut self.sdk, from, value).unwrap_or_else(|err| panic!("{}", err));
        Balance::add(&mut self.sdk, to, value).unwrap_or_else(|err| panic!("{}", err));

        emit_event(&mut self.sdk, Transfer { from, to, value });
        U256::from(1)
    }

    fn allowance(&self, owner: Address, spender: Address) -> U256 {
        Allowance::get(&self.sdk, owner, spender)
    }

    fn approve(&mut self, spender: Address, value: U256) -> U256 {
        let owner = self.sdk.context().contract_caller();
        Allowance::set(&mut self.sdk, owner, spender, value);
        emit_event(
            &mut self.sdk,
            Approval {
                owner,
                spender,
                value,
            },
        );
        U256::from(1)
    }

    fn transfer_from(&mut self, from: Address, to: Address, value: U256) -> U256 {
        let spender = self.sdk.context().contract_caller();

        let current_allowance = Allowance::get(&self.sdk, from, spender);
        if current_allowance < value {
            panic!("insufficient allowance");
        }

        Allowance::subtract(&mut self.sdk, from, spender, value)
            .unwrap_or_else(|err| panic!("{}", err));
        Balance::subtract(&mut self.sdk, from, value).unwrap_or_else(|err| panic!("{}", err));
        Balance::add(&mut self.sdk, to, value).unwrap_or_else(|err| panic!("{}", err));

        emit_event(&mut self.sdk, Transfer { from, to, value });
        U256::from(1)
    }

    // Initialization functions
    fn initialize(
        &mut self,
        name: Bytes,
        symbol: Bytes,
        decimals: U256,
        initial_supply: U256,
        owner: Address,
    ) -> U256 {
        // Check if already initialized
        let is_init = Initialized::get(&self.sdk);
        if is_init != U256::from(0) {
            panic!("already initialized");
        }

        // Validate inputs
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

        // Set metadata
        Name::set(&mut self.sdk, name.clone());
        Symbol::set(&mut self.sdk, symbol.clone());
        Decimals::set(&mut self.sdk, decimals);
        TotalSupply::set(&mut self.sdk, initial_supply);

        // Mint initial supply to owner
        Balance::add(&mut self.sdk, owner, initial_supply)
            .unwrap_or_else(|err| panic!("{}", err));

        // Mark as initialized
        Initialized::set(&mut self.sdk, U256::from(1));

        // Emit events
        emit_event(
            &mut self.sdk,
            Transfer {
                from: Address::ZERO,
                to: owner,
                value: initial_supply,
            },
        );

        emit_event(
            &mut self.sdk,
            TokenInitialized {
                owner,
                name: alloc::string::String::from_utf8_lossy(&name).to_string(),
                symbol: alloc::string::String::from_utf8_lossy(&symbol).to_string(),
                decimals,
                totalSupply: initial_supply,
            },
        );

        U256::from(1)
    }

    fn is_initialized(&self) -> U256 {
        Initialized::get(&self.sdk)
    }
}

/// Deploy function - called when contract is first deployed
impl<SDK: SharedAPI> ConfigurableERC20<SDK> {
    pub fn deploy(&mut self) {
        // Contract is deployed but not initialized
        // Initialization must be called separately by the factory
        Initialized::set(&mut self.sdk, U256::from(0));
    }
}

basic_entrypoint!(ConfigurableERC20);
