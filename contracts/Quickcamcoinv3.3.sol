// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract QuickCamCoin is ERC20, ERC20Pausable, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant OPERATIONAL_ROLE = keccak256("OPERATIONAL_ROLE");

    event TokensPurchased(
        address indexed buyer,
        uint256 ethAmount,
        uint256 qccAmount
    );

    AggregatorV3Interface public ethUsdPriceFeed;

    // QCC price in USD (18 decimals)
    // Example: 1 QCC = 1 USD → 1e18
    uint256 public QCC_PRICE_USD;


    /* ------------------ THRESHOLD STORAGE ------------------ */

    // Ascending list of totalSupply thresholds
    uint256[] public totalSupplyThresholds;

    // threshold => price / multiplier
    mapping(uint256 => uint256) public thresholdPriceMap;

    // Index into totalSupplyThresholds
    uint256 public currentThresholdIndex;

    // Optional cache (gas optimization)
    uint256 public thresholdsLength;



    constructor(address defaultAdmin, address admin, address pauser, address minter, address burner, address operational, address _ethUsdFeed)
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

        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdFeed);
        QCC_PRICE_USD = 1e18; // 1 QCC = 1 U

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

    // packages and throush hold details. 
 

    function addThreshold(uint256 threshold, uint256 price) external onlyRole(BURNER_ROLE) {
        if (thresholdsLength > 0) {
            require(
                threshold > totalSupplyThresholds[thresholdsLength - 1],
                "Threshold must be increasing"
            );
        }

        totalSupplyThresholds.push(threshold);
        thresholdPriceMap[threshold] = price;

        thresholdsLength++;
    }


    function _getEthUsdPrice() internal view returns (uint256) {
        (, int256 price,,,) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid price");

        // Chainlink ETH/USD has 8 decimals → convert to 18
        return uint256(price) * 1e10;
    }

    function _processPurchase(address to, uint256 ethAmount) internal {
        require(ethAmount > 0, "Send ETH");
        require(to != address(0), "Invalid address");

        uint256 ethUsdPrice = _getEthUsdPrice();

        // ETH sent → USD value
        uint256 usdValue = (ethAmount * ethUsdPrice) / 1e18;

        // USD → QCC amount
        uint256 qccAmount = (usdValue * 1e18) / QCC_PRICE_USD;

        _mint(to, qccAmount);

        emit TokensPurchased(to, ethAmount, qccAmount);
    }


    function updateQccPrice(uint256 newPriceUsd) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newPriceUsd > 0, "Invalid price");
        QCC_PRICE_USD = newPriceUsd;
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