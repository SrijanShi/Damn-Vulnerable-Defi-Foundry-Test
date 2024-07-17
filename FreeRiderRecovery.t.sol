pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/free-rider/FreeRiderRecovery.sol";
import "node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract FreeRiderRecoveryTest is Test {
    uint256 constant PRIZE = 45 ether;
    FreeRiderRecovery public recovery;
    address public beneficiary;
    MockNFT public nft;

    function setUp() public {
        beneficiary = makeAddr("benificiaryAddress");
        nft = new MockNFT();
        //-->This is used to have a supply of PRIZE so that the test contract can make a new instant of recovery as it needs to have 45 ether to work
        vm.deal(address(this), PRIZE);
        recovery = new FreeRiderRecovery{value: PRIZE}(beneficiary, address(nft));
    }
    /*function testConstructorRevert() public {
    vm.expectRevert(abi.encodeWithSelector(FreeRiderRecovery.NotEnoughFunding.selector));
    new FreeRiderRecovery{value: 44 ether}(beneficiary, address(nft));
}*/


    function testOnERC721Received() public {
    // Mint 6 NFTs to the recovery contract
    for (uint256 i = 0; i < 6; i++) {
        nft.mint(address(recovery), i);
    }

    bytes memory data = abi.encode(beneficiary);

    // Simulate 6 NFT transfers
    for (uint256 i = 0; i < 6; i++) {
        // Set msg.sender to NFT contract and tx.origin to beneficiary
        vm.prank(address(nft), beneficiary);
        
        recovery.onERC721Received(address(0), address(0), i, data);
    }

    // Check that the prize has been paid out
    assertEq(address(recovery).balance, 0);
    assertEq(beneficiary.balance, PRIZE);
    }
    function testOnERC721ReceivedInvalidTokenID() public {
        vm.prank(address(nft), beneficiary);
        vm.expectRevert(abi.encodeWithSelector(FreeRiderRecovery.InvalidTokenID.selector, 6));
        recovery.onERC721Received(address(0), address(0), 6, "");
    }
    function testOnERC721NonBeneficiary() public {
        vm.prank(address(nft));
        vm.expectRevert(FreeRiderRecovery.OriginNotBeneficiary.selector);
        recovery.onERC721Received(address(0), address(0), 0, "");
    }
    function testOnERC721ReceivedCallerNotNFT() public {
        vm.expectRevert(FreeRiderRecovery.CallerNotNFT.selector);
        recovery.onERC721Received(address(0), address(0), 0, "");
    }
    function testOnERC721ReceivedStillNotOwningToken() public {
    nft.mint(address(this), 0);  

    bytes memory data = abi.encode(beneficiary);

    vm.prank(address(nft), beneficiary);

    vm.expectRevert(abi.encodeWithSelector(FreeRiderRecovery.StillNotOwningToken.selector, 0));
    recovery.onERC721Received(address(0), address(0), 0, data);

    assertEq(nft.ownerOf(0), address(this));
}
}