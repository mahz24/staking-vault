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

    uint256 constant YIELD_AMOUNT = 100 ether;

    address USER = makeAddr("user");
    address ATTACKER = makeAddr("attacker");
    address VICTIM = makeAddr("victim");

    function setUp() public {
        deployer = new DeployVault();
        (token, vault) = deployer.run();
    }

    function testInflationAttackDoesNotStealVictimFunds() public {

        // Give both actors tokens to work with
        token.mint(ATTACKER, 1);
        token.mint(VICTIM, 5000 ether);

        // Step 1: ATTACKER deposits the minimum amount (1 wei of token) as first depositor
        vm.startPrank(ATTACKER);
        token.approve(address(vault), 1);
        vault.deposit(1, ATTACKER);
        vm.stopPrank();

        // Step 2: ATTACKER donates a huge amount DIRECTLY to the vault, bypassing deposit()
        token.mint(ATTACKER, 10_000 ether);
        vm.prank(ATTACKER);
        token.transfer(address(vault), 10_000 ether);

        // Step 3: VICTIM deposits a reasonable amount
        vm.startPrank(VICTIM);
        token.approve(address(vault), 5000 ether);
        uint256 victimShares = vault.deposit(5000 ether, VICTIM);
        vm.stopPrank();

        // The VICTIM must receive a meaningful, non-zero amount of shares
        assertGt(victimShares, 0);

        // The VICTIM must be able to redeem back close to what they deposited
        // (allowing for reasonable rounding, not losing everything)
        vm.prank(VICTIM);
        uint256 assetsBack = vault.redeem(victimShares, VICTIM, VICTIM);

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

    function testOnlyOwnerCanMakeDepositYield() public {
        vm.prank(USER);
        vm.expectRevert();
        vault.depositYield(YIELD_AMOUNT);
    }

    function testFuzzVaultNeverOverpaysAgainstBackedAssets(
    uint256 depositAmount,
    uint256 yieldAmount
) public {
    depositAmount = bound(depositAmount, 1, 1_000_000 ether);
    yieldAmount = bound(yieldAmount, 0, 1_000_000 ether);

    address user = makeAddr("fuzzUser");
    token.mint(user, depositAmount);

    vm.startPrank(user);
    token.approve(address(vault), depositAmount);
    uint256 shares = vault.deposit(depositAmount, user);
    vm.stopPrank();

    address owner = vault.owner();
    if (yieldAmount > 0) {
        token.mint(owner, yieldAmount);
        vm.startPrank(owner);
        token.approve(address(vault), yieldAmount);
        vault.depositYield(yieldAmount);
        vm.stopPrank();
    }

    uint256 vaultBalanceBefore = token.balanceOf(address(vault));

    vm.prank(user);
    uint256 assetsBack = vault.redeem(shares, user, user);

    assertLe(assetsBack, vaultBalanceBefore);
}
}
