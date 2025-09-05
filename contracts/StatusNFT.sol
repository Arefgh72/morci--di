// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title WalletStatusNFT
 * @notice A contract for dynamic NFTs representing wallet on-chain status.
 * Each NFT's metadata URI is constructed from a unique root hash.
 * This contract includes a batch update function for gas efficiency.
 */
contract WalletStatusNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // The constant gateway URL, taken directly from 0G's official documentation.
    string private constant GATEWAY_URL = "https://indexer-storage-testnet-turbo.0g.ai/file?root=";

    // Mapping from a tokenId to its unique Merkle Root Hash (the file identifier).
    mapping(uint256 => string) private _tokenRootHashes;

    // Mapping to ensure each wallet can only mint one NFT.
    mapping(address => bool) private _hasMinted;

    // --- Events ---
    event StatusNFTMinted(address indexed owner, uint256 indexed tokenId);
    event TokenRootHashUpdated(uint256 indexed tokenId, string newRootHash);
    event BatchTokenRootHashesUpdated(uint256[] tokenIds);

    /**
     * @dev Sets the name and symbol for the NFT collection.
     */
    constructor() ERC721("Wallet Status NFT", "WSNFT") Ownable(msg.sender) {}

    /**
     * @notice Allows a user to mint their own status NFT. Each address can mint only once.
     */
    function mintStatusNFT() external {
        require(!_hasMinted[msg.sender], "WalletStatusNFT: You have already minted an NFT.");
        _hasMinted[msg.sender] = true;

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);

        emit StatusNFTMinted(msg.sender, tokenId);
    }
    
    /**
     * @notice Sets or updates the unique Merkle Root Hash for a specific token.
     * @dev This can only be called by the contract owner (your script).
     * @param tokenId The ID of the token to update.
     * @param rootHash The new Merkle Root Hash for the token's metadata file.
     */
    function setTokenRootHash(uint256 tokenId, string memory rootHash) external onlyOwner {
        require(_exists(tokenId), "WalletStatusNFT: Cannot set URI for a nonexistent token.");
        _tokenRootHashes[tokenId] = rootHash;
        emit TokenRootHashUpdated(tokenId, rootHash);
    }

    /**
     * @notice Updates the root hashes for multiple tokens in a single transaction for gas efficiency.
     * @dev This can only be called by the contract owner (your script).
     * @param tokenIds An array of token IDs to update.
     * @param rootHashes An array of new Merkle Root Hashes, corresponding to the tokenIds.
     */
    function batchSetTokenRootHashes(uint256[] memory tokenIds, string[] memory rootHashes) external onlyOwner {
        require(tokenIds.length == rootHashes.length, "WalletStatusNFT: Arrays must have the same length.");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(_exists(tokenId), "WalletStatusNFT: One of the tokens does not exist.");
            _tokenRootHashes[tokenId] = rootHashes[i];
        }

        emit BatchTokenRootHashesUpdated(tokenIds);
    }

    /**
     * @notice Returns the full metadata URI for a token.
     * @dev The URI is constructed from the official 0G gateway and the token's unique hash.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "WalletStatusNFT: URI query for nonexistent token.");
        string memory rootHash = _tokenRootHashes[tokenId];
        
        // If no hash has been set for this token yet, return an empty string.
        if (bytes(rootHash).length == 0) {
            return "";
        }
        
        // Concatenate the gateway URL and the unique hash to form the final URI.
        return string(abi.encodePacked(GATEWAY_URL, rootHash));
    }

    /**
     * @dev A helper function to check if a wallet has already minted.
     */
    function hasMinted(address wallet) external view returns (bool) {
        return _hasMinted[wallet];
    }
}

