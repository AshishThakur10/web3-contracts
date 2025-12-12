// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Minimal Uniswap V2 Router interface used for price queries (getAmountsOut)
interface IUniswapV2Router02 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract QuickCamCoin is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MENTOR_ROLE = keccak256("MENTOR_ROLE");
    bytes32 public constant OPERATIONS_ROLE = keccak256("OPERATIONS_ROLE");
    bytes32 public constant TRANSACT_ROLE = keccak256("TRANSACT_ROLE");

    // External protocol integrations (configurable)
    IUniswapV2Router02 public uniswapRouter; // used to derive price between QCC <-> USDC (or other pair)
    IERC20 public usdcToken; // USDC token contract (configurable per network)

    // Pricing & fees
    // pricePerTokenInUSDC is expressed in USDC smallest unit (e.g., 6 decimals for typical USDC)
    uint256 public pricePerTokenInUSDC;
    uint256 public mentorFeeBps; // basis points (parts per 10,000) charged by mentor on top of token cost
    address public feeCollector;

    // Events
    event PriceUpdated(uint256 newPrice);
    event MentorFeeUpdated(uint256 newFeeBps);
    event FeeCollectorUpdated(address newCollector);
    event RouterUpdated(address newRouter);
    event USDCTokenUpdated(address newUSDCToken);
    event MentorMinted(address indexed by, address indexed to, uint256 quantity, uint256 usdcPaid);
    event OperationsMinted(address indexed by, address indexed to, uint256 quantity);
    event TransactMinted(address indexed by, address indexed to, uint256 quantity);

    constructor(
        address defaultAdmin,
        address pauser,
        address mentor,
        address operations,
        address transact,
        address initialRouter,
        address initialUSDCToken,
        address initialFeeCollector,
        uint256 initialPricePerTokenInUSDC,
        uint256 initialMentorFeeBps
    ) ERC20("QuickCam Coin", "QCC") {
        require(defaultAdmin != address(0), "admin-zero");
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        if (pauser != address(0)) _grantRole(PAUSER_ROLE, pauser);
        if (mentor != address(0)) _grantRole(MENTOR_ROLE, mentor);
        if (operations != address(0)) _grantRole(OPERATIONS_ROLE, operations);
        if (transact != address(0)) _grantRole(TRANSACT_ROLE, transact);

        if (initialRouter != address(0)) uniswapRouter = IUniswapV2Router02(initialRouter);
        if (initialUSDCToken != address(0)) usdcToken = IERC20(initialUSDCToken);

        feeCollector = initialFeeCollector;
        pricePerTokenInUSDC = initialPricePerTokenInUSDC;
        mentorFeeBps = initialMentorFeeBps;

        emit RouterUpdated(initialRouter);
        emit USDCTokenUpdated(initialUSDCToken);
        emit FeeCollectorUpdated(initialFeeCollector);
        emit PriceUpdated(initialPricePerTokenInUSDC);
        emit MentorFeeUpdated(initialMentorFeeBps);
    }

    // ------------------ Admin configuration ------------------
    function setUniswapRouter(address router) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapRouter = IUniswapV2Router02(router);
        emit RouterUpdated(router);
    }

    function setUSDCToken(address _usdc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdcToken = IERC20(_usdc);
        emit USDCTokenUpdated(_usdc);
    }

    function setPricePerTokenInUSDC(uint256 newPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pricePerTokenInUSDC = newPrice;
        emit PriceUpdated(newPrice);
    }

    function setMentorFeeBps(uint256 newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mentorFeeBps = newFeeBps;
        emit MentorFeeUpdated(newFeeBps);
    }

    function setFeeCollector(address collector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeCollector = collector;
        emit FeeCollectorUpdated(collector);
    }

    // ------------------ Pause / Unpause ------------------
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ------------------ Minting functions ------------------

    /// @notice Operations role can mint without fee
    function operationsMint(address to, uint256 quantity) external onlyRole(OPERATIONS_ROLE) {
        require(to != address(0), "to-zero");
        _mint(to, quantity);
        emit OperationsMinted(msg.sender, to, quantity);
    }

    /// @notice Mentor mints on behalf of a user but requires payment in USDC (mentor collects fee into feeCollector)
    /// The caller (mentor) must ensure the payer has approved USDC to this contract for the total cost.
    function mentorMintWithUSDC(address payer, address to, uint256 quantity) external onlyRole(MENTOR_ROLE) {
        require(to != address(0), "to-zero");
        require(payer != address(0), "payer-zero");
        require(address(usdcToken) != address(0), "usdc-not-set");
        require(pricePerTokenInUSDC > 0, "price-not-set");

        // total price = pricePerTokenInUSDC * quantity
        // Note: pricePerTokenInUSDC should be set with USDC decimals in mind (e.g. 6 decimals)
        uint256 totalPrice = pricePerTokenInUSDC * quantity;

        // mentor fee portion in bps
        uint256 feeAmount = (totalPrice * mentorFeeBps) / 10000;
        uint256 amountToCollect = totalPrice + feeAmount;

        // Transfer USDC from payer to feeCollector (or contract then forward). We transfer total to feeCollector for simplicity
        require(usdcToken.transferFrom(payer, feeCollector, amountToCollect), "usdc-transfer-failed");

        // Mint full quantity to recipient
        _mint(to, quantity);

        emit MentorMinted(msg.sender, to, quantity, amountToCollect);
    }

    /// @notice Transact.one or whitelisted external minter can call this role to mint tokens (used by off-chain payment processor integration)
    function transactMint(address to, uint256 quantity) external onlyRole(TRANSACT_ROLE) {
        require(to != address(0), "to-zero");
        _mint(to, quantity);
        emit TransactMinted(msg.sender, to, quantity);
    }

    // ------------------ Price helpers (on-chain Quick estimate using Uniswap) ------------------
    /// @notice Get estimated USDC amount for 1 QCC using Uniswap router
    /// Returns 0 if router or path not configured or call would revert
    function estimateUSDCPerQCC(address qccToken, address usdc, uint256 qccAmount) public view returns (uint256) {
        if (address(uniswapRouter) == address(0)) return 0;
        if (qccToken == address(0) || usdc == address(0)) return 0;
        address[] memory path = new address[](2);
        path[0] = qccToken;
        path[1] = usdc;
        try uniswapRouter.getAmountsOut(qccAmount, path) returns (uint[] memory amounts) {
            return amounts[amounts.length - 1];
        } catch {
            return 0;
        }
    }

    // ------------------ Overrides ------------------
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    // AccessControl supportsInterface comes from inherited contracts
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // ------------------ Convenience / Admin utilities ------------------
    /// @notice Admin can grant multiple roles in one call
    function grantRoles(address target, bytes32[] calldata roles) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < roles.length; ++i) {
            _grantRole(roles[i], target);
        }
    }

    /// @notice Admin can revoke multiple roles in one call
    function revokeRoles(address target, bytes32[] calldata roles) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < roles.length; ++i) {
            _revokeRole(roles[i], target);
        }
    }

    // ------------------ Notes for integrators ------------------
    // - Off-chain payment platforms like Transact.one should be granted TRANSACT_ROLE and will call transactMint() after payment confirmation.
    // - For on-chain purchases via mentors, ensure USDC token address has been set and payer has given approval to this contract.
    // - pricePerTokenInUSDC should be set with the correct USDC decimals for the target network.
    // - For multi-chain deployment, configure uniswapRouter and usdcToken addresses appropriate to each network.
}
