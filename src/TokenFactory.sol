// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MyToken} from "./MyToken.sol";

/**
 * @title TokenFactory
 * @dev Factory contract for deploying ERC20 tokens with custom parameters
 * @notice This contract allows users to create new ERC20 token instances by specifying
 * name, symbol, initial supply, and owner address
 */
contract TokenFactory {

    // ============ State Variables ============

    address public immutable registry;
    address[] private deployedTokens;
    mapping(address => bool) private isFromFactory;
    mapping(address => address[]) private tokensByCreator;

    // ============ Events ============

    event TokenCreated(
        address indexed tokenAddress,
        string name,
        string symbol,
        uint256 initialSupply,
        address indexed owner,
        address indexed creator,
        uint256 timestamp
    );

    // ============ Constructor ============

    /**
     * @dev Initialize the factory with optional registry address
     * @param _registry Address of the TokenRegistry contract (can be address(0) if not using registry)
     */
    constructor(address _registry) {
        registry = _registry;
    }

    // ============ Token Creation ============

    /**
     * @dev Create a new ERC20 token with custom parameters
     * @param name Token name (e.g., "MyToken")
     * @param symbol Token symbol (e.g., "MTK")
     * @param initialSupply Initial token supply (will be scaled by 10**decimals)
     * @param owner Address that will own the newly created token
     * @return tokenAddress Address of the newly deployed token
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) external returns (address tokenAddress) {
        // Input validation
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(owner != address(0), "Owner cannot be zero address");
        require(initialSupply > 0, "Initial supply must be greater than 0");

        // Deploy new token
        MyToken newToken = new MyToken(name, symbol, initialSupply, owner);
        tokenAddress = address(newToken);

        // Track deployment
        deployedTokens.push(tokenAddress);
        isFromFactory[tokenAddress] = true;
        tokensByCreator[msg.sender].push(tokenAddress);

        // Register with TokenRegistry if available
        if (registry != address(0)) {
            _registerToken(tokenAddress, name, symbol, 18, msg.sender);
        }

        // Emit event
        emit TokenCreated(
            tokenAddress,
            name,
            symbol,
            initialSupply,
            owner,
            msg.sender,
            block.timestamp
        );

        return tokenAddress;
    }

    // ============ Internal Functions ============

    /**
     * @dev Register token with the TokenRegistry contract
     * @param tokenAddress Address of the token to register
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token decimals
     * @param creator Address that created the token
     */
    function _registerToken(
        address tokenAddress,
        string memory name,
        string memory symbol,
        uint256 decimals,
        address creator
    ) internal {
        // Call registry's registerToken function
        // Type 0 = Solidity token
        (bool success, ) = registry.call(
            abi.encodeWithSignature(
                "registerToken(address,bytes,bytes,uint256,address,uint256)",
                tokenAddress,
                bytes(name),
                bytes(symbol),
                decimals,
                creator,
                0 // token_type: 0 for Solidity
            )
        );

        // Note: We don't revert if registration fails to allow token creation
        // even if registry is unavailable
        if (!success) {
            // Could emit an event here for monitoring
        }
    }

    // ============ View Functions ============

    /**
     * @dev Get total number of tokens created by this factory
     * @return count Number of tokens created
     */
    function getTokenCount() external view returns (uint256 count) {
        return deployedTokens.length;
    }

    /**
     * @dev Get token address at specific index
     * @param index Index in the deployedTokens array
     * @return tokenAddress Address of token at the given index
     */
    function getTokenAtIndex(uint256 index) external view returns (address tokenAddress) {
        require(index < deployedTokens.length, "Index out of bounds");
        return deployedTokens[index];
    }

    /**
     * @dev Check if a token was created by this factory
     * @param token Address to check
     * @return isFactory True if token was created by this factory
     */
    function isTokenFromFactory(address token) external view returns (bool isFactory) {
        return isFromFactory[token];
    }

    /**
     * @dev Get all tokens created by a specific address
     * @param creator Address of the creator
     * @return tokens Array of token addresses created by the creator
     */
    function getTokensByCreator(address creator) external view returns (address[] memory tokens) {
        return tokensByCreator[creator];
    }

    /**
     * @dev Get all tokens created by this factory
     * @return tokens Array of all token addresses
     */
    function getAllTokens() external view returns (address[] memory tokens) {
        return deployedTokens;
    }
}
