// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal interfaces for the tokens we need to interact with.
interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

interface IERC20Burnable {
    function burn(address from, uint256 amount) external;
}

interface IERC20Transferable {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

// Ownable contract for access control
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
 * @title GameContract
 * @dev Manages locking of WarpedParsDToken and distribution of UGameToken rewards.
 */
contract GameContract is Ownable {
    // --- State Variables ---

    IERC20Transferable public immutable warpedToken;  // The token to be locked (wPDT)
    IERC20Mintable public immutable lockToken;         // The receipt token for the game (LUGAME)
    IERC20Burnable public immutable lockTokenBurner;    // Same as lockToken, but using a burnable interface
    IERC20Mintable public immutable rewardToken;       // The reward token (UGAME)

    uint256 public constant REWARDS_PER_DAY = 10 * 1e18; // 10 UGAME tokens per day
    uint256 public constant TIME_PERIOD = 24 hours;
    
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // --- Events ---
    event Locked(address indexed user, uint256 amount);
    event Unlocked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 reward);

    // --- Constructor ---

    constructor(
        address _warpedTokenAddress,
        address _lockTokenAddress,
        address _rewardTokenAddress,
        address _initialOwner
    ) Ownable(_initialOwner) {
        warpedToken = IERC20Transferable(_warpedTokenAddress);
        lockToken = IERC20Mintable(_lockTokenAddress);
        lockTokenBurner = IERC20Burnable(_lockTokenAddress);
        rewardToken = IERC20Mintable(_rewardTokenAddress);
        lastUpdateTime = block.timestamp;
    }

    // --- Modifiers ---
    
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        _;
    }

    // --- View Functions for Rewards ---

    function rewardPerToken() public view returns (uint256) {
        uint256 totalLockSupply = warpedToken.totalSupply();
        if (totalLockSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * REWARDS_PER_DAY * 1e18) / (TIME_PERIOD * totalLockSupply);
    }

    function earned(address _account) public view returns (uint256) {
        return (warpedToken.balanceOf(_account) * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 + rewards[_account];
    }
    
    // --- Core Logic Functions (Callable only by Hub) ---
    
    function lock(address _user, uint256 _amount) external onlyOwner updateReward(_user) {
        require(_amount > 0, "GameContract: Cannot lock 0 tokens");
        // Pull wPDT tokens from the user into this contract
        warpedToken.transferFrom(_user, address(this), _amount);
        // Mint an equal amount of LUGAME tokens for the user as a receipt
        lockToken.mint(_user, _amount);
        emit Locked(_user, _amount);
    }
    
    function unlock(address _user, uint256 _amount) external onlyOwner updateReward(_user) {
        require(_amount > 0, "GameContract: Cannot unlock 0 tokens");
        // Burn the user's LUGAME receipt tokens
        lockTokenBurner.burn(_user, _amount);
        // Return the wPDT tokens to the user
        warpedToken.transfer(_user, _amount);
        emit Unlocked(_user, _amount);
    }

    // --- Public Functions ---
    
    /**
     * @dev Distributes rewards for the past period. Can be called by anyone.
     */
    function distributeRewards() public {
        require(block.timestamp >= lastUpdateTime + TIME_PERIOD, "GameContract: 24 hours have not passed");
        uint256 totalLockSupply = warpedToken.totalSupply();
        if (totalLockSupply > 0) {
            uint256 reward = (block.timestamp - lastUpdateTime) * REWARDS_PER_DAY / TIME_PERIOD;
            rewardPerTokenStored = rewardPerTokenStored + (reward * 1e18 / totalLockSupply);
            lastUpdateTime = block.timestamp;
            // Mint new reward tokens and keep them in this contract for users to claim
            rewardToken.mint(address(this), reward);
            emit RewardsDistributed(reward);
        }
    }

    /**
     * @dev Allows a user to claim their accumulated rewards.
     */
    function claimReward() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20Transferable(address(rewardToken)).transfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }
}
