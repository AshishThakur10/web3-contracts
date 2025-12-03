// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract QCCSale is Ownable {
    ERC20 public qcc;
    uint256 public ratePerETH; // How many QCC per 1 ETH

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event RateUpdated(uint256 oldRate, uint256 newRate);

    constructor(address _qccToken, uint256 _initialRate) Ownable(msg.sender) {
        qcc = ERC20(_qccToken);
        ratePerETH = _initialRate;
    }

    // Buy QCC using ETH
    function buyTokens() public payable {
        require(msg.value > 0, "Send ETH to buy tokens");

        uint256 tokens = (msg.value * ratePerETH) / 1 ether;

        require(qcc.balanceOf(address(this)) >= tokens, "Not enough tokens in contract");

        qcc.transfer(msg.sender, tokens);

        emit TokensPurchased(msg.sender, msg.value, tokens);
    }

 
    receive() external payable {
        buyTokens();
    }

    // Owner can change price anytime
    function updateRate(uint256 newRate) external onlyOwner {
        uint256 old = ratePerETH;
        ratePerETH = newRate;
        emit RateUpdated(old, newRate);
    }

    // Owner withdraws collected ETH
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Owner withdraws leftover tokens
    function withdrawQCC() external onlyOwner {
        qcc.transfer(owner(), qcc.balanceOf(address(this)));
    }
}
