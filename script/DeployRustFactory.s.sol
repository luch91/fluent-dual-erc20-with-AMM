// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

/**
 * @title DeployRustFactory
 * @dev Deployment script for RustTokenFactory and ConfigurableERC20
 * @notice This script deploys the Rust/WASM factory and token template
 *
 * Steps:
 * 1. Deploy ConfigurableERC20 WASM contract (template)
 * 2. Deploy RustTokenFactory WASM contract
 * 3. Set the token bytecode in the factory
 * 4. Create a test token to verify functionality
 *
 * Usage:
 * gblend script script/DeployRustFactory.s.sol --rpc-url <RPC_URL> --private-key $PRIVATE_KEY --broadcast
 */
contract DeployRustFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying Rust Token Factory ===");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy ConfigurableERC20 (token template)
        console.log("\n1. Deploying ConfigurableERC20 template...");
        bytes memory configTokenBytecode = vm.getCode("out/ConfigurableRustToken.wasm/foundry.json");
        console.log("ConfigurableERC20 bytecode size:", configTokenBytecode.length);

        address configTokenTemplate;
        assembly {
            configTokenTemplate := create(0, add(configTokenBytecode, 0x20), mload(configTokenBytecode))
        }

        require(configTokenTemplate != address(0), "ConfigurableERC20 deployment failed");
        console.log("ConfigurableERC20 template deployed at:", configTokenTemplate);

        // Step 2: Deploy RustTokenFactory
        console.log("\n2. Deploying RustTokenFactory...");
        bytes memory factoryBytecode = vm.getCode("out/RustTokenFactory.wasm/foundry.json");
        console.log("RustTokenFactory bytecode size:", factoryBytecode.length);

        address rustFactory;
        assembly {
            rustFactory := create(0, add(factoryBytecode, 0x20), mload(factoryBytecode))
        }

        require(rustFactory != address(0), "RustTokenFactory deployment failed");
        console.log("RustTokenFactory deployed at:", rustFactory);

        // Step 3: Initialize factory with registry address (use address(0) for now)
        console.log("\n3. Initializing factory...");
        // Note: In Phase 4, we'll pass the actual registry address here
        // For now, we initialize with address(0)

        // Step 4: Set token bytecode in factory
        console.log("\n4. Setting token bytecode in factory...");
        // Note: This would require calling setTokenBytecode on the factory
        // with the configurable token bytecode

        // Step 5: Create a test token
        console.log("\n5. Creating test token...");
        // This would call createToken on the factory
        // For now, we'll skip this step as it requires the factory to be fully set up

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("ConfigurableERC20 template:", configTokenTemplate);
        console.log("RustTokenFactory:", rustFactory);
        console.log("\nNext steps:");
        console.log("1. Set token bytecode: call setTokenBytecode() on factory");
        console.log("2. Create tokens: call createToken() on factory");
        console.log("3. (Phase 4) Deploy and link TokenRegistry");
    }
}
