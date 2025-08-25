// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal interfaces needed for interaction
interface IYazdParadiseNFT {
    function mint(address to) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

interface IParsToken {
    function mint(address to, uint256 amount) external;
}

// Minimal Ownable contract
abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor(address initialOwner) { _transferOwnership(initialOwner); }
    function owner() public view virtual returns (address) { return _owner; }
    modifier onlyOwner() { require(owner() == _msgSender(), "Ownable: caller is not the owner"); _; }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract MainContract is Ownable {
    IYazdParadiseNFT public yazdParadiseNFT;
    IParsToken public parsToken;

    event Interacted(address indexed user, uint256 nftBalanceBefore, uint256 newNftId, uint256 parsTokenMinted);

    constructor(address _yazdParadiseNFTAddress, address _parsTokenAddress, address initialOwner)
        Ownable(initialOwner)
    {
        yazdParadiseNFT = IYazdParadiseNFT(_yazdParadiseNFTAddress);
        parsToken = IParsToken(_parsTokenAddress);
    }

    function interact(address _originalCaller) external onlyOwner returns (uint256) {
        uint256 currentNftBalance = yazdParadiseNFT.balanceOf(_originalCaller);
        uint256 newNftId = yazdParadiseNFT.mint(_originalCaller);
        uint256 parsToMint = 0;
        if (currentNftBalance > 0) {
            uint256 x = currentNftBalance;
            uint256 y = (uint256(keccak256(abi.encodePacked(block.timestamp, _originalCaller, block.number, x, newNftId))) % 10) + 1;
            uint256 g_full_tokens = (100 * y) * x;
            parsToMint = g_full_tokens * (1 ether);
            if (parsToMint > 0) {
                 parsToken.mint(_originalCaller, parsToMint);
            }
        }
        emit Interacted(_originalCaller, currentNftBalance, newNftId, parsToMint);
        return newNftId;
    }

    function setYazdParadiseNFTAddress(address _newAddress) external onlyOwner {
        yazdParadiseNFT = IYazdParadiseNFT(_newAddress);
    }

    function setParsTokenAddress(address _newAddress) external onlyOwner {
        parsToken = IParsToken(_newAddress);
    }

    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
