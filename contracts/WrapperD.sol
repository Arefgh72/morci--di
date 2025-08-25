// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// An interface for the WarpedParsDToken, which we now call WrapperDToken
interface IWrapperDToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

// Provides information about the current execution context
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// Provides basic authorization control functions
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

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
 * @title WrapperD
 * @dev Securely holds native currency and mints/burns a corresponding ERC20 token (wDT).
 * All functions are owned and called by the central Hub contract.
 */
contract WrapperD is Ownable {
    // --- State Variables ---

    IWrapperDToken public immutable wrapperDToken;
    uint256 public totalWrapped;

    // --- Events ---

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);

    // --- Constructor ---

    constructor(address _wrapperDTokenAddress, address _initialOwner) Ownable(_initialOwner) {
        require(_wrapperDTokenAddress != address(0), "WrapperD: Invalid token address");
        wrapperDToken = IWrapperDToken(_wrapperDTokenAddress);
    }

    // --- Core Logic (Callable only by Hub) ---

    /**
     * @dev Wraps the native token sent with the transaction.
     * Mints an equal amount of wDT to the user.
     * @param _user The original user who initiated the transaction via the Hub.
     */
    function wrap(address _user) external onlyOwner payable {
        uint256 amount = msg.value;
        require(amount > 0, "WrapperD: Cannot wrap 0");

        totalWrapped += amount;
        wrapperDToken.mint(_user, amount);

        emit Wrapped(_user, amount);
    }

    /**
     * @dev Unwraps a specified amount of wDT.
     * Burns the user's wDT and returns an equal amount of the native token.
     * @param _user The original user who initiated the transaction via the Hub.
     * @param _amount The amount of wDT to unwrap.
     */
    function unwrap(address _user, uint256 _amount) external onlyOwner {
        require(_amount > 0, "WrapperD: Cannot unwrap 0");
        
        totalWrapped -= _amount;
        wrapperDToken.burn(_user, _amount);
        
        // Securely transfer the native token back to the user
        payable(_user).transfer(_amount);
        
        emit Unwrapped(_user, _amount);
    }
}
