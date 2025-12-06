// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {MyToken} from "../src/MyToken.sol";

contract TokenFactoryTest is Test {
    TokenFactory public factory;
    address public user1;
    address public user2;
    address public tokenOwner;

    event TokenCreated(
        address indexed tokenAddress,
        string name,
        string symbol,
        uint256 initialSupply,
        address indexed owner,
        address indexed creator,
        uint256 timestamp
    );

    function setUp() public {
        // Deploy factory without registry for basic tests
        factory = new TokenFactory(address(0));

        // Create test users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        tokenOwner = makeAddr("tokenOwner");
    }

    // ============ Basic Token Creation Tests ============

    function test_CreateToken_Success() public {
        string memory name = "TestToken";
        string memory symbol = "TEST";
        uint256 initialSupply = 1000000;

        vm.prank(user1);
        address tokenAddress = factory.createToken(name, symbol, initialSupply, tokenOwner);

        // Verify token was deployed
        assertTrue(tokenAddress != address(0), "Token address should not be zero");

        // Verify token properties
        MyToken token = MyToken(tokenAddress);
        assertEq(token.name(), name, "Token name mismatch");
        assertEq(token.symbol(), symbol, "Token symbol mismatch");
        assertEq(token.totalSupply(), initialSupply * 10 ** token.decimals(), "Total supply mismatch");
        assertEq(token.owner(), tokenOwner, "Token owner mismatch");

        // Verify owner received tokens
        assertEq(token.balanceOf(tokenOwner), initialSupply * 10 ** token.decimals(), "Owner balance mismatch");
    }

    function test_CreateToken_EmitsEvent() public {
        string memory name = "TestToken";
        string memory symbol = "TEST";
        uint256 initialSupply = 1000000;

        vm.expectEmit(false, true, true, false);
        emit TokenCreated(address(0), name, symbol, initialSupply, tokenOwner, user1, block.timestamp);

        vm.prank(user1);
        factory.createToken(name, symbol, initialSupply, tokenOwner);
    }

    function test_CreateToken_TracksInFactory() public {
        vm.startPrank(user1);

        address token1 = factory.createToken("Token1", "TK1", 1000000, tokenOwner);
        address token2 = factory.createToken("Token2", "TK2", 2000000, tokenOwner);

        vm.stopPrank();

        // Check factory tracking
        assertEq(factory.getTokenCount(), 2, "Token count mismatch");
        assertEq(factory.getTokenAtIndex(0), token1, "First token mismatch");
        assertEq(factory.getTokenAtIndex(1), token2, "Second token mismatch");
        assertTrue(factory.isTokenFromFactory(token1), "Token1 should be from factory");
        assertTrue(factory.isTokenFromFactory(token2), "Token2 should be from factory");
    }

    function test_CreateToken_TracksByCreator() public {
        vm.prank(user1);
        address token1 = factory.createToken("Token1", "TK1", 1000000, tokenOwner);

        vm.prank(user2);
        address token2 = factory.createToken("Token2", "TK2", 2000000, tokenOwner);

        vm.prank(user1);
        address token3 = factory.createToken("Token3", "TK3", 3000000, tokenOwner);

        // Check tokens by creator
        address[] memory user1Tokens = factory.getTokensByCreator(user1);
        address[] memory user2Tokens = factory.getTokensByCreator(user2);

        assertEq(user1Tokens.length, 2, "User1 should have 2 tokens");
        assertEq(user2Tokens.length, 1, "User2 should have 1 token");
        assertEq(user1Tokens[0], token1, "User1 first token mismatch");
        assertEq(user1Tokens[1], token3, "User1 second token mismatch");
        assertEq(user2Tokens[0], token2, "User2 token mismatch");
    }

    function test_CreateToken_MultipleTokensIndependent() public {
        vm.startPrank(user1);

        address token1 = factory.createToken("Token1", "TK1", 1000000, tokenOwner);
        address token2 = factory.createToken("Token2", "TK2", 2000000, user1);

        vm.stopPrank();

        MyToken t1 = MyToken(token1);
        MyToken t2 = MyToken(token2);

        // Verify tokens are independent
        assertEq(t1.name(), "Token1");
        assertEq(t2.name(), "Token2");
        assertEq(t1.symbol(), "TK1");
        assertEq(t2.symbol(), "TK2");
        assertEq(t1.owner(), tokenOwner);
        assertEq(t2.owner(), user1);
    }

    // ============ Input Validation Tests ============

    function test_CreateToken_RevertsOnEmptyName() public {
        vm.prank(user1);
        vm.expectRevert("Name cannot be empty");
        factory.createToken("", "TEST", 1000000, tokenOwner);
    }

    function test_CreateToken_RevertsOnEmptySymbol() public {
        vm.prank(user1);
        vm.expectRevert("Symbol cannot be empty");
        factory.createToken("TestToken", "", 1000000, tokenOwner);
    }

    function test_CreateToken_RevertsOnZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert("Owner cannot be zero address");
        factory.createToken("TestToken", "TEST", 1000000, address(0));
    }

    function test_CreateToken_RevertsOnZeroSupply() public {
        vm.prank(user1);
        vm.expectRevert("Initial supply must be greater than 0");
        factory.createToken("TestToken", "TEST", 0, tokenOwner);
    }

    // ============ View Function Tests ============

    function test_GetTokenCount_StartsAtZero() public view {
        assertEq(factory.getTokenCount(), 0, "Initial token count should be 0");
    }

    function test_GetTokenAtIndex_RevertsOnInvalidIndex() public {
        vm.expectRevert("Index out of bounds");
        factory.getTokenAtIndex(0);

        vm.prank(user1);
        factory.createToken("Token1", "TK1", 1000000, tokenOwner);

        vm.expectRevert("Index out of bounds");
        factory.getTokenAtIndex(1);
    }

    function test_IsTokenFromFactory_ReturnsFalseForNonFactoryToken() public {
        // Deploy token directly (not through factory)
        MyToken directToken = new MyToken("Direct", "DIR", 1000000, tokenOwner);

        assertFalse(factory.isTokenFromFactory(address(directToken)), "Direct token should not be from factory");
        assertFalse(factory.isTokenFromFactory(address(0)), "Zero address should not be from factory");
    }

    function test_GetTokensByCreator_EmptyForNewUser() public view {
        address[] memory tokens = factory.getTokensByCreator(user1);
        assertEq(tokens.length, 0, "New user should have 0 tokens");
    }

    function test_GetAllTokens() public {
        vm.startPrank(user1);
        address token1 = factory.createToken("Token1", "TK1", 1000000, tokenOwner);
        address token2 = factory.createToken("Token2", "TK2", 2000000, tokenOwner);
        address token3 = factory.createToken("Token3", "TK3", 3000000, tokenOwner);
        vm.stopPrank();

        address[] memory allTokens = factory.getAllTokens();
        assertEq(allTokens.length, 3, "Should have 3 tokens");
        assertEq(allTokens[0], token1);
        assertEq(allTokens[1], token2);
        assertEq(allTokens[2], token3);
    }

    // ============ Token Functionality Tests ============

    function test_CreatedToken_CanTransfer() public {
        vm.prank(user1);
        address tokenAddress = factory.createToken("TestToken", "TEST", 1000000, tokenOwner);

        MyToken token = MyToken(tokenAddress);
        uint256 transferAmount = 1000 * 10 ** token.decimals();

        // Transfer from owner to user1
        vm.prank(tokenOwner);
        token.transfer(user1, transferAmount);

        assertEq(token.balanceOf(user1), transferAmount, "User1 balance mismatch after transfer");
    }

    function test_CreatedToken_CanMint() public {
        vm.prank(user1);
        address tokenAddress = factory.createToken("TestToken", "TEST", 1000000, tokenOwner);

        MyToken token = MyToken(tokenAddress);
        uint256 mintAmount = 500000 * 10 ** token.decimals();

        // Only owner can mint
        vm.prank(tokenOwner);
        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount, "User1 balance mismatch after mint");
    }

    function test_CreatedToken_CanBurn() public {
        vm.prank(user1);
        address tokenAddress = factory.createToken("TestToken", "TEST", 1000000, tokenOwner);

        MyToken token = MyToken(tokenAddress);
        uint256 burnAmount = 100000 * 10 ** token.decimals();
        uint256 initialBalance = token.balanceOf(tokenOwner);

        // Owner burns their tokens
        vm.prank(tokenOwner);
        token.burn(burnAmount);

        assertEq(token.balanceOf(tokenOwner), initialBalance - burnAmount, "Balance mismatch after burn");
        assertEq(token.totalSupply(), initialBalance - burnAmount, "Total supply mismatch after burn");
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateToken_WithVariousSupplies(uint256 supply) public {
        // Bound supply to reasonable range
        supply = bound(supply, 1, type(uint128).max);

        vm.prank(user1);
        address tokenAddress = factory.createToken("FuzzToken", "FUZZ", supply, tokenOwner);

        MyToken token = MyToken(tokenAddress);
        assertEq(token.totalSupply(), supply * 10 ** token.decimals());
    }

    function testFuzz_CreateToken_WithDifferentOwners(address owner) public {
        // Exclude zero address
        vm.assume(owner != address(0));

        vm.prank(user1);
        address tokenAddress = factory.createToken("FuzzToken", "FUZZ", 1000000, owner);

        MyToken token = MyToken(tokenAddress);
        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(owner), 1000000 * 10 ** token.decimals());
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_CreateToken() public {
        uint256 gasBefore = gasleft();

        vm.prank(user1);
        factory.createToken("GasTest", "GAS", 1000000, tokenOwner);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for token creation:", gasUsed);
    }

    function test_Gas_CreateMultipleTokens() public {
        vm.startPrank(user1);

        for (uint i = 0; i < 5; i++) {
            uint256 gasBefore = gasleft();

            factory.createToken(
                string(abi.encodePacked("Token", vm.toString(i))),
                string(abi.encodePacked("TK", vm.toString(i))),
                1000000,
                tokenOwner
            );

            uint256 gasUsed = gasBefore - gasleft();
            console.log("Gas used for token", i, ":", gasUsed);
        }

        vm.stopPrank();
    }
}
