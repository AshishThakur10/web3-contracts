// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract QuickCamCoin is ERC20, ERC20Pausable, ERC20Burnable, AccessControl {

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IERC20 public usdcToken;
    IUniswapV2Pair public uniswapPair;

    event PricePairSet(address indexed pair, address indexed quoteToken);

    constructor(address defaultAdmin, address pauser, address minter, address _usdcToken)
        ERC20("QuickCam Coin", "QCC")
    {
        require(_usdcToken != address(0), "USDC address required");
        usdcToken = IERC20(_usdcToken);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
    }

    // ------------------------------
    // Pausable
    // ------------------------------
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ------------------------------
    // Minting
    // ------------------------------
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // ------------------------------
    // Uniswap Price Management
    // ------------------------------
    function setPricePair(address pair, address _usdcToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(pair != address(0), "Pair address required");
        require(_usdcToken != address(0), "USDC address required");

        uniswapPair = IUniswapV2Pair(pair);
        usdcToken = IERC20(_usdcToken);
        emit PricePairSet(pair, _usdcToken);
    }

    function getQccPriceInUsdc() public view returns (uint256 price) {
        require(address(uniswapPair) != address(0), "Uniswap pair not set");

        (uint112 reserve0, uint112 reserve1,) = uniswapPair.getReserves();
        address token0 = uniswapPair.token0();
        address token1 = uniswapPair.token1();

        uint256 reserveQcc;
        uint256 reserveUsdc;

        if(token0 == address(this) && token1 == address(usdcToken)) {
            reserveQcc = reserve0;
            reserveUsdc = reserve1;
        } else if(token1 == address(this) && token0 == address(usdcToken)) {
            reserveQcc = reserve1;
            reserveUsdc = reserve0;
        } else {
            revert("Pair does not contain QCC and USDC");
        }

        uint8 decimalsQcc = decimals();
        uint8 decimalsUsdc = IERC20Metadata(address(usdcToken)).decimals();

        price = (reserveUsdc * (10**(18 + decimalsQcc))) / (reserveQcc * (10**decimalsUsdc));
    }

    // ------------------------------
    // Buy QCC with USDC
    // ------------------------------
    function buyQccWithUsdc(uint256 usdcAmount) external {
        require(usdcAmount > 0, "Send USDC");
        require(address(uniswapPair) != address(0), "Uniswap pair not set");

        uint256 qccPrice = getQccPriceInUsdc();
        uint256 qccAmount = (usdcAmount * 1e18) / qccPrice;

        require(usdcToken.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        _mint(msg.sender, qccAmount);
    }

    // ------------------------------
    // Sell QCC for USDC
    // ------------------------------
    function sellQccForUsdc(uint256 qccAmount) external {
        require(qccAmount > 0, "Send QCC");
        require(address(uniswapPair) != address(0), "Uniswap pair not set");

        uint256 qccPrice = getQccPriceInUsdc();
        uint256 usdcAmount = (qccAmount * qccPrice) / 1e18;

        _burn(msg.sender, qccAmount);
        require(usdcToken.transfer(msg.sender, usdcAmount), "USDC transfer failed");
    }

    // ------------------------------
    // Override _update (OpenZeppelin 5.x requirement)
    // ------------------------------
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
