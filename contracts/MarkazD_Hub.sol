// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --- Interfaces for the contracts the Hub interacts with ---

interface IWrapperD {
    function wrap(address _user) external payable;
    function unwrap(address _user, uint256 _amount) external;
}

interface IGameContract {
    function lock(address _user, uint256 _amount) external;
    function unlock(address _user, uint256 _amount) external;
    function claimReward() external;
}

interface IWrapperDToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// --- Ownable contract for access control ---

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


/**
 * @title MarkazD_Hub
 * @dev The central entry point for all user interactions with the ecosystem.
 * It acts as a proxy to the WrapperD and Game contracts.
 */
contract MarkazD_Hub is Ownable {
    // --- State Variables ---

    IWrapperD public immutable wrapperD;
    IGameContract public immutable gameContract;
    IWrapperDToken public immutable wrapperDToken; 

    // --- Events ---
    
    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);
    event LockedInGame(address indexed user, uint256 amount);
    event UnlockedFromGame(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user);
    
    // --- Constructor ---

    constructor(
        address _wrapperDAddress,
        address _gameContractAddress,
        address _wrapperDTokenAddress,
        address _initialOwner
    ) Ownable(_initialOwner) {
        wrapperD = IWrapperD(_wrapperDAddress);
        gameContract = IGameContract(_gameContractAddress);
        wrapperDToken = IWrapperDToken(_wrapperDTokenAddress);
    }

    // --- Public User-Facing Functions ---

    /**
     * @dev Wraps native currency into wDT. User sends native currency with the call.
     */
    function wrap() external payable {
        require(msg.value > 0, "Hub: Cannot wrap 0");
        // Forward the call and the native currency to the wrapper contract
        wrapperD.wrap{value: msg.value}(msg.sender);
        emit Wrapped(msg.sender, msg.value);
    }

    /**
     * @dev Unwraps wDT back to native currency. User must first approve this Hub contract to spend their wDT.
     */
    function unwrap(uint256 _amount) external {
        require(_amount > 0, "Hub: Cannot unwrap 0");
        // First, pull the user's wDT tokens to the WrapperD contract
        wrapperDToken.transferFrom(msg.sender, address(wrapperD), _amount);
        // Then, call the unwrap function on the wrapper contract
        wrapperD.unwrap(msg.sender, _amount);
        emit Unwrapped(msg.sender, _amount);
    }

    /**
     * @dev Locks wDT in the game. User must first approve this Hub contract to spend their wDT.
     */
    function lockInGame(uint256 _amount) external {
        require(_amount > 0, "Hub: Cannot lock 0");
        // Pull the user's wDT tokens to the GameContract to be locked
        wrapperDToken.transferFrom(msg.sender, address(gameContract), _amount);
        // Then, call the lock function on the game contract
        gameContract.lock(msg.sender, _amount);
        emit LockedInGame(msg.sender, _amount);
    }
    
    /**
     * @dev Unlocks wDT from the game by burning LUGAME tokens.
     */
    function unlockFromGame(uint256 _amount) external {
        require(_amount > 0, "Hub: Cannot unlock 0");
        gameContract.unlock(msg.sender, _amount);
        emit UnlockedFromGame(msg.sender, _amount);
    }

    /**
     * @dev Claims the user's accumulated game rewards (UGAME).
     */
    function claimGameReward() external {
        gameContract.claimReward();
        emit RewardClaimed(msg.sender);
    }
}
