// SPDX-License-Identifier: MIT
/*pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import {AccountingToken} from "../src/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../src/the-rewarder/FlashLoanerPool.sol";
import {RewardToken} from "../src/the-rewarder/RewardToken.sol";
import {TheRewarderPool} from "../src/the-rewarder/TheRewarderPool.sol";
import {DamnValuableToken} from "wallet-mining/DamnValuableToken.sol";

contract theRewarderTest is Test {
    uint256 constant TOKEN_IN_POOL = 1000000e18;
    uint256 constant USER_DEPOSIT = 25e18;
    DamnValuableToken public liquidityToken;
    RewardToken public rewardToken;
    AccountingToken public accountingToken;
    TheRewarderPool public rewarderPool;
    FlashLoanerPool public flashLoanPool;

    address public deployer = address(1);
    address public alice = address(2);
    address public bob = address(3);
    address public charlie = address(4);
    address public david = address(5);
    address public attacker = address(6);

    function setUp() public {
    console.log("Setting up the test...");
    
    vm.startPrank(deployer);
    liquidityToken = new DamnValuableToken();
    console.log("Total supply of liquidityToken:", liquidityToken.totalSupply());
    console.log("Deployer balance:", liquidityToken.balanceOf(deployer));
    
    rewarderPool = new TheRewarderPool(address(liquidityToken));
    flashLoanPool = new FlashLoanerPool(address(liquidityToken));
    rewardToken = RewardToken(rewarderPool.rewardToken());
    accountingToken = AccountingToken(rewarderPool.accountingToken());
    
    console.log("Transferring tokens to FlashLoanerPool...");
    liquidityToken.transfer(address(flashLoanPool), TOKEN_IN_POOL);
    console.log("FlashLoanerPool balance:", liquidityToken.balanceOf(address(flashLoanPool)));
    console.log("Deployer balance after FlashLoanerPool transfer:", liquidityToken.balanceOf(deployer));
    
    console.log("Transferring and depositing tokens for Alice...");
    liquidityToken.transfer(alice, USER_DEPOSIT);
    console.log("Alice balance after transfer:", liquidityToken.balanceOf(alice));
    vm.startPrank(alice);
    liquidityToken.approve(address(rewarderPool), USER_DEPOSIT);
    console.log("Alice allowance after approval:", liquidityToken.allowance(alice, address(rewarderPool)));
    rewarderPool.deposit(USER_DEPOSIT);
    console.log("Alice balance after deposit:", liquidityToken.balanceOf(alice));
    vm.stopPrank();
    
    console.log("Transferring and depositing tokens for Bob...");
    liquidityToken.transfer(bob, USER_DEPOSIT);
    console.log("Bob balance after transfer:", liquidityToken.balanceOf(bob));
    vm.startPrank(bob);
    liquidityToken.approve(address(rewarderPool), USER_DEPOSIT);
    console.log("Bob allowance after approval:", liquidityToken.allowance(bob, address(rewarderPool)));
    rewarderPool.deposit(USER_DEPOSIT);
    console.log("Bob balance after deposit:", liquidityToken.balanceOf(bob));
    vm.stopPrank();
    
    console.log("Transferring and depositing tokens for Charlie...");
    liquidityToken.transfer(charlie, USER_DEPOSIT);
    console.log("Charlie balance after transfer:", liquidityToken.balanceOf(charlie));
    vm.startPrank(charlie);
    liquidityToken.approve(address(rewarderPool), USER_DEPOSIT);
    console.log("Charlie allowance after approval:", liquidityToken.allowance(charlie, address(rewarderPool)));
    rewarderPool.deposit(USER_DEPOSIT);
    console.log("Charlie balance after deposit:", liquidityToken.balanceOf(charlie));
    vm.stopPrank();
    
    console.log("Transferring and depositing tokens for David...");
    liquidityToken.transfer(david, USER_DEPOSIT);
    console.log("David balance after transfer:", liquidityToken.balanceOf(david));
    vm.startPrank(david);
    liquidityToken.approve(address(rewarderPool), USER_DEPOSIT);
    console.log("David allowance after approval:", liquidityToken.allowance(david, address(rewarderPool)));
    rewarderPool.deposit(USER_DEPOSIT);
    console.log("David balance after deposit:", liquidityToken.balanceOf(david));
    vm.stopPrank();
    
    assertEq(accountingToken.totalSupply(), USER_DEPOSIT * 4);
    assertEq(rewardToken.totalSupply(), 0);

    vm.stopPrank();

    vm.warp(block.timestamp + 5 days);
    address[4] memory users = [alice, bob, charlie, david];
    for (uint256 i = 0; i < users.length; i++) {
        address user = users[i];
        vm.prank(user);
        rewarderPool.distributeRewards();
        assertGt(rewardToken.balanceOf(user), 0);
    }
    assertEq(rewarderPool.roundNumber(), 2);
    assertEq(liquidityToken.balanceOf(attacker), 0);

    console.log("Test setup complete.");
}
    function testConstructorRewarderPool() public {
        DamnValuableToken mockLiquidityToken = new DamnValuableToken();
        TheRewarderPool newRewarderPool = new TheRewarderPool(address(mockLiquidityToken));
        assertEq(address(newRewarderPool.liquidityToken()), address(mockLiquidityToken), "Liquidity token not set correctly");
        AccountingToken accountingToken = AccountingToken(newRewarderPool.accountingToken());
        assertTrue(address(accountingToken) != address(0), "Accounting token not created");
        RewardToken rewardToken = RewardToken(newRewarderPool.rewardToken());
        assertTrue(address(rewardToken) != address(0), "Reward token not created");
        assertEq(newRewarderPool.roundNumber(), 1, "Initial round number should be 1");
        assertTrue(newRewarderPool.lastRecordedSnapshotTimestamp() > 0, "Snapshot timestamp not set");
    }
}*/
