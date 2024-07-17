pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/the-rewarder/TheRewarderPool.sol";
import "wallet-mining/DamnValuableToken.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
contract TheRewarderPoolTest is Test {
    using FixedPointMathLib for uint256;
    MockERC20 public liquidityToken;
    AccountingToken public accountingToken;
    RewardToken public rewardToken;
    TheRewarderPool public pool;

    address public alice = address(0x1);
    address public bob = address(0x2);

    uint128 public lastSnapshotIdForRewards;
    uint256 public constant INITIAL_LIQUIDITY = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 100 ether;
    uint256 public constant REWARDS = 100 ether;

    function setUp() public {

        liquidityToken = new MockERC20();
        pool = new TheRewarderPool(address(liquidityToken));
        rewardToken = pool.rewardToken();
        accountingToken = pool.accountingToken();

        liquidityToken.mint(alice, INITIAL_LIQUIDITY);
        liquidityToken.mint(bob, INITIAL_LIQUIDITY);
        //-->So that pool can take the tokens in alice and bob's address and send it to pool's balance
        vm.prank(alice);
        liquidityToken.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        liquidityToken.approve(address(pool), type(uint256).max);
    }
    function testConstructor() public {
        assertEq(address(pool.liquidityToken()), address(liquidityToken));
        assertEq(address(pool.accountingToken()), address(accountingToken));
        assertEq(address(pool.rewardToken()), address(rewardToken));
        assertEq(pool.roundNumber(), 1);
    }
    function testDeposit() public {
        vm.prank(alice);
        pool.deposit(DEPOSIT_AMOUNT);
        vm.prank(bob);
        pool.deposit(DEPOSIT_AMOUNT);

        assertEq(accountingToken.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(accountingToken.balanceOf(bob), DEPOSIT_AMOUNT);
        assertEq(liquidityToken.balanceOf(address(pool)), 2*DEPOSIT_AMOUNT);
    }
    function testDepositAmountZero() public {
        vm.prank(alice);
        vm.expectRevert(TheRewarderPool.InvalidDepositAmount.selector);
        pool.deposit(0);
    }
    function testWithdraw() public{
    vm.startPrank(alice);
    pool.deposit(DEPOSIT_AMOUNT);
     vm.startPrank(alice);
    pool.withdraw(DEPOSIT_AMOUNT);

    assertEq(accountingToken.balanceOf(alice), 0);
    assertEq(liquidityToken.balanceOf(alice), INITIAL_LIQUIDITY);
    }
    function testDistributeRewards() public {
        vm.prank(alice);
        pool.deposit(DEPOSIT_AMOUNT);

        // Fast forward 5 days
        vm.warp(block.timestamp + 5 days);

        vm.prank(alice);
        uint256 rewards = pool.distributeRewards();

        assertEq(rewards, REWARDS);
        assertEq(rewardToken.balanceOf(alice), REWARDS);
    }

    function testMultipleDepositsAndRewards() public {
    vm.prank(alice);
    pool.deposit(DEPOSIT_AMOUNT);

    vm.prank(bob);
    pool.deposit(DEPOSIT_AMOUNT * 2);
    vm.warp(block.timestamp + 5 days);
    vm.prank(alice);
    uint256 aliceRewards = pool.distributeRewards();

    vm.prank(bob);
    uint256 bobRewards = pool.distributeRewards();
    uint256 currentRoundNumber = pool.roundNumber();

    uint256 totalDeposits = accountingToken.totalSupplyAt(currentRoundNumber);
    uint256 amountDepositAlice = accountingToken.balanceOfAt(alice, currentRoundNumber);
    uint256 amountDepositBob = accountingToken.balanceOfAt(bob, currentRoundNumber);

    assertEq(aliceRewards, amountDepositAlice.mulDiv(REWARDS, totalDeposits));
    assertEq(bobRewards, amountDepositBob.mulDiv(REWARDS, totalDeposits));
    }
    
    function testNewRewardsRound() public {
        assertFalse(pool.isNewRewardsRound());

        // Fast forward 5 days
        vm.warp(block.timestamp + 5 days);

        assertTrue(pool.isNewRewardsRound());
    }

    function testCannotClaimRewardsTwiceInSameRound() public {
    vm.prank(alice);
    pool.deposit(DEPOSIT_AMOUNT);

    vm.warp(block.timestamp + 5 days);

    // Record Alice's initial reward token balance
    uint256 initialRewardBalance = rewardToken.balanceOf(alice);

    vm.prank(alice);
    uint256 rewards1 = pool.distributeRewards();

    // Record Alice's reward token balance after first claim
    uint256 balanceAfterFirstClaim = rewardToken.balanceOf(alice);

    vm.prank(alice);
    uint256 rewards2 = pool.distributeRewards();

    uint256 balanceAfterSecondClaim = rewardToken.balanceOf(alice);

    assertEq(rewards1, 100 ether, "First reward should be 100 ether");
    assertEq(rewards2, 100 ether, "Second call to distributeRewards still returns 100 ether");
    
    assertEq(balanceAfterFirstClaim - initialRewardBalance, 100 ether, "Alice should receive 100 ether rewards on first claim");
    assertEq(balanceAfterSecondClaim, balanceAfterFirstClaim, "Alice's balance should not change after second claim attempt");
    }
}