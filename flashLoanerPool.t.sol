// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/the-rewarder/FlashLoanerPool.sol";
import "wallet-mining/DamnValuableToken.sol";

contract FlashLoanerPoolTest is Test {
    FlashLoanerPool public pool;
    DamnValuableToken public token;
    address public owner;
    uint256 constant loanAmount = 100 ether;
    uint256 constant POOL_INITIAL_BALANCE = 1000000 ether;

    function setUp() public {
        owner = address(this);
        token = new DamnValuableToken();
        pool = new FlashLoanerPool(address(token));

        // Transfer tokens to the pool
        token.transfer(address(pool), POOL_INITIAL_BALANCE);
        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
    }
     function testConstructor() public {
        pool = new FlashLoanerPool(address(token));
        
        // Check if the liquidityToken is correctly set
        assertEq(address(pool.liquidityToken()), address(token), "Liquidity token not set correctly");
    }
    function testFlashLoanCallerNotContract() public {
        
        address notContract = vm.addr(1);
        vm.startPrank(notContract);
        vm.expectRevert(FlashLoanerPool.CallerIsNotContract.selector);
        pool.flashLoan(loanAmount);
        vm.stopPrank();
    }

    function testFlashLoanSuccess() public {
        MockReceiver receiver = new MockReceiver(address(pool), address(token));
        receiver.executeFlashLoan(loanAmount, true);
        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
    }

    function testFlashLoanNotEnoughBalance() public {
        uint256 loanAmountLess = POOL_INITIAL_BALANCE + 1 ether;
        MockReceiver receiver = new MockReceiver(address(pool), address(token));
        vm.expectRevert(FlashLoanerPool.NotEnoughTokenBalance.selector);
        receiver.executeFlashLoan(loanAmountLess, true);
    }

    function testFlashLoanNotPaidBack() public {
        MockReceiver receiver = new MockReceiver(address(pool), address(token));
        vm.expectRevert(FlashLoanerPool.FlashLoanNotPaidBack.selector);
        receiver.executeFlashLoan(loanAmount, false);
    }
}

contract MockReceiver {
    FlashLoanerPool private pool;
    DamnValuableToken private token;
    bool private shouldPayBack;

    constructor(address _pool, address _token) {
        pool = FlashLoanerPool(_pool);
        token = DamnValuableToken(_token);
    }

    function executeFlashLoan(uint256 amount, bool _shouldPayBack) external {
        shouldPayBack = _shouldPayBack;
        pool.flashLoan(amount);
    }
    
    function receiveFlashLoan(uint256 amount) external {
        if (shouldPayBack) {
            token.transfer(address(pool), amount);
        }
    }
}
