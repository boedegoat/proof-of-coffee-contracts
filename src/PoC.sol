// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IPoCToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 value) external;
}

contract PoC is Ownable {
    error InvalidToken();
    error DisabledToken();
    error PoCTokenAlreadySet();
    error InsufficientBalance();
    error InvalidAmount(uint256 amount);

    enum TOKEN_STATUS {
        DISABLED,
        ENABLED
    }

    IPoCToken public pocToken;
    mapping (address => TOKEN_STATUS) public paymentToken;

    event OrderedWithToken(address indexed user, uint256 indexed orderId, address token, uint256 total, uint256 points, uint256 timestamp);
    event Withdrawn(address indexed owner, address token, uint256 amount, uint256 timestamp);
    event Refunded(address indexed to, address token, uint256 amount, uint256 timestamp);
    event PaymentTokenSet(address indexed token, TOKEN_STATUS status, uint256 timestamp);
    event PocTokensMinted(address indexed to, uint256 amount, uint256 timestamp);
    event PocTokensBurned(uint256 amount, uint256 timestamp);
    event PoCTokenSet(address token, uint256 timestamp);
    
    constructor(address initialOwner, address[] memory initialPaymentTokens) Ownable(initialOwner) {
        for (uint256 i = 0; i < initialPaymentTokens.length; i++) {
            if (initialPaymentTokens[i] == address(0)) {
                revert InvalidToken();
            }
            paymentToken[initialPaymentTokens[i]] = TOKEN_STATUS.ENABLED;
        }
    }

    modifier validToken(address token) {
        if (token == address(0)) {
            revert InvalidToken();
        }
        _;
    }

    modifier enabledToken(address token) {
        if (paymentToken[token] == TOKEN_STATUS.DISABLED || token != address(pocToken)) {
            revert DisabledToken();
        }
        _;
    }

    function setPoCToken(address token) external onlyOwner validToken(token) {
        if (address(pocToken) != address(0)) revert PoCTokenAlreadySet();
        pocToken = IPoCToken(token);
        emit PoCTokenSet(token, block.timestamp);
    }

    function orderWithToken(uint256 orderId, address token, uint256 total, uint256 points) external validToken(token) enabledToken(token) {
        if (total == 0) revert InvalidAmount(total);
        if (IERC20(token).balanceOf(msg.sender) < total) revert InsufficientBalance();
        if (points > 0) {
            if (pocToken.balanceOf(msg.sender) < points) revert InsufficientBalance();
            pocToken.transferFrom(msg.sender, address(this), points);
        }
        IERC20(token).transferFrom(msg.sender, address(this), total);
        emit OrderedWithToken(msg.sender, orderId, token, total, points, block.timestamp);
    }

    function refund(address token, address to, uint256 amount) external onlyOwner validToken(token) enabledToken(token) {
        IERC20(token).transfer(to, amount);
        emit Refunded(to, token, amount, block.timestamp);
    }

    function withdraw(address token, uint256 amount) external onlyOwner validToken(token) enabledToken(token) {
        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount, block.timestamp);
    }

    function setPaymentToken(address token, TOKEN_STATUS status) external onlyOwner validToken(token) {
        paymentToken[token] = status;
        emit PaymentTokenSet(token, status, block.timestamp);
    }

    function markOrderCompleted(address user, uint256 mintAmount, uint256 burnAmount) external onlyOwner {
        if (mintAmount > 0) _mintPoCTokens(user, mintAmount);
        if (burnAmount > 0) _burnPoCTokens(burnAmount);
    }

    function _mintPoCTokens(address to, uint256 mintAmount) internal {
        pocToken.mint(to, mintAmount);
        emit PocTokensMinted(to, mintAmount, block.timestamp);
    }

    function _burnPoCTokens(uint256 burnAmount) internal {
        pocToken.burn(burnAmount);
        emit PocTokensBurned(burnAmount, block.timestamp);
    }

    receive() external payable {}
    fallback() external payable {}
}

// PoC: https://arbiscan.io/address/0xA7Ff9FD09eD70c174Ae9CB580FB6b31325869a05
// PoCToken: https://arbiscan.io/address/0x5d05133f9dE9892688831613C0A3cB80B4cB2D22