// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/backdoor/WalletRegistry.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "node_modules/@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "node_modules/@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

contract MockERC20 is ERC20 { 
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 100 ether);
    }
}

contract WalletRegistryTest is Test {
    WalletRegistry public registry;
    MockERC20 public token;
    GnosisSafe public masterCopy;
    GnosisSafeProxyFactory public walletFactory;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public david = address(0x4);

    function setUp() public {
        token = new MockERC20();
        masterCopy = new GnosisSafe();
        walletFactory = new GnosisSafeProxyFactory();

        address[] memory initialBeneficiaries = new address[](4);
        initialBeneficiaries[0] = alice;
        initialBeneficiaries[1] = bob;
        initialBeneficiaries[2] = charlie;
        initialBeneficiaries[3] = david;

        registry = new WalletRegistry(
            address(masterCopy),
            address(walletFactory),
            address(token),
            initialBeneficiaries
        );

        token.transfer(address(registry), 40 ether);
    }

    function testInitialSetUp() public {
        assertEq(registry.masterCopy(), address(masterCopy));
        assertEq(registry.walletFactory(), address(walletFactory));
        assertEq(address(registry.token()), address(token));

        assertTrue(registry.beneficiaries(alice));
        assertTrue(registry.beneficiaries(bob));
        assertTrue(registry.beneficiaries(charlie));
        assertTrue(registry.beneficiaries(david));

        assertEq(token.balanceOf(address(registry)), 40 ether);
    }

    function testAddBeneficiary() public {
        address newBeneficiary = makeAddr("newBeneficiary");
        vm.prank(registry.owner());
        registry.addBeneficiary(newBeneficiary);
        assertTrue(registry.beneficiaries(newBeneficiary));
    }

    function testFailAddBeneficiaryNonOwner() public {
        address newBeneficiary = makeAddr("newBeneficiary");
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        registry.addBeneficiary(newBeneficiary);
    }
    function testProxyCreated() public {
        //-->To have the initializer bytes we will find the following parameters and use them to encode the initializer:-
        //Genosis.setUp.selector
        //owners
        //threshold
        //to
        //data
        //fallbackHandler
        //paymentToken
        //payment
        //paymentReceiver
         // Setup wallet creation parameters for multiple owners
    // Create a new address for the owner
    address newOwner = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp)))));

    // Setup owners and threshold
    address[] memory owners = new address[](1);
    owners[0] = newOwner;
    uint256 threshold = 1;

    // Create and setup the GnosisSafe
    GnosisSafe safe = new GnosisSafe();
    
    try safe.setup(
        owners,
        threshold,
        address(0),
        bytes(""),
        address(0),
        address(0),
        0,
        payable(address(0))
    ) {
        // Setup successful
        emit log("GnosisSafe setup successful");
    } catch Error(string memory reason) {
        emit log(reason);
        revert("GnosisSafe setup failed");
    }

    // Prepare the initializer data
    bytes memory initializer = abi.encodeWithSelector(
        GnosisSafe.setup.selector,
        owners,
        threshold,
        address(0),
        bytes(""),
        address(0),
        address(0),
        0,
        payable(address(0))
    );

    // Transfer some tokens to the registry (if not already done in setUp)
    if (token.balanceOf(address(registry)) < 10 ether) {
        token.transfer(address(registry), 10 ether);
    }

    // Simulate the wallet factory calling proxyCreated on the registry
    vm.prank(address(walletFactory));
    registry.proxyCreated(GnosisSafeProxy(payable(address(safe))), address(masterCopy), initializer, 0);

    // Assertions
    assertEq(registry.wallets(newOwner), address(safe), "Safe should be registered for the new owner");
    assertFalse(registry.beneficiaries(newOwner), "New owner should not be a beneficiary");
    assertEq(token.balanceOf(address(safe)), 10 ether, "Safe should have received 10 tokens");

    // Additional checks
    assertEq(GnosisSafe(payable(address(safe))).getThreshold(), threshold, "Threshold should be set correctly");
    assertEq(GnosisSafe(payable(address(safe))).getOwners()[0], newOwner, "New address should be the owner of the safe");
}
    }
    


