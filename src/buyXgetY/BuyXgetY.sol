// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { ISliceProductPrice } from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import { IProductsModule } from "../Slice/interfaces/IProductsModule.sol";


struct PriceParams {
    uint256 basePrice;
    uint256 buyX;
    uint256 getY;
}

contract BuyXGetYPrices is ISliceProductPrice {

  // Mapping from slicerId to productId to ProductParams
  mapping(uint256 => mapping(uint256 => PriceParams))
    private _productParams;

  address internal immutable _productsModuleAddress;

  constructor(address productsModuleAddress) {
    _productsModuleAddress = productsModuleAddress;
  }

  /// @notice Check if msg.sender is owner of a product. Used to manage access of `setProductPrice`
  /// in implementations of this contract.
  modifier onlyProductOwner(uint256 slicerId, uint256 productId) {
    require(
      IProductsModule(_productsModuleAddress).isProductOwner(
        slicerId,
        productId,
        msg.sender
      ),
      "NOT_PRODUCT_OWNER"
    );
    _;
  }

  /// @notice Set LinearProductParams for product.
  /// @param slicerId ID of the slicer to set the price params for.
  /// @param productId ID of the product to set the price params for.
  /// @param price price of each product.
  /// @param buy amount to buy to get discount.
  /// @param get amount to get when the buy amount is met.
  function setProductPrice(
    uint256 slicerId,
    uint256 productId,
    uint256 price,
    uint256 buy,
    uint256 get
  ) external onlyProductOwner(slicerId, productId) {
    require(get > buy);
    _productParams[slicerId][productId] = PriceParams({
      basePrice: price, 
      buyX: buy, 
      getY: get
    });
  }

  function productPrice(
    uint256 slicerId,
    uint256 productId,
    address currency,
    uint256 quantity,
    address buyer,
    bytes memory data
  ) external view returns (uint256 ethPrice, uint256 currencyPrice) {
    PriceParams memory params = _productParams[slicerId][productId];
    uint256 diff = params.getY - params.buyX;
    if (quantity == params.buyX) {
      if (currency != address(0)) {
        currencyPrice = (quantity + diff) * params.basePrice;
      } else {
        ethPrice = (quantity + diff) * params.basePrice;
      }
    } else {
      if (currency != address(0)) {
        currencyPrice = quantity * params.basePrice;
      } else {
        ethPrice = quantity * params.basePrice;
      }
    }
  }
}