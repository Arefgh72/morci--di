// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract WalletStatusNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // --- THIS IS THE ONLY CHANGE ---
    // The gateway URL is now a standard public IPFS gateway.
    string private constant GATEWAY_URL = "https://gateway.pinata.cloud/ipfs/";

    // Mapping from a tokenId to its unique IPFS CID (Content Identifier).
    mapping(uint256 => string) private _tokenRootHashes;

    // ... (The rest of the contract code is exactly the same as before) ...
    // [Remaining contract code is omitted for brevity but is identical to the previous version]

    mapping(address => bool) private _hasMinted;
    event StatusNFTMinted(address indexed owner, uint256 indexed tokenId);
    event TokenRootHashUpdated(uint256 indexed tokenId, string newRootHash);
    event BatchTokenRootHashesUpdated(uint256[] tokenIds);

    constructor() ERC721("Wallet Status NFT", "WSNFT") Ownable(msg.sender) {}

    function mintStatusNFT() external {
        require(!_hasMinted[msg.sender], "WalletStatusNFT: You have already minted an NFT.");
        _hasMinted[msg.sender] = true;
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);
        emit StatusNFTMinted(msg.sender, tokenId);
    }
    
    function setTokenRootHash(uint256 tokenId, string memory rootHash) external onlyOwner {
        require(_exists(tokenId), "WalletStatusNFT: Cannot set URI for a nonexistent token.");
        _tokenRootHashes[tokenId] = rootHash;
        emit TokenRootHashUpdated(tokenId, rootHash);
    }

    function batchSetTokenRootHashes(uint256[] memory tokenIds, string[] memory rootHashes) external onlyOwner {
        require(tokenIds.length == rootHashes.length, "WalletStatusNFT: Arrays must have the same length.");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(_exists(tokenId), "WalletStatusNFT: One of the tokens does not exist.");
            _tokenRootHashes[tokenId] = rootHashes[i];
        }
        emit BatchTokenRootHashesUpdated(tokenIds);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "WalletStatusNFT: URI query for nonexistent token.");
        string memory rootHash = _tokenRootHashes[tokenId];
        if (bytes(rootHash).length == 0) {
            return "";
        }
        return string(abi.encodePacked(GATEWAY_URL, rootHash));
    }

    function hasMinted(address wallet) external view returns (bool) {
        return _hasMinted[wallet];
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
}
