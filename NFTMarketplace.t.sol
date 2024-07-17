// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/free-rider/FreeRiderNFTMarketplace.sol";
import "wallet-mining/DamnValuableNFT.sol";


contract NFTMarketplaceTest is Test {
    FreeRiderNFTMarketplace public marketplace;
   

    DamnValuableNFT public nft;
    address public owner;
    address public buyer;
    uint256 public constant INITIAL_NFT_SUPPLY = 6;
    uint256 public constant INITIAL_ETH_SUPPLY = 200 ether;
    
    function setUp() public {
        owner = makeAddr("owner");
        buyer = makeAddr("buyer");
        
        vm.deal(owner, INITIAL_ETH_SUPPLY);
        vm.deal(buyer, INITIAL_ETH_SUPPLY);

        vm.prank(owner);
        marketplace = new FreeRiderNFTMarketplace{value: 1 ether}(INITIAL_NFT_SUPPLY);
        nft = marketplace.token();
    }

    function testConstructor() public {
        assertEq(address(marketplace.token()), address(nft));
        assertEq(nft.balanceOf(owner), INITIAL_NFT_SUPPLY);
        assertEq(nft.owner(), address(0));
    }
    function testOfferMany() public {
        uint256[] memory tokenIds = new uint256[](6);
        uint256[] memory prices = new uint256[](6);
        for (uint256 i = 0; i < 6;) {
            tokenIds[i] = i;
            prices[i] = 15 ether;
            unchecked {
                i++;
            }
        }

        vm.startPrank(owner);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.offerMany(tokenIds, prices);
        vm.stopPrank();

        assertEq(marketplace.offersCount(), 6);
    }
    function testOfferManyInvalidInputs() public {
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory prices = new uint256[](2);

        vm.prank(owner);
        vm.expectRevert(FreeRiderNFTMarketplace.InvalidPricesAmount.selector);
        marketplace.offerMany(tokenIds, prices);

        tokenIds = new uint256[](0);
        prices = new uint256[](0);

        vm.prank(owner);
        vm.expectRevert(FreeRiderNFTMarketplace.InvalidTokensAmount.selector);
        marketplace.offerMany(tokenIds, prices);
    }

    function testOfferManyInvalidPrice() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        tokenIds[0] = 0;
        prices[0] = 0;

        vm.startPrank(owner);
        nft.setApprovalForAll(address(marketplace), true);
        vm.expectRevert(FreeRiderNFTMarketplace.InvalidPrice.selector);
        marketplace.offerMany(tokenIds, prices);
        vm.stopPrank();
    }

    function testOfferManyCallerNotOwner() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        tokenIds[0] = 0;
        prices[0] = 1 ether;

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(FreeRiderNFTMarketplace.CallerNotOwner.selector, 0));
        marketplace.offerMany(tokenIds, prices);
    }

    function testOfferManyInvalidApproval() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        tokenIds[0] = 0;
        prices[0] = 1 ether;

        vm.prank(owner);
        vm.expectRevert(FreeRiderNFTMarketplace.InvalidApproval.selector);
        marketplace.offerMany(tokenIds, prices);
    }

    function testBuyMany() public {
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory prices = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = i;
            prices[i] = 1 ether;
        }

        vm.startPrank(owner);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.offerMany(tokenIds, prices);
        vm.stopPrank();

        vm.prank(buyer);
        marketplace.buyMany{value: 3 ether}(tokenIds);

        assertEq(nft.balanceOf(buyer), 3);
        assertEq(marketplace.offersCount(), 0);
    }

    function testBuyManyInsufficientPayment() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        tokenIds[0] = 0;
        prices[0] = 1 ether;

        vm.startPrank(owner);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.offerMany(tokenIds, prices);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert(FreeRiderNFTMarketplace.InsufficientPayment.selector);
        marketplace.buyMany{value: 0.5 ether}(tokenIds);
    }

    function testBuyManyTokenNotOffered() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 999; // Non-existent token

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(FreeRiderNFTMarketplace.TokenNotOffered.selector, 999));
        marketplace.buyMany{value: 1 ether}(tokenIds);
    }

    receive() external payable {}
}

