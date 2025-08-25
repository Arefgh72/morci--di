// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --- اینترفیس برای قراردادهایی که هاب با آن‌ها تعامل می‌کند ---

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

// --- قرارداد Ownable برای کنترل دسترسی ---

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

contract MarkazD_Hub is Ownable {
    IWrapperD public immutable wrapperD;
    IGameContract public immutable gameContract;
    IWrapperDToken public immutable wrapperDToken; 
    uint256 private constant DECIMALS = 1e18;

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);
    event LockedInGame(address indexed user, uint256 amount);
    event UnlockedFromGame(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user);
    
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

    // --- توابع عمومی برای کاربران ---

    function wrap() external payable {
        require(msg.value > 0, "Hub: Cannot wrap 0");
        wrapperD.wrap{value: msg.value}(msg.sender);
        emit Wrapped(msg.sender, msg.value);
    }

    function unwrap(uint256 _amount) external {
        require(_amount > 0, "Hub: Cannot unwrap 0");
        wrapperDToken.transferFrom(msg.sender, address(wrapperD), _amount);
        wrapperD.unwrap(msg.sender, _amount);
        emit Unwrapped(msg.sender, _amount);
    }

    function unwrapFull(uint256 _fullAmount) external {
        uint256 amount = _fullAmount * DECIMALS;
        this.unwrap(amount); // <-- اصلاح شد
    }

    function lockInGame(uint256 _amount) external {
        require(_amount > 0, "Hub: Cannot lock 0");
        wrapperDToken.transferFrom(msg.sender, address(gameContract), _amount);
        gameContract.lock(msg.sender, _amount);
        emit LockedInGame(msg.sender, _amount);
    }

    function lockInGameFull(uint256 _fullAmount) external {
        uint256 amount = _fullAmount * DECIMALS;
        this.lockInGame(amount); // <-- اصلاح شد
    }
    
    function unlockFromGame(uint256 _amount) external {
        require(_amount > 0, "Hub: Cannot unlock 0");
        gameContract.unlock(msg.sender, _amount);
        emit UnlockedFromGame(msg.sender, _amount);
    }

    function unlockFromGameFull(uint256 _fullAmount) external {
        uint256 amount = _fullAmount * DECIMALS;
        this.unlockFromGame(amount); // <-- اصلاح شد
    }

    function claimGameReward() external {
        gameContract.claimReward();
        emit RewardClaimed(msg.sender);
    }
}
