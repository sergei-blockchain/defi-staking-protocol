// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalAssets() external view returns (uint256);
}

contract DeFiVault is
    Initializable,
    ERC4626Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    uint256 public performanceFee;
    address public treasury;
    address public strategy;
    uint256 public lastTotalAssets;

    uint256 private constant MAX_FEE = 2000;

    /// EVENTS

    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);

    event FeeUpdated(uint256 oldFee, uint256 newFee);

    event Invested(address indexed strategy, uint256 amount);

    event Harvest(uint256 profit, uint256 feeSharesMinted);

    event DepositAssets(address indexed user, uint256 assets, uint256 shares);

    event WithdrawAssets(address indexed user, uint256 assets, uint256 shares);

    function initialize(
        address asset_,
        address treasury_,
        uint256 fee_
    ) public initializer {
        require(fee_ <= MAX_FEE, "Fee too high");

        __ERC20_init("Vault Share", "vSHARE");
        __ERC4626_init(IERC20(asset_));
        __ERC20Permit_init("Vault Share");
        __Ownable_init(msg.sender);

        treasury = treasury_;
        performanceFee = fee_;
        lastTotalAssets = 0;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function setStrategy(address _strategy) external onlyOwner {
        address old = strategy;
        strategy = _strategy;

        emit StrategyUpdated(old, _strategy);
    }

    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Too high");

        uint256 old = performanceFee;
        performanceFee = newFee;

        emit FeeUpdated(old, newFee);
    }

    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (uint256 shares) {
        IERC20Permit(asset()).permit(
            msg.sender,
            address(this),
            assets,
            deadline,
            v,
            r,
            s
        );

        shares = deposit(assets, receiver);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        uint256 invested = strategy == address(0)
            ? 0
            : IStrategy(strategy).totalAssets();

        return idle + invested;
    }

    function invest(uint256 amount) external onlyOwner {
        require(strategy != address(0), "No strategy");

        IERC20(asset()).approve(strategy, amount);
        IStrategy(strategy).deposit(amount);

        emit Invested(strategy, amount);
    }

    function harvest() external nonReentrant {
        uint256 currentAssets = totalAssets();

        if (currentAssets <= lastTotalAssets) {
            lastTotalAssets = currentAssets;
            return;
        }

        uint256 profit = currentAssets - lastTotalAssets;
        uint256 feeAmount = (profit * performanceFee) / 10_000;

        uint256 sharesToMint = 0;

        if (feeAmount > 0) {
            sharesToMint = convertToShares(feeAmount);
            _mint(treasury, sharesToMint);
        }

        lastTotalAssets = totalAssets();

        emit Harvest(profit, sharesToMint);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {

        uint256 idle = IERC20(asset()).balanceOf(address(this));

        if (idle < assets) {
            uint256 missing = assets - idle;
            IStrategy(strategy).withdraw(missing);
        }

        super._withdraw(caller, receiver, owner, assets, shares);

        emit WithdrawAssets(receiver, assets, shares);
    }

    function decimals()
        public
        view
        override(ERC20Upgradeable, ERC4626Upgradeable)
        returns (uint8)
    {
        return super.decimals();
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256)
    {
        uint256 shares = super.deposit(assets, receiver);

        lastTotalAssets = totalAssets();

        emit DepositAssets(receiver, assets, shares);

        return shares;
    }

    uint256[50] private __gap;
}