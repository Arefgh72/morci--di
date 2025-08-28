// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title کمک‌کدنویس: بخش اول
 * @dev این بخش شامل تعاریف اولیه، رابط‌ها و کتابخانه‌های مورد نیاز است.
 */

// --- رابط (Interface) قرارداد توکن GGO ---
// این رابط به قرارداد اصلی ما اجازه می‌دهد تا تابع mint را روی قرارداد توکن GGO فراخوانی کند.
interface IGGOToken {
    function mint(address to, uint256 amount) external;
}

// --- کتابخانه شمارنده (Counters Library) از OpenZeppelin ---
// این کتابخانه یک روش امن برای ایجاد شناسه‌های یکتا و افزایشی برای NFTها فراهم می‌کند.
library Counters {
    struct Counter {
        uint256 _value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }
}

// --- قرارداد زمینه (Context Contract) از OpenZeppelin ---
// این یک قرارداد انتزاعی و پایه است که توابعی مانند _msgSender() را برای دریافت
// آدرس فرستنده تراکنش فراهم می‌کند. این کار امنیت قرارداد را در برابر حملات خاص افزایش می‌دهد.
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
/**
 * @title کمک‌کدنویس: بخش دوم - قسمت اول (استاندارد ERC721)
 * @dev این بخش شامل رابط‌ها و تعاریف اولیه استاندارد توکن غیرمثلی (NFT) است.
 */

// --- رابط استاندارد ERC165 ---
// این رابط به قراردادها اجازه می‌دهد تا در زمان اجرا اعلام کنند که از چه رابط‌های دیگری پشتیبانی می‌کنند.
// برای سازگاری ERC721 ضروری است.
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// --- قرارداد پایه ERC165 از OpenZeppelin ---
abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// --- رابط استاندارد ERC721 (بخش متادیتا) ---
interface IERC721Metadata /* is IERC20Metadata */ { // Note: ERC721 can extend other interfaces
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// --- رابط دریافت‌کننده ERC721 ---
// قراردادی که می‌خواهد به صورت امن NFT دریافت کند، باید این رابط را پیاده‌سازی کند.
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
/**
 * @title کمک‌کدنویس: بخش دوم - قسمت دوم (رابط اصلی ERC721)
 * @dev این رابط اصلی، تمام توابع و رویدادهای استاندارد ERC721 را تعریف می‌کند.
 */

// --- رابط (Interface) اصلی و کامل ERC721 ---
interface IERC721 is IERC165 {
    // --- رویدادها (Events) ---

    /**
     * @dev این رویداد زمانی اجرا می‌شود که یک NFT از یک آدرس به آدرس دیگر منتقل شود.
     * این شامل minting (انتقال از آدرس صفر) و burning (انتقال به آدرس صفر) نیز می‌شود.
     */
    event Transfer(address indexed from, address indexed to, uint26 indexed tokenId);

    /**
     * @dev این رویداد زمانی اجرا می‌شود که یک مالک، اجازه‌ی مدیریت یک NFT خاص را به آدرس دیگری می‌دهد.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev این رویداد زمانی اجرا می‌شود که یک مالک، به یک اپراتور اجازه می‌دهد تا تمام NFTهای او را مدیریت کند.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // --- توابع ---

    /**
     * @dev تعداد NFT های یک مالک را برمی‌گرداند.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev مالک یک NFT با شناسه مشخص را برمی‌گرداند.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev یک NFT را از یک آدرس به آدرس دیگر به صورت امن منتقل می‌کند.
     * این تابع بررسی می‌کند که آیا آدرس گیرنده یک قرارداد است یا خیر و در این صورت،
     * اطمینان حاصل می‌کند که آن قرارداد می‌تواند NFT ها را دریافت کند.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev نسخه دیگری از safeTransferFrom بدون داده اضافی.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev یک NFT را از یک آدرس به آدرس دیگر منتقل می‌کند.
     * هشدار: استفاده از این تابع مسئولیت بررسی توانایی دریافت NFT توسط گیرنده را به عهده فراخواننده می‌گذارد.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev به یک آدرس دیگر اجازه می‌دهد تا یک NFT خاص را مدیریت کند.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev آدرسی که برای مدیریت یک NFT خاص تایید شده است را برمی‌گرداند.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev به یک اپراتور اجازه می‌دهد تا تمام NFTهای یک مالک را مدیریت کند یا این اجازه را لغو کند.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev بررسی می‌کند که آیا یک اپراتور اجازه مدیریت تمام NFTهای یک مالک را دارد یا خیر.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
/**
 * @title کمک‌کدنویس: بخش دوم - قسمت سوم (شروع پیاده‌سازی ERC721)
 * @dev این قرارداد، پیاده‌سازی اصلی و کامل استاندارد ERC721 از OpenZeppelin است.
 */

abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    // --- متغیرهای وضعیت (State Variables) ---

    // نگاشت (Mapping) از شناسه توکن (tokenId) به آدرس مالک آن.
    mapping(uint256 => address) private _owners;

    // نگاشت (Mapping) از آدرس مالک به تعداد توکن‌هایی که در اختیار دارد.
    mapping(address => uint256) private _balances;

    // نگاشت (Mapping) از شناسه توکن به آدرسی که برای مدیریت آن تایید شده است.
    mapping(uint256 => address) private _tokenApprovals;

    // نگاشت (Mapping) از آدرس مالک به اپراتورهایی که اجازه مدیریت تمام توکن‌های او را دارند.
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // نام توکن NFT
    string private _name;

    // نماد (سمبل) توکن NFT
    string private _symbol;

    // --- سازنده (Constructor) ---

    /**
     * @dev سازنده قرارداد که نام و نماد مجموعه NFT را تنظیم می‌کند.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev بررسی می‌کند که آیا این قرارداد از یک رابط (Interface) خاص پشتیبانی می‌کند یا خیر.
     * این تابع برای سازگاری با استاندارد ERC165 است.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
/**
 * @title کمک‌کدنویس: بخش دوم - قسمت چهارم (توابع خواندن اطلاعات ERC721)
 * @dev پیاده‌سازی توابعی که اطلاعات NFT را از بلاکچین می‌خوانند.
 */

abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    // ... کدهای بخش ۲.۳ در اینجا قرار دارند ...

    // --- توابع خواندن اطلاعات (View Functions) ---

    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }


    // --- توابع داخلی کمکی (Internal Helper Functions) ---

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
    
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    // --- تابع toString برای تبدیل عدد به رشته ---
    // این تابع توسط tokenURI استفاده می‌شود
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
/**
 * @title کمک‌کدنویس: بخش دوم - قسمت پنجم (توابع تاییدیه ERC721)
 * @dev پیاده‌سازی توابع approve و setApprovalForAll برای مدیریت اجازه‌نامه‌ها.
 */

abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    // ... کدهای بخش ۲.۴ در اینجا قرار دارند ...

    // --- توابع تاییدیه و اجازه‌نامه (Approval Functions) ---

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }


    // --- توابع داخلی کمکی (Internal Helper Functions) ---

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }
}
/**
 * @title Code Helper: Part Two - Section Six (ERC721 Transfer, Mint, and Burn Functions)
 * @dev Implements the core logic for moving, creating, and destroying NFTs.
 */

abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    // ... code from part 2.5 is here ...

    // --- Transfer Functions ---

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    // --- Internal Helper and Core Logic Functions ---

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address
/**
 * @title کمک‌کدنویس: بخش سوم (تعریف قرارداد اصلی، متغیرها و سازنده)
 * @dev در این بخش، قرارداد اصلی LockAndReward را با ارث‌بری از ERC721 و Ownable تعریف می‌کنیم.
 */

// --- قرارداد مالکیت (Ownable Contract) از OpenZeppelin ---
// این قرارداد یک سیستم کنترل دسترسی ساده را فراهم می‌کند که در آن یک حساب به عنوان "مالک" شناخته می‌شود.
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
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


// ######################################################################
// ###           قرارداد اصلی LOCK AND REWARD                      ###
// ######################################################################

contract LockAndReward is ERC721, Ownable {
    // استفاده از کتابخانه شمارنده برای شناسه‌های NFT
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // --- متغیرهای وضعیت سفارشی (Custom State Variables) ---

    // آدرس قرارداد توکن پاداش GGO
    IGGOToken public immutable rewardToken;

    // ساختاری (Struct) برای ذخیره اطلاعات هر قفل
    struct LockInfo {
        address owner;   // آدرس مالک قفل
        uint256 amount;    // مقدار ETH قفل شده
        uint256 startTime; // زمان شروع قفل (timestamp)
    }

    // نگاشت (Mapping) برای مرتبط کردن هر شناسه NFT با اطلاعات قفل آن
    mapping(uint256 => LockInfo) public lockDetails;

    // نرخ پاداش: مقدار GGO در ثانیه به ازای هر واحد ETH قفل شده
    // این عدد با 18 رقم اعشار در نظر گرفته می‌شود تا دقت محاسبات حفظ شود.
    uint256 public rewardRatePerSecondPerEth;

    // --- رویدادهای سفارشی (Custom Events) ---
    event TokensLocked(address indexed user, uint256 indexed tokenId, uint256 amount);
    event TokensUnlocked(address indexed user, uint256 indexed tokenId, uint256 lockedAmount, uint256 rewardAmount);
    event RewardRateChanged(uint256 newRate);


    // --- سازنده (Constructor) ---
    constructor(address _rewardTokenAddress) ERC721("Lock Receipt NFT", "LRN") Ownable() {
        require(_rewardTokenAddress != address(0), "Reward token address cannot be zero");
        rewardToken = IGGOToken(_rewardTokenAddress);
        
        // تنظیم نرخ پاداش اولیه به عنوان مثال
        // این مقدار یعنی به ازای هر 1 اتر، در هر ثانیه 0.001 GGO پاداش داده می‌شود.
        // 1 ether * 1 second * (10**15) / 1e18 = 0.001
        rewardRatePerSecondPerEth = 10**15;
    }
}
/**
 * @title کمک‌کدنویس: بخش چهارم (منطق اصلی قرارداد)
 * @dev پیاده‌سازی توابع lock, unlock، محاسبه پاداش و توابع مدیریتی.
 */

contract LockAndReward is ERC721, Ownable {
    // ... کدهای بخش ۳ در اینجا قرار دارند ...

    // --- توابع اصلی و عمومی (Public Functions) ---

    /**
     * @dev تابع عمومی برای قفل کردن ETH و دریافت NFT.
     * این تابع `payable` است تا بتواند اتر (توکن اصلی شبکه) را دریافت کند.
     */
    function lock() public payable {
        require(msg.value > 0, "Lock amount must be greater than zero");

        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();

        // 1. ساخت (mint) یک NFT جدید برای کاربر به عنوان رسید
        _safeMint(msg.sender, newTokenId);

        // 2. ذخیره اطلاعات قفل در نگاشت (mapping)
        lockDetails[newTokenId] = LockInfo({
            owner: msg.sender,
            amount: msg.value,
            startTime: block.timestamp
        });

        emit TokensLocked(msg.sender, newTokenId, msg.value);
    }

    /**
     * @dev تابع عمومی برای آزادسازی ETH و دریافت پاداش با سوزاندن NFT.
     * @param _tokenId شناسه NFT که به عنوان سند مالکیت عمل می‌کند.
     */
    function unlock(uint256 _tokenId) public {
        // 1. بررسی اینکه آیا فراخواننده تابع، مالک NFT است یا خیر
        require(ownerOf(_tokenId) == msg.sender, "Unlock caller is not the owner of this NFT");

        LockInfo storage currentLock = lockDetails[_tokenId];

        // 2. محاسبه پاداش
        uint256 rewardAmount = _calculateReward(currentLock.amount, currentLock.startTime);

        // 3. سوزاندن NFT
        _burn(_tokenId);

        // 4. حذف اطلاعات قفل برای صرفه‌جویی در هزینه Gas
        delete lockDetails[_tokenId];

        // 5. ضرب کردن توکن پاداش GGO مستقیماً برای کاربر
        if (rewardAmount > 0) {
            rewardToken.mint(msg.sender, rewardAmount);
        }

        // 6. بازگرداندن ETH قفل شده به کاربر
        (bool sent, ) = msg.sender.call{value: currentLock.amount}("");
        require(sent, "Failed to send Ether back to the user");

        emit TokensUnlocked(msg.sender, _tokenId, currentLock.amount, rewardAmount);
    }


    // --- توابع خواندن اطلاعات و مدیریتی ---

    /**
     * @dev تابعی برای مشاهده جزئیات یک قفل خاص از طریق شناسه NFT.
     */
    function getLockInfo(uint256 _tokenId) public view returns (LockInfo memory) {
        require(_exists(_tokenId), "Token ID does not exist");
        return lockDetails[_tokenId];
    }

    /**
     * @dev تابعی برای مالک قرارداد تا بتواند نرخ پاداش را تغییر دهد.
     */
    function setRewardRate(uint256 _newRate) public onlyOwner {
        rewardRatePerSecondPerEth = _newRate;
        emit RewardRateChanged(_newRate);
    }


    // --- تابع داخلی کمکی (Internal Helper Function) ---

    /**
     * @dev فرمول داخلی برای محاسبه پاداش.
     */
    function _calculateReward(uint256 _amount, uint256 _startTime) internal view returns (uint256) {
        uint256 lockDuration = block.timestamp - _startTime;
        
        // فرمول: پاداش = (مقدار * مدت_زمان * نرخ_پاداش) / 10**18
        // مخرج 10**18 برای مدیریت اعشار در نرخ پاداش است.
        return (_amount * lockDuration * rewardRatePerSecondPerEth) / 1e18;
    }
}
