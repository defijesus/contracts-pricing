// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DSTestPlus} from "lib/solmate/src/test/utils/DSTestPlus.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";
import {ERC721Discount} from "src/ERC721Discount/ERC721Discount.sol";
import {ProductDiscounts, DiscountType} from "src/ERC721Discount/structs/ProductDiscounts.sol";
import {NFTDiscountParams} from "src/ERC721Discount/structs/NFTDiscountParams.sol";
import {CurrencyParams} from "src/ERC721Discount/structs/CurrencyParams.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

address constant ETH = address(0);
address constant USDC = address(1);
uint256 constant slicerId = 0;
uint256 constant productId = 1;
address constant owner = address(0);
address constant buyer = address(10);
uint88 constant fixedDiscountOne = 100;
uint88 constant fixedDiscountTwo = 200;
uint88 constant percentDiscount = 1000; // 10%

contract ERC721DiscountTest is DSTestPlus {
    ERC721Discount erc721GatedDiscount;
    MockProductsModule productsModule;
    MockERC721 nftOne;
    MockERC721 nftTwo;
    MockERC721 nftThree;

    uint240 basePrice = 1000;
    uint256 quantity = 1;
    uint8 minNftQuantity = 1;

    function setUp() public {
        productsModule = new MockProductsModule();
        erc721GatedDiscount = new ERC721Discount(address(productsModule));

        nftOne = new MockERC721(
            "NFTOne",
            "NFT1"
        );
        nftOne.mint(buyer);

        nftTwo = new MockERC721(
            "NFTTwo",
            "NFT2"
        );

        nftThree = new MockERC721(
            "NFTThree",
            "NFT3"
        );
    }

    function createDiscount(NFTDiscountParams[] memory nftDiscountParams) internal {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](nftDiscountParams.length);

        for (uint256 i = 0; i < nftDiscountParams.length; i++) {
            discounts[i] = nftDiscountParams[i];
        }

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);
    }

    function testDeploy() public {
        assertTrue(address(erc721GatedDiscount) != address(0));
    }

    function testSetProductPrice__ETH() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountOne, minQuantity: minNftQuantity});

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);
    }

    function testSetProductPrice__ERC20() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountOne, minQuantity: minNftQuantity});

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(currencyPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(ethPrice == 0);
    }

    function testSetProductPrice__MultipleCurrencies() public {
        NFTDiscountParams[] memory discountsOne = new NFTDiscountParams[](1);
        NFTDiscountParams[] memory discountsTwo = new NFTDiscountParams[](1);
        CurrencyParams[] memory currenciesParams = new CurrencyParams[](2);

        /// set product price with additional custom inputs
        discountsOne[0] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountOne, minQuantity: minNftQuantity});

        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discountsOne);

        /// set product price with different discount for different currency
        discountsTwo[0] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountTwo, minQuantity: minNftQuantity});

        currenciesParams[1] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discountsTwo);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price for ETH
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);

        /// check product price for USDC
        (uint256 ethPrice2, uint256 usdcPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(ethPrice2 == 0);
        assertTrue(usdcPrice == (quantity * basePrice) - fixedDiscountTwo);
    }

    function testProductPrice__NotNFTOwner() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        /// set product price for NFT that is not owned by buyer
        discounts[0] =
            NFTDiscountParams({nft: address(nftTwo), discount: fixedDiscountOne, minQuantity: minNftQuantity});

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * basePrice);
        assertTrue(currencyPrice == 0);
    }

    function testProductPrice__MinQuantity() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        /// Buyer owns 1 NFT, but minQuantity is 2
        discounts[0] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountOne, minQuantity: minNftQuantity + 1});

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * basePrice);
        assertTrue(currencyPrice == 0);

        /// Buyer owns 2 NFTs, minQuantity is 2
        nftOne.mint(buyer);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testProductPrice__HigherDiscount() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](2);

        /// NFT 2 has higher discount, but buyer owns only NFT 1
        discounts[0] =
            NFTDiscountParams({nft: address(nftTwo), discount: fixedDiscountTwo, minQuantity: minNftQuantity});
        discounts[1] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountOne, minQuantity: minNftQuantity});

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);

        /// Buyer mints NFT 2
        nftTwo.mint(buyer);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testProductPrice__Relative() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        discounts[0] = NFTDiscountParams({nft: address(nftOne), discount: percentDiscount, minQuantity: minNftQuantity});

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        /// set product price with percentage discount
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Relative, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - (basePrice * percentDiscount) / 1e4));
        assertTrue(currencyPrice == 0);
    }

    function testProductPrice__MultipleBoughtQuantity() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        discounts[0] = NFTDiscountParams({nft: address(nftOne), discount: percentDiscount, minQuantity: minNftQuantity});

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        /// set product price with percentage discount
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Relative, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        // buy multiple products
        quantity = 6;

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - (basePrice * percentDiscount) / 1e4));
        assertTrue(currencyPrice == 0);
    }

    function testSetProductPrice__Edit() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        discounts[0] =
            NFTDiscountParams({nft: address(nftTwo), discount: fixedDiscountTwo, minQuantity: minNftQuantity});

        createDiscount(discounts);

        // mint NFT 2
        nftTwo.mint(buyer);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(currencyPrice == 0);

        NFTDiscountParams[] memory discountsTwo = new NFTDiscountParams[](2);

        /// edit product price, with more NFTs and first NFT has higher discount but buyer owns only the second
        discountsTwo[0] =
            NFTDiscountParams({nft: address(nftThree), discount: fixedDiscountOne + 10, minQuantity: minNftQuantity});

        discountsTwo[1] =
            NFTDiscountParams({nft: address(nftOne), discount: fixedDiscountOne, minQuantity: minNftQuantity});

        createDiscount(discountsTwo);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);
    }
}