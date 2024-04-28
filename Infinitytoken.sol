// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e., if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}

/**
 * @title ERC20 interface
 * @dev ERC20 token standard interface
 */
interface IERC20 {
    /**
     * @dev Returns the total supply of the token
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the balance of the account
     * @param account Address of the account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Transfers tokens from the caller's account to another account
     * @param recipient Address of the recipient
     * @param amount Amount of tokens to transfer
     * @return Boolean indicating success of the transfer
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining allowance of tokens granted to a spender
     * @param owner Address of the token owner
     * @param spender Address of the spender
     * @return Remaining allowance
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Approves a spender to spend a certain amount of tokens on behalf of the owner
     * @param spender Address of the spender
     * @param amount Amount of tokens to approve
     * @return Boolean indicating success of the approval
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Transfers tokens from one account to another using allowance mechanism
     * @param sender Address of the sender
     * @param recipient Address of the recipient
     * @param amount Amount of tokens to transfer
     * @return Boolean indicating success of the transfer
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when tokens are transferred from one account to another
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when approval is granted for spending tokens
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title LoopOfInfinity
 * @dev ERC20 token contract implementing the Loop Of Infinity (LOI) token
 */
contract LoopOfInfinity is IERC20 {
    using SafeMath for uint256;

    string public name = "Drop"; // Token name
    string public symbol = "Drop"; // Token symbol
    uint8 public decimals = 18; // Token decimals
    uint256 private constant MAX_SUPPLY = 150000000000 * (10 ** uint256(18)); // Maximum token supply
    uint256 private constant TAX_RATE = 2; // Transfer tax rate (2%)
    address private _owner; // Contract owner address
    bool private _paused; // Flag indicating if the contract is paused
    bool private _recoverTokensLock; // Reentrancy guard for recoverTokens function
    mapping(address => uint256) private _balances; // Balances of token holders
    mapping(address => mapping(address => uint256)) private _allowances; // Allowances for token spending
    mapping(address => bool) private _blacklist; // Blacklist of addresses
    uint256 private _totalSupply; // Total token supply

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Pause();
    event Unpause();
    event AuditTrail(address indexed sender, string action, uint256 amount);
    event EmergencyTransfer(address indexed from, address indexed to, uint256 amount);
    event AccountFrozen(address indexed account, bool frozen);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event TokenRecovered(address indexed token, address indexed recipient, uint256 amount);

    // Modifiers

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Contract is paused");
        _;
    }

    /**
     * @dev Throws if the recoverTokens function is locked (reentrancy guard).
     */
    modifier noReentrancy() {
        require(!_recoverTokensLock, "Reentrancy guard: reentrant call");
        _recoverTokensLock = true;
        _;
        _recoverTokensLock = false;
    }

    /**
     * @dev Contract constructor
     */
    constructor() {
        _owner = msg.sender;
        _totalSupply = MAX_SUPPLY;
        _balances[_owner] = MAX_SUPPLY;
        emit Transfer(address(0), _owner, MAX_SUPPLY);
        emit OwnershipTransferred(address(0), _owner);
    }

    // External functions

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     */
    function transfer(address recipient, uint256 amount) external override whenNotPaused returns (bool) {
        require(!_blacklist[msg.sender], "Sender is blacklisted");
        require(!_blacklist[recipient], "Recipient is blacklisted");
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     */
    function approve(address spender, uint256 amount) external override whenNotPaused returns (bool) {
        require(!_blacklist[msg.sender], "Sender is blacklisted");
        require(!_blacklist[spender], "Spender is blacklisted");
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override whenNotPaused returns (bool) {
        require(!_blacklist[sender], "Sender is blacklisted");
        require(!_blacklist[recipient], "Recipient is blacklisted");
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    /**
     * @dev Increases the allowance for `spender` to spend on behalf of `owner`.
     */
    function increaseAllowance(address spender, uint256 addedValue) external whenNotPaused returns (bool) {
        require(!_blacklist[msg.sender], "Sender is blacklisted");
        require(!_blacklist[spender], "Spender is blacklisted");
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Decreases the allowance for `spender` to spend on behalf of `owner`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external whenNotPaused returns (bool) {
        require(!_blacklist[msg.sender], "Sender is blacklisted");
        require(!_blacklist[spender], "Spender is blacklisted");
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Pauses the contract. Only the owner can call this function.
     */
    function pause() external onlyOwner {
        require(!_paused, "Contract already paused");
        _paused = true;
        emit Pause();
    }

    /**
     * @dev Unpauses the contract. Only the owner can call this function.
     */
    function unpause() external onlyOwner {
        require(_paused, "Contract not paused");
        _paused = false;
        emit Unpause();
    }

    /**
     * @dev Checks if the contract is paused.
     */
    function paused() external view returns (bool) {
        return _paused;
    }

    /**
     * @dev Freezes or unfreezes an account (`account`). Only the owner can call this function.
     */
    function freezeAccount(address account, bool freeze) external onlyOwner {
        _blacklist[account] = freeze;
        emit AccountFrozen(account, freeze);
    }

    /**
     * @dev Adds an address to the blacklist.
     */
    function addToBlacklist(address account) external onlyOwner {
        require(account != address(0), "Blacklist address cannot be the zero address");
        require(!_blacklist[account], "Address already blacklisted");
        _blacklist[account] = true;
        emit BlacklistUpdated(account, true);
    }

    /**
     * @dev Removes an address from the blacklist.
     */
    function removeFromBlacklist(address account) external onlyOwner {
        require(account != address(0), "Blacklist address cannot be the zero address");
        require(_blacklist[account], "Address not blacklisted");
        _blacklist[account] = false;
        emit BlacklistUpdated(account, false);
    }

    /**
     * @dev Transfers tokens in emergency situations to a specified account (`to`). Only the owner can call this function.
     */
    function emergencyTransfer(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Transfer to the zero address");
        require(amount <= _balances[_owner], "Insufficient balance");
        
        _transfer(_owner, to, amount);
        emit EmergencyTransfer(_owner, to, amount);
    }

    /**
     * @dev Recovers tokens mistakenly sent to the contract for a specified ERC20 token (`token`). Only the owner can call this function.
     * @notice This function is protected by a reentrancy guard.
     */
    function recoverTokens(address token, address to, uint256 amount) external onlyOwner noReentrancy {
        require(token != address(0), "Token address cannot be zero");
        require(to != address(0), "Recovery to the zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient balance for recovery");

        IERC20(token).transfer(to, amount);
        emit TokenRecovered(token, to, amount);
    }

    // Internal functions

    /**
     * @dev Executes a transfer of tokens from one account to another.
     * Applies a transfer tax to the sender and records an audit trail.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 taxAmount = amount.mul(TAX_RATE).div(100);
        uint256 netAmount = amount.sub(taxAmount);

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(netAmount);
        _balances[_owner] = _balances[_owner].add(taxAmount); // Send tax to owner
        
        emit Transfer(sender, recipient, netAmount);
        emit Transfer(sender, _owner, taxAmount); // Emit Transfer event for tax sent to owner
        emit AuditTrail(sender, "Transfer", amount);
    }

    /**
     * @dev Approves an allowance for `spender` to transfer tokens on behalf of `owner`.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

