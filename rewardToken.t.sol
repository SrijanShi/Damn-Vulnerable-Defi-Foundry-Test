pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/the-rewarder/RewardToken.sol";

contract rewardTokenTest is Test {
    RewardToken public token;
    address public owner;
    address public alice;
    address public bob;

    uint256 constant MINTER_ROLE = 1 << 0;

    function setUp() public {
        owner = address(this);
        token = new RewardToken();
        alice = address(0x1);
        bob = address(0x2);
    }
    function testInitialState() public {
        assertEq(token.name(), "Reward Token");
        assertEq(token.symbol(), "RWT");
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasAllRoles(owner, MINTER_ROLE));
    }
    function testMint() public {
        token.mint(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.totalSupply(), 1000);
    }

}