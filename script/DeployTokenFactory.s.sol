// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {MyToken} from "../src/MyToken.sol";

/**
 * @title DeployTokenFactory
 * @dev Deployment script for TokenFactory
 * @notice Run with: gblend script script/DeployTokenFactory.s.sol --rpc-url <RPC_URL> --private-key $PRIVATE_KEY --broadcast
 */
contract DeployTokenFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying TokenFactory...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TokenFactory without registry (registry will be deployed in Phase 4)
        TokenFactory factory = new TokenFactory(address(0));
        console.log("TokenFactory deployed at:", address(factory));

        // Example: Create a test token to verify factory works
        console.log("\nCreating test token...");
        address testToken = factory.createToken(
            "FactoryToken",
            "FTOK",
            1000000,
            deployer
        );

        console.log("Test token created at:", testToken);

        // Verify test token
        MyToken token = MyToken(testToken);
        console.log("Test token name:", token.name());
        console.log("Test token symbol:", token.symbol());
        console.log("Test token total supply:", token.totalSupply());
        console.log("Test token owner:", token.owner());

        // Display factory stats
        console.log("\nFactory stats:");
        console.log("Total tokens created:", factory.getTokenCount());
        console.log("Token at index 0:", factory.getTokenAtIndex(0));

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("TokenFactory address:", address(factory));
        console.log("Save this address for future use!");
    }
}
