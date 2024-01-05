// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct ASC20Order {
    address seller; // signer of the asc20 token seller
    address creator; // deployer of the asc20 token creator
    bytes32 listId;
    string ticker; 
    uint256 amount;
    uint256 price;
    uint256 nonce; // order nonce (must be unique unless new maker order is meant to override existing one e.g., lower ask price)
    uint64 listingTime; // startTime in timestamp
    uint64 expirationTime; // endTime in timestamp
    uint16 creatorFeeRate;
    uint32 salt; // 9-digit
    bytes extraParams; // additional parameters
    uint8 v; // v: parameter (27 or 28)
    bytes32 r; // r: parameter
    bytes32 s; // s: parameter
}

library OrderTypes {
    bytes32 internal constant ASC20_ORDER_HASH =
        keccak256(
            "ASC20Order(address seller,address creator,bytes32 listId,string ticker,uint256 amount,uint256 price,uint256 nonce,uint64 listingTime,uint64 expirationTime,uint16 creatorFeeRate,uint32 salt,bytes extraParams)"
        );

    function hash(ASC20Order memory order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ASC20_ORDER_HASH,
                    order.seller,
                    order.creator,
                    order.listId,
                    keccak256(bytes(order.ticker)),
                    order.amount,
                    order.price,
                    order.nonce,
                    order.listingTime,
                    order.expirationTime,
                    order.creatorFeeRate,
                    order.salt,
                    keccak256(order.extraParams)
                )
            );
    }
}