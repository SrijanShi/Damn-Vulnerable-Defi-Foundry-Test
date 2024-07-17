// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/Truster/TrusterLenderPool.sol";
import "wallet-mining/DamnValuableToken.sol";

contract MockReceiver {
    DamnValuableToken public token;
    address public pool;

    constructor(DamnValuableToken _token, address _pool) {
        token = _token;
        pool = _pool;
    }

    function executeFlashLoan(uint256 amount) external {
        // Transfer the borrowed amount back to the pool
        require(token.transfer(pool, amount), "Transfer back to pool failed");
    }
}


contract TrusterLenderPoolTest is Test {
    TrusterLenderPool public pool;
    DamnValuableToken public token;
    address public borrower;
    MockReceiver public receiver;
    uint256 public constant POOL_INITIAL_BALANCE = 1_000_000 ether;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        borrower = makeAddr("Borrower");
        receiver = new MockReceiver(token, address(pool));

        // Transfer initial tokens to the pool
        token.transfer(address(pool), POOL_INITIAL_BALANCE);

        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
    }

    function testFlashLoanSuccessful() public {
        uint256 borrowAmount = 100 ether;

        // Prepare the data to call executeFlashLoan on the receiver
        bytes memory data = abi.encodeWithSignature(
            "executeFlashLoan(uint256)",
            borrowAmount
        );

        vm.prank(borrower);
        bool success = pool.flashLoan(borrowAmount, address(receiver), address(receiver), data);

        assertTrue(success);
        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
        assertEq(token.balanceOf(address(receiver)), 0); // Ensure receiver has no tokens left
    }

    function testFlashLoanRepayFailed() public {
        uint256 borrowAmount = 100 ether;
        bytes memory data = abi.encodeWithSignature(
            "executeFlashLoan(uint256)"); // Empty data, so no repayment happens

        vm.expectRevert(TrusterLenderPool.RepayFailed.selector);
        vm.prank(borrower);
        pool.flashLoan(borrowAmount, address(borrower), address(borrower), data);
    }

    function testFlashLoanZeroAmount() public {
        uint256 borrowAmount = 0;
        bytes memory data = abi.encodeWithSignature(
            "executeFlashLoan(uint256)");

        vm.prank(borrower);
        bool success = pool.flashLoan(borrowAmount, address(receiver), address(receiver), data);

        assertTrue(success);
        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
    }
}