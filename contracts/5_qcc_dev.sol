// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract QuickCamCoin is ERC20, ERC20Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // 1 QCC = 0.002 ETH
    uint256 public constant RATE = 0.002 ether;

    event TokensPurchased(
        address indexed buyer,
        uint256 ethAmount,
        uint256 qccAmount
    );

    constructor(address defaultAdmin, address pauser, address minter)
        ERC20("QuickCam Coin", "QCC")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
    }

    // -----------------------------
    // USER BUYS QCC WITH ETH
    // -----------------------------
    function buyQCC() external payable whenNotPaused {
        require(msg.value > 0, "Send ETH");

        uint256 qccAmount = (msg.value * 1e18) / RATE;

        _mint(msg.sender, qccAmount);

        emit TokensPurchased(msg.sender, msg.value, qccAmount);
    }

    // -----------------------------
    // ADMIN FUNCTIONS
    // -----------------------------
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
    {
        _mint(to, amount);
    }

    // function withdrawETH(address payable to)
    //     external
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     require(address(this).balance > 0, "No ETH");
    //     to.transfer(address(this).balance);
    // }

    function withdrawETH(address payable to)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
{
    uint256 balance = address(this).balance;
    require(balance > 0, "No ETH");

    (bool success, ) = to.call{value: balance}("");
    require(success, "ETH transfer failed");
}


    // -----------------------------
    // REQUIRED OVERRIDE
    // -----------------------------
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
