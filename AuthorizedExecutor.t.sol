// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/abi-smuggling/AuthorizedExecutor.sol";

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract ConcreteAuthorizedExecutor is AuthorizedExecutor {
    function _beforeFunctionCall(address target, bytes memory actionData) internal override {
        // For testing purposes, we'll leave this empty
    }
}

contract AuthorizedExecutorTest is Test {
    ConcreteAuthorizedExecutor executor;
    MockTarget target;
    address user = address(0x1);
    bytes4 selector = bytes4(keccak256("setValue(uint256)"));

    function setUp() public {
        executor = new ConcreteAuthorizedExecutor();
        target = new MockTarget();
    }

    function testSetPermissions() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = executor.getActionId(selector, user, address(target));

        vm.prank(user);
        executor.setPermissions(ids);

        assertTrue(executor.permissions(ids[0]));
        assertTrue(executor.initialized());
    }

    function testSetPermissionsAlreadyInitialized() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = executor.getActionId(selector, user, address(target));

        vm.prank(user);
        executor.setPermissions(ids);

        vm.expectRevert(AuthorizedExecutor.AlreadyInitialized.selector);
        executor.setPermissions(ids);
    }

    function testExecute() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = executor.getActionId(selector, user, address(target));

        vm.prank(user);
        executor.setPermissions(ids);

        bytes memory actionData = abi.encodeWithSelector(selector, 42);

        vm.prank(user);
        executor.execute(address(target), actionData);

        assertEq(target.value(), 42);
    }

    function testExecuteNotAllowed() public {
        bytes memory actionData = abi.encodeWithSelector(selector, 42);

        vm.expectRevert(AuthorizedExecutor.NotAllowed.selector);
        vm.prank(user);
        executor.execute(address(target), actionData);
    }

    function testGetActionId() public {
        bytes32 expectedId = keccak256(abi.encodePacked(selector, user, address(target)));
        bytes32 actualId = executor.getActionId(selector, user, address(target));

        assertEq(actualId, expectedId);
    }
}