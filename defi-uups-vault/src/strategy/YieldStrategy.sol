// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RealYieldStrategy {

    IERC20 public asset;
    address public vault;

    uint256 public totalShares;
    uint256 public exchangeRate = 1e18;

    mapping(address => uint256) public shares;

    modifier onlyVault() {
        require(msg.sender == vault, "not vault");
        _;
    }

    constructor(address _asset, address _vault) {
        asset = IERC20(_asset);
        vault = _vault;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external onlyVault {

        uint256 newShares =
            (amount * 1e18) / exchangeRate;

        totalShares += newShares;
        shares[vault] += newShares;

        asset.transferFrom(msg.sender, address(this), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function withdraw(uint256 amount) external onlyVault {

        uint256 shareAmount =
            (amount * 1e18) / exchangeRate;

        shares[vault] -= shareAmount;
        totalShares -= shareAmount;

        asset.transfer(vault, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        TOTAL ASSETS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view returns (uint256) {

        return (totalShares * exchangeRate) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD ACCRUAL
    //////////////////////////////////////////////////////////////*/

    function accrueYield(uint256 yieldBps) external {

        // example: 500 = 5%
        exchangeRate =
            exchangeRate +
            (exchangeRate * yieldBps) / 10_000;
    }
}