// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/vault/DeFiVault.sol";
import "../src/vault/DeFiVaultv2.sol";
import "../src/mock/MockERC20.sol";
import "../src/vault/MockStrategy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultTest is Test {
    MockERC20 token;
    DeFiVault implementation;
    DeFiVault vault;
    MockStrategy strategy;

    address owner = address(this);
    address user = address(1);
    address treasury = address(2);

    uint256 constant FEE = 1000; // 10%

    function setUp() public {
        token = new MockERC20();

        implementation = new DeFiVault();

        bytes memory data = abi.encodeWithSelector(
            DeFiVault.initialize.selector,
            address(token),
            treasury,
            FEE
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            data
        );

        vault = DeFiVault(address(proxy));

        strategy = new MockStrategy(address(token), address(vault));
        vault.setStrategy(address(strategy));

        token.mint(user, 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                            BASIC DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 100e18);
        assertEq(vault.totalSupply(), 100e18);
        assertEq(vault.balanceOf(user), 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                            INVEST FLOW
    //////////////////////////////////////////////////////////////*/

    function testInvest() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();

        vault.invest(100e18);

        assertEq(token.balanceOf(address(strategy)), 100e18);
        assertEq(vault.totalAssets(), 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                            YIELD + HARVEST
    //////////////////////////////////////////////////////////////*/

    function testHarvestWithProfit() public {
        // deposit 100
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();

        vault.invest(100e18);

        // simulate +50 yield
        token.mint(address(this), 50e18);
        token.approve(address(strategy), 50e18);
        strategy.simulateYield(50e18);

        uint256 assetsBefore = vault.totalAssets(); // 150
        uint256 supplyBefore = vault.totalSupply(); // 100

        assertEq(assetsBefore, 150e18);

        // expected fee
        uint256 profit = assetsBefore - 100e18; // 50
        uint256 feeAmount = profit * FEE / 10_000; // 5

        // shares minted according to ERC4626 math
        uint256 expectedShares =
            feeAmount * supplyBefore / assetsBefore;

        // harvest
        vault.harvest();

        uint256 treasuryShares = vault.balanceOf(treasury);

        assertApproxEqAbs(
            treasuryShares,
            expectedShares,
            1
        );

        // verify value equivalence
        uint256 treasuryAssets =
            vault.convertToAssets(treasuryShares);

        uint256 newSupply = supplyBefore + expectedShares;

        uint256 expectedAssetsValue =
            expectedShares * assetsBefore / newSupply;

        assertApproxEqAbs(
            treasuryAssets,
            expectedAssetsValue,
            1
        );
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW AFTER YIELD
    //////////////////////////////////////////////////////////////*/

    function testWithdrawAfterYield() public {
        uint256 depositAmount = 100e18;

        // --- user initial balance ---
        uint256 startingBalance = token.balanceOf(user); // 1000e18

        // --- deposit ---
        vm.startPrank(user);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        vault.invest(depositAmount);

        // --- simulate +100 yield ---
        token.mint(address(this), 100e18);
        token.approve(address(strategy), 100e18);
        strategy.simulateYield(100e18);

        uint256 assetsBefore = vault.totalAssets();   // 200e18
        uint256 supplyBefore = vault.totalSupply();   // 100e18

        // --- compute expected fee ---
        uint256 profit = assetsBefore - depositAmount;   // 100e18
        uint256 feeAmount = profit * FEE / 10_000;       // 10e18

        // shares minted to treasury (same math as convertToShares)
        uint256 mintedShares =
            feeAmount * supplyBefore / assetsBefore;

        uint256 newSupply = supplyBefore + mintedShares;

        // --- harvest ---
        vault.harvest();

        // --- redeem all user shares ---
        vm.startPrank(user);
        uint256 userShares = vault.balanceOf(user);
        vault.redeem(userShares, user, user);
        vm.stopPrank();

        // expected assets received from redeem
        uint256 expectedUserAssets =
            userShares * assetsBefore / newSupply;

        // final expected balance
        uint256 expectedFinalBalance =
            startingBalance
            - depositAmount
            + expectedUserAssets;

        assertApproxEqAbs(
            token.balanceOf(user),
            expectedFinalBalance,
            2
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INVARIANT-LIKE CHECK
    //////////////////////////////////////////////////////////////*/

    function testTotalAssetsMatchesBalances() public {
        vm.startPrank(user);
        token.approve(address(vault), 200e18);
        vault.deposit(200e18, user);
        vm.stopPrank();

        vault.invest(150e18);

        uint256 idle = token.balanceOf(address(vault));
        uint256 strat = token.balanceOf(address(strategy));

        assertEq(vault.totalAssets(), idle + strat);
    }

    function testUpgradeToV2() public {
        // user deposit
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();

        // deploy new implementation
        DeFiVaultV2 newImpl = new DeFiVaultV2();

        // upgrade (owner = address(this))
        vault.upgradeToAndCall(address(newImpl), "");

        // cast proxy to V2
        DeFiVaultV2 upgraded = DeFiVaultV2(address(vault));

        // 🔎 check storage preserved
        assertEq(upgraded.balanceOf(user), 100e18);

        // 🔎 check new function works
        assertEq(upgraded.version(), "V2");

        // 🔎 test new state variable
        upgraded.setWithdrawalFee(500);
        assertEq(upgraded.withdrawalFee(), 500);
    }
}