// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/MockERC20.sol";
import {StakingVault} from "../../src/StakingVault.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";

contract StakingVaultTest is Test {
    MockERC20 public token;
    StakingVault public vault;
    DeployVault public deployer;

    address USER = makeAddr("user");

    function setUp() public {
        deployer = new DeployVault();
        (token, vault) = deployer.run();
    }

    function testInflationAttackDoesNotStealVictimFunds() public {
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");

        // Give both actors tokens to work with
        token.mint(attacker, 1);
        token.mint(victim, 5000 ether);

        // Step 1: Attacker deposits the minimum amount (1 wei of token) as first depositor
        vm.startPrank(attacker);
        token.approve(address(vault), 1);
        vault.deposit(1, attacker);
        vm.stopPrank();

        // Step 2: Attacker donates a huge amount DIRECTLY to the vault, bypassing deposit()
        token.mint(attacker, 10_000 ether);
        vm.prank(attacker);
        token.transfer(address(vault), 10_000 ether);

        // Step 3: Victim deposits a reasonable amount
        vm.startPrank(victim);
        token.approve(address(vault), 5000 ether);
        uint256 victimShares = vault.deposit(5000 ether, victim);
        vm.stopPrank();

        // The victim must receive a meaningful, non-zero amount of shares
        assertGt(victimShares, 0);

        // The victim must be able to redeem back close to what they deposited
        // (allowing for reasonable rounding, not losing everything)
        vm.prank(victim);
        uint256 assetsBack = vault.redeem(victimShares, victim, victim);

        assertApproxEqRel(assetsBack, 5000 ether, 0.01e18); // within 1% tolerance
    }

    function testDepositAndWithdrawReturnsFullAmount() public {
        token.mint(USER, 1000 ether);

        vm.startPrank(USER);
        token.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, USER);

        uint256 assetsBack = vault.redeem(shares, USER, USER);
        vm.stopPrank();

        assertEq(assetsBack, 1000 ether);
    }

    function testYieldIncreasesWithdrawableAmount() public {
        token.mint(USER, 1000 ether);

        // USER deposits as the sole depositor
        vm.startPrank(USER);
        token.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, USER);
        vm.stopPrank();

        // Owner injects yield
        address owner = vault.owner();
        token.mint(owner, 100 ether);
        vm.startPrank(owner);
        token.approve(address(vault), 100 ether);
        vault.depositYield(100 ether);
        vm.stopPrank();

        // USER redeems all shares — should now be worth more than the original deposit
        vm.prank(USER);
        uint256 assetsBack = vault.redeem(shares, USER, USER);

        assertApproxEqAbs(assetsBack, 1100 ether, 1); // tolerance: 1 wei
    }
}
