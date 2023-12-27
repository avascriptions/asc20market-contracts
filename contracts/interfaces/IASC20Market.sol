// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ASC20Order } from "../lib/OrderTypes.sol";

interface IASC20Market {
    error MsgValueInvalid();
    error ETHTransferFailed();
    error OrderExpired();
    error NoncesInvalid();
    error SignerInvalid();
    error SignatureInvalid();
    error ExpiredSignature();
    error NoOrdersMatched();

   
    event NewTrustedVerifier(address trustedVerifier);
    event AllowBatchOrdersUpdate(bool allowBatchOrders);

    event avascriptions_protocol_TransferASC20Token(
        address indexed from,
        address indexed to,
        string indexed ticker,
        uint256 amount
    );

    event avascriptions_protocol_TransferASC20TokenForListing(
        address indexed from,
        address indexed to,
        bytes32 id
    );

    event ASC20OrderExecuted(address seller, address taker, bytes32 listId, string ticker, uint256 amount, uint256 price, uint16 feeRate, uint64 timestamp);
    event ASC20OrderCanceled(address seller,bytes32 listId,uint64 timestamp);

    function executeOrder(ASC20Order calldata order, address recipient) external payable;

    function batchMatchOrders(ASC20Order[] calldata orders, address recipient) external payable;

    function cancelOrder(ASC20Order calldata order) external;
    function cancelOrders(ASC20Order[] calldata orders) external;

}
