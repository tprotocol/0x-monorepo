/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../../utils/LibBytes/LibBytes.sol";
import "./libs/LibMath.sol";
import "./libs/LibFillResults.sol";
import "./libs/LibOrder.sol";
import "./libs/LibExchangeErrors.sol";
import "./mixins/MMatchOrders.sol";
import "./mixins/MSettlement.sol";
import "./mixins/MAssetProxyDispatcher.sol";

contract MixinSettlement is
    LibBytes,
    LibMath,
    LibExchangeErrors,
    MMatchOrders,
    MSettlement,
    MAssetProxyDispatcher
{
    // ZRX metadata used for fee transfers.
    // This will be constant throughout the life of the Exchange contract,
    // since ZRX will always be transferred via the ERC20 AssetProxy.
    bytes internal ZRX_ASSET_DATA;

    /// @dev Gets the ZRX metadata used for fee transfers.
    function zrxAssetData()
        external
        view
        returns (bytes memory)
    {
        return ZRX_ASSET_DATA;
    }

    /// TODO: _zrxAssetData should be a constant in production.
    /// @dev Constructor sets the metadata that will be used for paying ZRX fees.
    /// @param _zrxAssetData Byte array containing ERC20 proxy id concatenated with address of ZRX.
    constructor (bytes memory _zrxAssetData)
        public
    {
        ZRX_ASSET_DATA = _zrxAssetData;
    }

    /// @dev Settles an order by transferring assets between counterparties.
    /// @param order Order struct containing order specifications.
    /// @param takerAddress Address selling takerAsset and buying makerAsset.
    /// @param fillResults Amounts to be filled and fees paid by maker and taker.
    function settleOrder(
        LibOrder.Order memory order,
        address takerAddress,
        LibFillResults.FillResults memory fillResults
    )
        internal
    {
        uint8 makerAssetProxyId = uint8(popByte(order.makerAssetData));
        uint8 takerAssetProxyId = uint8(popByte(order.takerAssetData));
        bytes memory zrxAssetData = ZRX_ASSET_DATA;
        uint8 zrxProxyId = uint8(popByte(zrxAssetData));
        dispatchTransferFrom(
            order.makerAssetData,
            makerAssetProxyId,
            order.makerAddress,
            takerAddress,
            fillResults.makerAssetFilledAmount
        );
        dispatchTransferFrom(
            order.takerAssetData,
            takerAssetProxyId,
            takerAddress,
            order.makerAddress,
            fillResults.takerAssetFilledAmount
        );
        dispatchTransferFrom(
            zrxAssetData,
            zrxProxyId,
            order.makerAddress,
            order.feeRecipientAddress,
            fillResults.makerFeePaid
        );
        dispatchTransferFrom(
            zrxAssetData,
            zrxProxyId,
            takerAddress,
            order.feeRecipientAddress,
            fillResults.takerFeePaid
        );
    }

    /// @dev Settles matched order by transferring appropriate funds between order makers, taker, and fee recipient.
    /// @param leftOrder First matched order.
    /// @param rightOrder Second matched order.
    /// @param takerAddress Address that matched the orders. The taker receives the spread between orders as profit.
    /// @param matchedFillResults Struct holding amounts to transfer between makers, taker, and fee recipients.
    function settleMatchedOrders(
        LibOrder.Order memory leftOrder,
        LibOrder.Order memory rightOrder,
        address takerAddress,
        LibFillResults.MatchedFillResults memory matchedFillResults
    )
        internal
    {
        uint8 leftMakerAssetProxyId = uint8(popByte(leftOrder.makerAssetData));
        uint8 rightMakerAssetProxyId = uint8(popByte(rightOrder.makerAssetData));
        bytes memory zrxAssetData = ZRX_ASSET_DATA;
        uint8 zrxProxyId = uint8(popByte(zrxAssetData));
        // Order makers and taker
        dispatchTransferFrom(
            leftOrder.makerAssetData,
            leftMakerAssetProxyId,
            leftOrder.makerAddress,
            rightOrder.makerAddress,
            matchedFillResults.right.takerAssetFilledAmount
        );
        dispatchTransferFrom(
            rightOrder.makerAssetData,
            rightMakerAssetProxyId,
            rightOrder.makerAddress,
            leftOrder.makerAddress,
            matchedFillResults.left.takerAssetFilledAmount
        );
        dispatchTransferFrom(
            leftOrder.makerAssetData,
            leftMakerAssetProxyId,
            leftOrder.makerAddress,
            takerAddress,
            matchedFillResults.leftMakerAssetSpreadAmount
        );

        // Maker fees
        dispatchTransferFrom(
            zrxAssetData,
            zrxProxyId,
            leftOrder.makerAddress,
            leftOrder.feeRecipientAddress,
            matchedFillResults.left.makerFeePaid
        );
        dispatchTransferFrom(
            zrxAssetData,
            zrxProxyId,
            rightOrder.makerAddress,
            rightOrder.feeRecipientAddress,
            matchedFillResults.right.makerFeePaid
        );

        // Taker fees
        if (leftOrder.feeRecipientAddress == rightOrder.feeRecipientAddress) {
            dispatchTransferFrom(
                zrxAssetData,
                zrxProxyId,
                takerAddress,
                leftOrder.feeRecipientAddress,
                safeAdd(
                    matchedFillResults.left.takerFeePaid,
                    matchedFillResults.right.takerFeePaid
                )
            );
        } else {
            dispatchTransferFrom(
                zrxAssetData,
                zrxProxyId,
                takerAddress,
                leftOrder.feeRecipientAddress,
                matchedFillResults.left.takerFeePaid
            );
            dispatchTransferFrom(
                zrxAssetData,
                zrxProxyId,
                takerAddress,
                rightOrder.feeRecipientAddress,
                matchedFillResults.right.takerFeePaid
            );
        }
    }
}
