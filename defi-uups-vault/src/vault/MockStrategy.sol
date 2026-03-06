// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStrategy {
    IERC20 public immutable asset;
    address public immutable vault;

    constructor(address _asset, address _vault) {
        asset = IERC20(_asset);
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }

    function deposit(uint256 amount) external onlyVault {
        asset.transferFrom(vault, address(this), amount);
    }

    function withdraw(uint256 amount) external onlyVault {
        asset.transfer(vault, amount);
    }

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function simulateYield(uint256 amount) external {
        asset.transferFrom(msg.sender, address(this), amount);
    }
}