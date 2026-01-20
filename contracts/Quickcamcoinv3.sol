// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract QuickCamCoin is ERC20, ERC20Pausable, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant OPERATIONAL_ROLE = keccak256("OPERATIONAL_ROLE");

    uint256 public RATE; // wei per 1 qcc

    event TokensPurchased(
        address indexed buyer,
        uint256 ethAmount,
        uint256 qccAmount
    );


    constructor(address defaultAdmin, address admin, address pauser, address minter, address burner, address operational, uint256 _rate)
        ERC20("QuickCam Coin", "QCC") 
    {

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        _grantRole(ADMIN_ROLE, admin);

        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(BURNER_ROLE, burner);
        _grantRole(OPERATIONAL_ROLE, operational);

        _grantRole(PAUSER_ROLE, operational);
        _grantRole(BURNER_ROLE, operational);
        _grantRole(MINTER_ROLE, operational);

        RATE = _rate;

    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    // static rate Start
    function updateRate(uint256 newRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        require(newRate > 0, "Rate must be greater then 0");
        RATE = newRate;
    }

    function _processPurchase(address to, uint256 ethAmount) internal {
        require(ethAmount > 0, "Send ETH");
        require(to != address(0), "Invalid address");

        uint256 qccAmount = (ethAmount * 1e18) / RATE;
        _mint(to, qccAmount);

        emit TokensPurchased(to, ethAmount, qccAmount);
    }

    function buyQCC(address to) external payable whenNotPaused {
        _processPurchase(to, msg.value);
    }


    receive() external payable {
        _processPurchase(msg.sender, msg.value);
    }


    function withdrawETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
	    uint256 balance = address(this).balance;
	    require(balance > 0, "No ETH");

	    (bool success, ) = to.call{value: balance}("");
	    require(success, "ETH transfer failed");
	}


    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}