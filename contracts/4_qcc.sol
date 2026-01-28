// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ===================== IMPORTS ===================== */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/* ===================== UNISWAP INTERFACE ===================== */
interface IUniswapV2Router02 {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

/* ===================== CONTRACT ===================== */
contract QCC is ERC20, AccessControl {

    /* ===================== ROLES ===================== */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* ===================== STATE ===================== */
    IUniswapV2Router02 public uniswapRouter;
    address public usdcToken;

    /* ===================== CONSTRUCTOR ===================== */
    constructor(
        address _router,
        address _usdc
    ) ERC20("QCC Token", "QCC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        uniswapRouter = IUniswapV2Router02(_router);
        usdcToken = _usdc;

        // Optional initial mint (remove if not needed)
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    /* =========================================================
                        PRICE ESTIMATION
       ========================================================= */

    function estimateUSDCPerQCC(uint256 qccAmount)
        public
        view
        returns (uint256)
    {
        if (address(uniswapRouter) == address(0)) return 0;
        if (usdcToken == address(0)) return 0;
        if (qccAmount == 0) return 0;

        // ✅ CORRECT declaration (fixes ALL your errors)
        address;
        path[0] = address(this);
        path[1] = usdcToken;

        try uniswapRouter.getAmountsOut(qccAmount, path)
            returns (uint256[] memory amounts)
        {
            return amounts[amounts.length - 1];
        } catch {
            return 0;
        }
    }

    /* =========================================================
                        ADMIN FUNCTIONS
       ========================================================= */

    function setUniswapRouter(address _router)
        external
        onlyRole(ADMIN_ROLE)
    {
        uniswapRouter = IUniswapV2Router02(_router);
    }

    function setUSDCToken(address _usdc)
        external
        onlyRole(ADMIN_ROLE)
    {
        usdcToken = _usdc;
    }

    function mint(address to, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        _mint(to, amount);
    }

    /* =========================================================
                        ROLE MANAGEMENT
       ========================================================= */

    function revokeRoles(
        address target,
        bytes32[] calldata roles
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < roles.length; i++) {
            _revokeRole(roles[i], target);
        }
    }
}
