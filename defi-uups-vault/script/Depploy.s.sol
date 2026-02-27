// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/vault/DeFiVault.sol";
import "../src/mock/MockERC20.sol";
import "../src/vault/MockStrategy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        MockERC20 token = new MockERC20();

        DeFiVault implementation = new DeFiVault();

        bytes memory data = abi.encodeWithSelector(
            DeFiVault.initialize.selector,
            address(token),
            msg.sender,
            1000
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            data
        );

        DeFiVault vault = DeFiVault(address(proxy));

        MockStrategy strategy = new MockStrategy(
            address(token),
            address(vault)
        );

        vault.setStrategy(address(strategy));

        vm.stopBroadcast();
    }
}