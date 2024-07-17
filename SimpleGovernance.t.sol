// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/Selfie/SimpleGovernance.sol";
import "wallet-mining/DamnValuableTokenScreenshot.sol";

contract DummyContract {
    bool public functionCalled = false;

    function dummyFunction() external {
        functionCalled = true;
    }
}

contract SimpleGovernanceTest is Test {
    SimpleGovernance public governance;
    DamnValuableTokenSnapshot private token;
    address private owner;
    address private user;
    uint256 public TOKENS_IN_POOL = 1500000e18;
    
    function setUp() public {
    owner = address(this);
    user = address(0x1);
    
    token = new DamnValuableTokenSnapshot(TOKENS_IN_POOL);

    governance = new SimpleGovernance(address(token));
    token.transfer(user, TOKENS_IN_POOL / 2 + 1);//--> To ensure that user has enough votes 
    }
    function testGetActionDelay () public {
        assertEq(governance.getActionDelay(), 2 days);
    }
    function testGetGovernanceToken () public {
        assertEq(governance.getGovernanceToken(), address(token));
    }
    function testGetActionCounter() public {
        assertEq(governance.getActionCounter(), 1);
    }
    function testNotEnoughVotes () public {
        address poorUser = address(0x123);
        address target = address(0x999);
        uint128 value = 100;
        bytes memory data = abi.encodeWithSignature("someFunction()");
        //-->Taking a snapshot of that perticular token as we never took a snapShot we need to take one to run the code
        token.snapshot();
        vm.deal(poorUser, value);
        vm.startPrank(poorUser);
        vm.expectRevert(abi.encodeWithSelector(ISimpleGovernance.NotEnoughVotes.selector, poorUser));
        governance.queueAction(target, value, data);
        vm.stopPrank();
    }
    function testQueueAction() public {
        vm.startPrank(user);
        
        // Take a snapshot
        token.snapshot();
        
        DummyContract dummyContract = new DummyContract();
        address target = address(dummyContract);
        uint128 value = 1000000e18;
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        uint256 actionId = governance.queueAction(target, value, data);
        
        assertEq(actionId, 1);
        assertEq(governance.getActionCounter(), 2);
        
        SimpleGovernance.GovernanceAction memory action = governance.getAction(actionId);
        assertEq(action.target, target);
        assertEq(action.value, value);
        assertEq(action.data, data);
        assertEq(action.proposedAt, block.timestamp);
        assertEq(action.executedAt, 0);
        
        vm.stopPrank();
    }
    function testExecuteAction() public {
    vm.startPrank(user);
    token.snapshot();
    
    DummyContract dummyContract = new DummyContract();
    address target = address(dummyContract);
    uint128 value = 0;
    bytes memory data = abi.encodeWithSignature("dummyFunction()");

    uint256 actionId = governance.queueAction(target, value, data);

    vm.warp(block.timestamp + 2 days + 1);

    governance.executeAction(actionId);

    SimpleGovernance.GovernanceAction memory action = governance.getAction(actionId);
    assertEq(action.executedAt, block.timestamp);
    
    assertTrue(dummyContract.functionCalled(), "Dummy function was not called");
    
    vm.stopPrank();
    }
    function testCannotExecuteActionBeforeDelay() public {
        vm.startPrank(user);
        token.snapshot();
        
        address target = address(this);
        uint128 value = 0;
        bytes memory data = abi.encodeWithSignature("dummyFunction()");
        
        uint256 actionId = governance.queueAction(target, value, data);
        
        vm.warp(block.timestamp + 2 days - 1);
        
        vm.expectRevert(abi.encodeWithSelector(ISimpleGovernance.CannotExecute.selector, actionId));
        governance.executeAction(actionId);
        
        vm.stopPrank();
    }
}