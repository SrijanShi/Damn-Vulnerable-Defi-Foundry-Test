pragma solidity ^0.8.0;

import "src/naive-receiver/FlashLoanReceiver.sol";
import "lib/forge-std/src/Test.sol";
import "src/naive-receiver/NaiveReceiverLenderPool.sol";

contract naiveReceiver is Test{
    FlashLoanReceiver  receiver;
    NaiveReceiverLenderPool  pool;
    address constant ETH=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    function setUp() public {
    pool = new NaiveReceiverLenderPool();
    receiver = new FlashLoanReceiver(address(pool));
    vm.deal(address(pool), 1000 ether);
    vm.deal(address(receiver), 10 ether);
    }

    
    function testOnFlashLoanSuccess() public {
        uint256 amount = 5 ether;  
        uint256 fee = 1 ether;     
        uint256 initialPoolBalance = address(pool).balance;
        uint256 initialReceiverBalance = address(receiver).balance;

        assertEq(initialReceiverBalance, 10 ether, "Receiver should start with 10 ETH");
        vm.prank(address(pool));
        bytes32 result = receiver.onFlashLoan(address(receiver), ETH, amount, fee, "");
        uint256 finalPoolBalance = address(pool).balance;
        uint256 finalReceiverBalance = address(receiver).balance;
        assertEq(result, keccak256("ERC3156FlashBorrower.onFlashLoan"), "Incorrect return value");
        assertEq(finalPoolBalance, initialPoolBalance + amount + fee, "Pool balance should increase by amount + fee");
        assertEq(finalReceiverBalance, initialReceiverBalance - (amount + fee), "Receiver balance should decrease by amount + fee");
    }
    function testOnFlashLoanWrongCaller() public{
        uint256 amount = 5 ether;
        uint256 fee = 1 ether;

        vm.expectRevert(0x48f5c3ed);
        vm.prank(address(0x999));
        receiver.onFlashLoan(address(receiver), ETH, amount, fee, "");
    }
    function testOnFlashLoanToken() public {
        uint256 amount = 5 ether;
        uint256 fee = 1 ether;
        address notETH = address(0x123);
        vm.expectRevert(FlashLoanReceiver.UnsupportedCurrency.selector);
        vm.prank(address(pool));  // Simulate call from the pool
        receiver.onFlashLoan(address(receiver), notETH, amount, fee, "");
    }
    function testReceiveFunction() public {
        uint256 initialBalance = address(receiver).balance;
        uint256 amount = 1 ether;
        (bool success, ) = address(receiver).call{value: amount}("");
        assertTrue(success, "ETH transfer failed");
        assertEq(
            address(receiver).balance,
            initialBalance + amount,
            "Receiver balance did not increase correctly"
        );
}
    function testOnFlashLoanWithZeroAmount() public {
        uint256 amount = 0;
        uint256 fee = 1 ether;

        vm.prank(address(pool));
        bytes32 result = receiver.onFlashLoan(address(receiver), ETH, amount, fee, "");

        assertEq(result, keccak256("ERC3156FlashBorrower.onFlashLoan"), "Incorrect return value");
    }

    function testOnFlashLoanWithZeroFee() public {
        uint256 amount = 5 ether;
        uint256 fee = 0;

        vm.prank(address(pool));
        bytes32 result = receiver.onFlashLoan(address(receiver), ETH, amount, fee, "");

        assertEq(result, keccak256("ERC3156FlashBorrower.onFlashLoan"), "Incorrect return value");
    }
    function testMaxFlashLoan() public {
        uint256 maxFlashLoan = pool.maxFlashLoan(ETH);
        assertEq(maxFlashLoan, address(pool).balance);
    }
    function testMaxFlashLoanDifferentToken() public{
        address notToken = address(0x444);
        uint256 result = pool.maxFlashLoan(notToken);
        assertEq(result, 0);
    }
    function testFlashFeeDifferentToken() public {
        address newToken = address(0x444);
        uint256 fee = 1;
        vm.expectRevert(NaiveReceiverLenderPool.UnsupportedCurrency.selector);
        pool.flashFee(newToken, fee);
    }
    function testFlashFeeETHToken() public {
        uint256 fee = 1 ether;
        uint256 feeCalculated = pool.flashFee(ETH, fee);
        assertEq(feeCalculated, fee);
    }
    function testFlashLoan() public {
    uint256 amount = 5 ether;
    uint256 fee = 1 ether; 
    
    uint256 poolBalanceBefore = address(pool).balance;
    uint256 receiverBalanceBefore = address(receiver).balance;
    
    vm.prank(address(this)); // Set msg.sender to this contract
    bool success = pool.flashLoan(IERC3156FlashBorrower(address(receiver)), ETH, amount, ""
    );
    
    assertTrue(success, "Flash loan should succeed");
    assertEq(address(pool).balance, poolBalanceBefore + fee, "Pool balance should increase by fee");
    assertEq(address(receiver).balance, receiverBalanceBefore - fee, "Receiver balance should decrease by fee");
    assertEq(address(receiver).balance, 10 ether - fee, "Receiver should only lose the fee amount");
}
    function testFlashLoanDifferentToken() public {
        address newToken = address(0x444);
        uint256 amount = 5 ether;
        vm.expectRevert(NaiveReceiverLenderPool.UnsupportedCurrency.selector);
        pool.flashLoan(IERC3156FlashBorrower(receiver), newToken, amount, "");

    }
    function testFlashLoanCallback() public {
        uint256 amount = 5 ether;
        uint256 fee =  1 ether;
        vm.prank(address(pool));
        bytes32 result= receiver.onFlashLoan(address(receiver), ETH, amount, fee, "");
        assertEq(result, CALLBACK_SUCCESS);
        
    }
    function testFlashLoanCallbackFailed() public {
    // Create a failing receiver
    MockFailingReceiver failingReceiver = new MockFailingReceiver(true);
    
    // Fund the failing receiver with some ETH to pay fees
    vm.deal(address(failingReceiver), 10 ether);

    uint256 loanAmount = 5 ether;

    // Expect the CallbackFailed error
    vm.expectRevert(NaiveReceiverLenderPool.CallbackFailed.selector);

    // Attempt the flash loan
    pool.flashLoan(
        IERC3156FlashBorrower(address(failingReceiver)),
        ETH,
        loanAmount,
        ""
    );
    
}
    function testRepayFailed() public {
    uint256 borrowAmount = 10 ether;
    uint256 fee = 1 ether;
    
    // Create a new receiver that won't repay the loan
    NonRepayingReceiver nonRepayingReceiver = new NonRepayingReceiver(address(pool));
    vm.deal(address(nonRepayingReceiver), borrowAmount + fee);

    uint256 poolBalanceBefore = address(pool).balance;

    vm.prank(address(this));
    vm.expectRevert(NaiveReceiverLenderPool.RepayFailed.selector);
    pool.flashLoan(
        IERC3156FlashBorrower(address(nonRepayingReceiver)),
        ETH,
        borrowAmount,
        ""
    );

    // Ensure the pool's balance hasn't changed
    assertEq(address(pool).balance, poolBalanceBefore, "Pool balance should not change");
}

}
contract MockFailingReceiver is IERC3156FlashBorrower {
    bool public shouldFail;
    
    constructor(bool _shouldFail) {
        shouldFail = _shouldFail;
    }

    function onFlashLoan(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external override returns (bytes32) {
        if (shouldFail) {
            return bytes32(0); // Return wrong value
        }
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    receive() external payable {}
}
contract NonRepayingReceiver is IERC3156FlashBorrower {
    address public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function onFlashLoan(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external override returns (bytes32) {
        // Do not repay the loan
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    receive() external payable {}
}