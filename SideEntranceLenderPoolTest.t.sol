// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/SideEntranceLenderPool/SideEntranceLenderPool.sol";

contract SideEntranceLenderPoolTest is Test {
    SideEntranceLenderPool public pool;
    address public constant user = address(0x1);
    address public constant attacker = address(0x2);

    uint256 public constant INITIAL_POOL_BALANCE = 1000 ether;
    uint256 public constant INITIAL_USER_BALANCE = 100 ether;
    uint256 public constant INITIAL_ATTACKER_BALANCE = 1 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;

    function setUp() public {
        pool = new SideEntranceLenderPool();
        vm.deal(address(pool), INITIAL_POOL_BALANCE);
        vm.deal(user, INITIAL_USER_BALANCE);
        vm.deal(attacker, INITIAL_ATTACKER_BALANCE);
    }

    function testDeposit() public {
        vm.startPrank(user);
        pool.deposit{value: DEPOSIT_AMOUNT}();
        vm.stopPrank();
        assertEq(address(pool).balance, INITIAL_POOL_BALANCE + DEPOSIT_AMOUNT, "Pool balance should increase by deposit amount");
        
    }

    function testWithdraw() public {
        vm.startPrank(user);
        pool.deposit{value: DEPOSIT_AMOUNT}();
        pool.withdraw();
        vm.stopPrank();

        assertEq(address(pool).balance, INITIAL_POOL_BALANCE, "Pool balance should return to initial balance after withdrawal");
        assertEq(user.balance, INITIAL_USER_BALANCE, "User balance should be back to initial amount after withdrawal");
    }

    function testFlashLoan() public {
        bool isMalicious = false;
        uint256 flashLoanAmount = 10 ether;
        normalAndMaliciousReceiver receiver = new normalAndMaliciousReceiver(address(pool), isMalicious);
        vm.prank(address(receiver));
        pool.flashLoan(flashLoanAmount);
        assertEq(address(pool).balance, INITIAL_POOL_BALANCE, "Pool balance should remain unchanged after flash loan");
        
    }
    function testFlashLoanRepayFailed() public {
        bool isMalicious = true;
        normalAndMaliciousReceiver Receiver = new normalAndMaliciousReceiver(address(pool), isMalicious);
        uint256 flashLoanAmount = 10 ether;
        vm.prank(address(Receiver));
        vm.expectRevert(SideEntranceLenderPool.RepayFailed.selector);
        pool.flashLoan(flashLoanAmount);
        assertEq(address(pool).balance, INITIAL_POOL_BALANCE, "Pool balance should remain unchanged after failed flash loan");
    }
}
contract normalAndMaliciousReceiver is IFlashLoanEtherReceiver{
    SideEntranceLenderPool private pool;
    bool private isMalicious;
    constructor (address _pool, bool _isMalicious){
        pool = SideEntranceLenderPool(_pool);
        isMalicious = _isMalicious;
    }
    function execute() external payable override {
        if (!isMalicious) {
            // Normal behavior: immediately deposit the borrowed funds back into the pool
            pool.deposit{value: msg.value}();
        } else {
            // Malicious behavior: do nothing, don't repay the loan
        }
    }
    receive() external payable{}
}