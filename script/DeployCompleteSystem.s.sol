// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {MyToken} from "../src/MyToken.sol";

/**
 * @title DeployCompleteSystem
 * @dev Comprehensive deployment script for the complete token factory system
 *
 * Deployment Order:
 * 1. Deploy TokenRegistry (Rust/WASM)
 * 2. Deploy Solidity TokenFactory with registry address
 * 3. Deploy ConfigurableERC20 template (Rust/WASM)
 * 4. Deploy RustTokenFactory with registry address
 * 5. Authorize both factories in the registry
 * 6. Set token bytecode in RustTokenFactory
 * 7. Create test tokens from both factories
 * 8. Verify everything works
 *
 * Usage:
 * gblend script script/DeployCompleteSystem.s.sol --rpc-url <RPC_URL> --private-key $PRIVATE_KEY --broadcast
 */
contract DeployCompleteSystem is Script {

    // Contract addresses (will be set during deployment)
    address public tokenRegistry;
    address public solidityFactory;
    address public configTokenTemplate;
    address public rustFactory;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=======================================================");
        console.log("  DEPLOYING COMPLETE TOKEN FACTORY SYSTEM");
        console.log("=======================================================");
        console.log("Deployer address:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // ============ Step 1: Deploy TokenRegistry ============
        console.log("Step 1: Deploying TokenRegistry (Rust/WASM)...");
        console.log("-------------------------------------------------------");

        bytes memory registryBytecode = vm.getCode("out/TokenRegistry.wasm/foundry.json");
        console.log("TokenRegistry bytecode size:", registryBytecode.length);

        assembly {
            tokenRegistry := create(0, add(registryBytecode, 0x20), mload(registryBytecode))
        }

        require(tokenRegistry != address(0), "TokenRegistry deployment failed");
        console.log("TokenRegistry deployed at:", tokenRegistry);
        console.log("");

        // ============ Step 2: Deploy Solidity TokenFactory ============
        console.log("Step 2: Deploying Solidity TokenFactory...");
        console.log("-------------------------------------------------------");

        TokenFactory solidityFactoryContract = new TokenFactory(tokenRegistry);
        solidityFactory = address(solidityFactoryContract);

        console.log("Solidity TokenFactory deployed at:", solidityFactory);
        console.log("Registry address:", solidityFactoryContract.registry());
        console.log("");

        // ============ Step 3: Deploy ConfigurableERC20 Template ============
        console.log("Step 3: Deploying ConfigurableERC20 template (Rust/WASM)...");
        console.log("-------------------------------------------------------");

        bytes memory configTokenBytecode = vm.getCode("out/ConfigurableRustToken.wasm/foundry.json");
        console.log("ConfigurableERC20 bytecode size:", configTokenBytecode.length);

        assembly {
            configTokenTemplate := create(0, add(configTokenBytecode, 0x20), mload(configTokenBytecode))
        }

        require(configTokenTemplate != address(0), "ConfigurableERC20 deployment failed");
        console.log("ConfigurableERC20 template deployed at:", configTokenTemplate);
        console.log("");

        // ============ Step 4: Deploy RustTokenFactory ============
        console.log("Step 4: Deploying RustTokenFactory (Rust/WASM)...");
        console.log("-------------------------------------------------------");

        bytes memory rustFactoryBytecode = vm.getCode("out/RustTokenFactory.wasm/foundry.json");
        console.log("RustTokenFactory bytecode size:", rustFactoryBytecode.length);

        assembly {
            rustFactory := create(0, add(rustFactoryBytecode, 0x20), mload(rustFactoryBytecode))
        }

        require(rustFactory != address(0), "RustTokenFactory deployment failed");
        console.log("RustTokenFactory deployed at:", rustFactory);
        console.log("");

        // ============ Step 5: Authorize Factories in Registry ============
        console.log("Step 5: Authorizing factories in TokenRegistry...");
        console.log("-------------------------------------------------------");

        // Call authorizeFactory for Solidity factory
        (bool success1, ) = tokenRegistry.call(
            abi.encodeWithSignature("authorizeFactory(address)", solidityFactory)
        );
        require(success1, "Failed to authorize Solidity factory");
        console.log("Authorized Solidity factory:", solidityFactory);

        // Call authorizeFactory for Rust factory
        (bool success2, ) = tokenRegistry.call(
            abi.encodeWithSignature("authorizeFactory(address)", rustFactory)
        );
        require(success2, "Failed to authorize Rust factory");
        console.log("Authorized Rust factory:", rustFactory);
        console.log("");

        // ============ Step 6: Set Token Bytecode in RustTokenFactory ============
        console.log("Step 6: Setting token bytecode in RustTokenFactory...");
        console.log("-------------------------------------------------------");

        (bool success3, ) = rustFactory.call(
            abi.encodeWithSignature("setTokenBytecode(bytes)", configTokenBytecode)
        );

        if (success3) {
            console.log("Token bytecode set successfully");
        } else {
            console.log("Warning: Could not set token bytecode (may need to be done manually)");
        }
        console.log("");

        // ============ Step 7: Create Test Tokens ============
        console.log("Step 7: Creating test tokens from both factories...");
        console.log("-------------------------------------------------------");

        // Create test token from Solidity factory
        console.log("Creating Solidity test token...");
        address solidityTestToken = solidityFactoryContract.createToken(
            "SolidityTestToken",
            "STT",
            1000000,
            deployer
        );
        console.log("Solidity test token created at:", solidityTestToken);

        // Verify test token
        MyToken testToken = MyToken(solidityTestToken);
        console.log("  Name:", testToken.name());
        console.log("  Symbol:", testToken.symbol());
        console.log("  Total Supply:", testToken.totalSupply());
        console.log("");

        // Note: Creating Rust test token would require calling createToken on rustFactory
        // This is skipped here as it requires specific bytecode handling
        console.log("Note: Rust test token creation should be done via separate call");
        console.log("Use: cast send $RUST_FACTORY_ADDRESS 'createToken(bytes,bytes,uint256,uint256,address)'");
        console.log("");

        // ============ Step 8: Verify Registry ============
        console.log("Step 8: Verifying registry state...");
        console.log("-------------------------------------------------------");

        // Check token count in registry
        (bool success4, bytes memory data) = tokenRegistry.call(
            abi.encodeWithSignature("getTokenCount()")
        );

        if (success4 && data.length > 0) {
            uint256 tokenCount = abi.decode(data, (uint256));
            console.log("Total tokens in registry:", tokenCount);
        } else {
            console.log("Could not query registry (may need manual verification)");
        }

        // Check if Solidity factory is authorized
        (bool success5, bytes memory authData) = tokenRegistry.call(
            abi.encodeWithSignature("isAuthorizedFactory(address)", solidityFactory)
        );

        if (success5 && authData.length > 0) {
            uint256 isAuth = abi.decode(authData, (uint256));
            console.log("Solidity factory authorized:", isAuth == 1 ? "Yes" : "No");
        }

        vm.stopBroadcast();

        // ============ Deployment Summary ============
        console.log("");
        console.log("=======================================================");
        console.log("  DEPLOYMENT COMPLETE");
        console.log("=======================================================");
        console.log("");
        console.log("Contract Addresses:");
        console.log("-------------------");
        console.log("TokenRegistry (Rust):", tokenRegistry);
        console.log("Solidity TokenFactory:", solidityFactory);
        console.log("ConfigurableERC20 Template:", configTokenTemplate);
        console.log("RustTokenFactory:", rustFactory);
        console.log("");
        console.log("Test Tokens:");
        console.log("------------");
        console.log("Solidity Test Token:", solidityTestToken);
        console.log("");
        console.log("Next Steps:");
        console.log("-----------");
        console.log("1. Create tokens via Solidity factory:");
        console.log("   cast send", solidityFactory, "'createToken(string,string,uint256,address)' ...");
        console.log("");
        console.log("2. Create tokens via Rust factory:");
        console.log("   cast send", rustFactory, "'createToken(bytes,bytes,uint256,uint256,address)' ...");
        console.log("");
        console.log("3. Query registry:");
        console.log("   cast call", tokenRegistry, "'getTokenCount()'");
        console.log("   cast call", tokenRegistry, "'getTokenByIndex(uint256)' 0");
        console.log("");
        console.log("=======================================================");
    }
}
