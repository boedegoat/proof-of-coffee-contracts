// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {PoCToken} from "./PoCToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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

    PoCToken public pocToken;
    mapping (address => TOKEN_STATUS) public paymentToken;

    event OrderedWithToken(address indexed user, uint256 indexed orderId, address token, uint256 total, uint256 totalIdr, uint256 points, uint256 timestamp);
    event Withdrawn(address indexed owner, address token, uint256 amount, uint256 timestamp);
    event Refunded(address indexed to, address token, uint256 amount, uint256 timestamp);
    event PaymentTokenSet(address indexed token, TOKEN_STATUS status, uint256 timestamp);
    event PocTokensMinted(address indexed to, uint256 amount, uint256 timestamp);
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
        if (paymentToken[token] == TOKEN_STATUS.DISABLED) {
            revert DisabledToken();
        }
        _;
    }

    function setPoCToken(address token) external onlyOwner validToken(token) {
        if (address(pocToken) != address(0)) revert PoCTokenAlreadySet();
        pocToken = PoCToken(token);
        emit PoCTokenSet(token, block.timestamp);
    }

    function orderWithToken(uint256 orderId, address token, uint256 total, uint256 totalIdr, uint256 points) external validToken(token) enabledToken(token) {
        if (total == 0) revert InvalidAmount(total);
        if (IERC20(token).balanceOf(msg.sender) < total) revert InsufficientBalance();
        if (points > 0) {
            if (pocToken.balanceOf(msg.sender) < points) revert InsufficientBalance();
            pocToken.burnFrom(msg.sender, points);
        }
        IERC20(token).transferFrom(msg.sender, address(this), total);
        emit OrderedWithToken(msg.sender, orderId, token, total, totalIdr, points, block.timestamp);
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

    function mintPoCTokens(address to, uint256 amount) external onlyOwner {
        pocToken.mint(to, amount);
        emit PocTokensMinted(to, amount, block.timestamp);
    }

    receive() external payable {}
    fallback() external payable {}
}

// PoC: https://arbiscan.io/address/0x7afa6498ff856a5b5c02eb290c6b4019d312b38d
// PoCToken: https://arbiscan.io/address/0x4f3c9eAAF79A07A46F69b8AF3F9cA564ba21e1Da