// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/abi-smuggling/SelfAuthorizedVault.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract SelfAuthorizedVaultTest is Test {
    SelfAuthorizedVault vault;
    MockToken token;
    address user = address(0x1);
    uint256 WAITING_PERIOD = 15 days;

    function setUp() public {
        vault = new SelfAuthorizedVault();
        token = new MockToken();
        // Transfer all tokens to the vault
        token.transfer(address(vault), 1000000 ether);
    }

    function testWithdraw() public {
        vm.warp(block.timestamp + 15 days + 1);
        vm.prank(address(vault));
        vault.withdraw(address(token), user, 0.5 ether);
        assertEq(token.balanceOf(user), 0.5 ether);
    }

    function testWithdrawExceedingLimit() public {
        vm.prank(address(vault));
        vm.expectRevert(SelfAuthorizedVault.InvalidWithdrawalAmount.selector);
        vault.withdraw(address(token), user, 1.1 ether);
    }

    function testWithdrawBeforeWaitingPeriod() public {
    vm.warp(1000000);

    vm.warp(1000000 + WAITING_PERIOD + 1);

    vm.prank(address(vault));
    vault.withdraw(address(token), user, 0.5 ether);
    assertEq(token.balanceOf(user), 0.5 ether);

    vm.warp(1000000 + WAITING_PERIOD + 1 + WAITING_PERIOD - 1); // Just before the next waiting period ends
    vm.prank(address(vault));
    vm.expectRevert(SelfAuthorizedVault.WithdrawalWaitingPeriodNotEnded.selector);
    vault.withdraw(address(token), user, 0.5 ether);

    assertEq(token.balanceOf(user), 0.5 ether);
    }
    function testGetLastWithdrawalTimestamp() public {
    uint256 initialTimestamp = vault.getLastWithdrawalTimestamp();

    vm.warp(block.timestamp + 15 days + 1);

    vm.prank(address(vault));
    vault.withdraw(address(token), user, 0.5 ether);

    uint256 newTimestamp = vault.getLastWithdrawalTimestamp();
    assertEq(newTimestamp, block.timestamp);
    assertTrue(newTimestamp > initialTimestamp);
    }
    function testSweepFunds() public {
        vm.prank(address(vault));
        vault.sweepFunds(user, token);
        assertEq(token.balanceOf(user), 1000000 ether);
        assertEq(token.balanceOf(address(vault)), 0);
    }
    function testOnlyThisModifier() public {
        vm.prank(address(0x100));
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), user, 0.5 ether);

    }
    function testWithdrawFromOtherAddress() public {
    vm.warp(block.timestamp + WAITING_PERIOD + 1);
    
    // Try to call withdraw directly from another address
    vm.prank(address(0x123));
    vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
    vault.withdraw(address(token), user, 0.5 ether);
}
    
}