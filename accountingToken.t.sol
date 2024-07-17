// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/the-rewarder/AccountingToken.sol";

contract AccountingTokenTest is Test {
    AccountingToken public token;
    address public owner;
    address public alice;
    address public bob;
    uint256 public amount = 1000e18;

    uint256 constant MINTER_ROLE = 1;//-->1 << 0
    uint256 constant SNAPSHOT_ROLE = 2;//-->1 << 1
    uint256 constant BURNER_ROLE = 4;//-->1 << 2

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);
        
        token = new AccountingToken();
    }

    function testInitialState() public {
        assertEq(token.name(), "rToken");
        assertEq(token.symbol(), "rTKN");
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasAllRoles(owner, MINTER_ROLE | SNAPSHOT_ROLE | BURNER_ROLE));
    }

    function testMint() public {
        token.mint(alice, amount);
        token.mint(bob, amount);
        assertEq(token.balanceOf(alice), 1000e18);
        assertEq(token.balanceOf(bob), 1000e18);
        assertEq(token.totalSupply(), 2*1000e18);
    }

    function testBurn() public {
        token.mint(alice, 1000e18);
        token.burn(alice, 500e18);
        assertEq(token.balanceOf(alice), 500e18);
        assertEq(token.totalSupply(), 500e18);
    }

    function testBurnUnauthorized() public {
        token.mint(alice, 1000e18);
        vm.prank(alice);
        vm.expectRevert();
        token.burn(alice, 500e18);
    }

    function testSnapshot() public {
        token.mint(alice, 1000e18);
        uint256 snapshotId = token.snapshot();
        token.mint(alice, 500e18);
        assertEq(token.balanceOf(alice), 1500e18);
        assertEq(token.balanceOfAt(alice, snapshotId), 1000e18);
    }

    function testSnapshotUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.snapshot();
    }

    function testTransferNotImplemented() public {
        token.mint(alice, 1000e18);
        vm.prank(alice);
        vm.expectRevert(AccountingToken.NotImplemented.selector);
        token.transfer(bob, 500e18);
    }

    function testApproveNotImplemented() public {
        vm.prank(alice);
        vm.expectRevert(AccountingToken.NotImplemented.selector);
        token.approve(bob, 500e18);
    }

    function testGrantAndRevokeRoles() public {
        token.grantRoles(alice, MINTER_ROLE);
        assertTrue(token.hasAllRoles(alice, MINTER_ROLE));

        vm.prank(alice);
        token.mint(bob, 1000e18);
        assertEq(token.balanceOf(bob), 1000e18);

        token.revokeRoles(alice, MINTER_ROLE);
        assertFalse(token.hasAllRoles(alice, MINTER_ROLE));

        vm.prank(alice);
        vm.expectRevert();
        token.mint(bob, 1000e18);
    }
}