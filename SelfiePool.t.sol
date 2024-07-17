// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/Selfie/SelfiePool.sol";
import "src/Selfie/SimpleGovernance.sol";
import "wallet-mining/DamnValuableTokenScreenshot.sol";

contract MockFlashLoanReceiver is IERC3156FlashBorrower {
    IERC20 public token;
    

    function onFlashLoan(address initiator, address _token, uint256 amount, uint256 fee, bytes calldata) external returns (bytes32) {
        // Approve the SelfiePool contract to transfer the borrowed amount + fee
        token = IERC20(_token);
        token.approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract SelfiePoolTest is Test {
    SelfiePool public selfiePool;
    SimpleGovernance public governance;
    DamnValuableTokenSnapshot public token;
    address public constant ATTACKER = address(0x1);
    uint256 public constant TOKENS_IN_POOL = 1_500_000e18;

    function setUp() public {
        token = new DamnValuableTokenSnapshot(TOKENS_IN_POOL);
        governance = new SimpleGovernance(address(token));
        selfiePool = new SelfiePool(address(token), address(governance));
        token.transfer(address(selfiePool), TOKENS_IN_POOL);
    }
    function testConstructor() public {
        assertEq(address(selfiePool.token()), address(token));
        assertEq(address(selfiePool.governance()), address(governance));
    }
    function testMaxFlashLoan() public {
        address notToken = address(0x1);
        assertEq(selfiePool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(selfiePool.maxFlashLoan(address(0x1234)), 0);
    }
    function testFlashFee() public {
        uint256 amount = 1000e18;
        assertEq(selfiePool.flashFee(address(token), amount), 0);
    }
    function testFlashFeeNotToken() public {
        address notToken = address(0x1);
        uint256 amount = 1000e18;
        vm.expectRevert(SelfiePool.UnsupportedCurrency.selector);
        assertEq(selfiePool.flashFee(address(notToken), amount), 0);
    }
    function testFlashLoan() public {
    MockFlashLoanReceiver receiver = new MockFlashLoanReceiver();
    uint256 borrowAmount = 1000e18;

    // Prank the ATTACKER to initiate the flash loan
    vm.prank(ATTACKER);
    bool success = selfiePool.flashLoan( receiver, address(token), borrowAmount, "");

    assertTrue(success);

    assertEq(token.balanceOf(address(selfiePool)), TOKENS_IN_POOL);
}

    function testFlashLoanWithUnsupportedCurrency() public {
        MockFlashLoanReceiver receiver = new MockFlashLoanReceiver();
        
        vm.expectRevert(abi.encodeWithSignature("UnsupportedCurrency()"));
        selfiePool.flashLoan(receiver, address(0x1234), 1000, "");
    }

    function testEmergencyExit() public {
        vm.prank(address(governance));
        selfiePool.emergencyExit(ATTACKER);

        assertEq(token.balanceOf(ATTACKER), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(selfiePool)), 0);
    }

    function testEmergencyExitNotGovernance() public {
        vm.expectRevert(abi.encodeWithSignature("CallerNotGovernance()"));
        selfiePool.emergencyExit(ATTACKER);
    }

}

