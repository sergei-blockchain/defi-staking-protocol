// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeFiVault.sol";

contract DeFiVaultV2 is DeFiVault {

    /// NEW STORAGE 
    uint256 public withdrawalFee; // basis points

    /// EVENT
    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);

    function setWithdrawalFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "Too high"); // max 10%

        uint256 old = withdrawalFee;
        withdrawalFee = _fee;

        emit WithdrawalFeeUpdated(old, _fee);
    }

    function version() external pure returns (string memory) {
        return "V2";
    }
}