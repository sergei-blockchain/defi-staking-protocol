// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeFiVault.sol";

contract DeFiVaultV2 is DeFiVault {

    // 🔥 ВАЖНО: новая storage переменная ТОЛЬКО В КОНЕЦ
    uint256 public withdrawalFee; // basis points

    function setWithdrawalFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "Too high"); // max 10%
        withdrawalFee = _fee;
    }

    function version() external pure returns (string memory) {
        return "V2";
    }
}