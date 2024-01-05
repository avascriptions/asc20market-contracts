// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IASC20Market.sol";
import { OrderTypes, ASC20Order } from "./lib/OrderTypes.sol";

contract ASC20Market is
    IASC20Market,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using OrderTypes for ASC20Order;

    /// @dev Suggested gas stipend for contract receiving ETH that disallows any storage writes.
    uint256 internal constant _GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    mapping(address => uint256) public userNonces; // unused
    mapping(bytes32 => bool) private cancelledOrFilled;
    address private trustedVerifier;
    bool private allowCancelAll; // unused
    bool private allowBatch;

    function initialize() public initializer {
        __EIP712_init("ASC20Market", "1.0");
        __Ownable_init();
        __ReentrancyGuard_init();

        // default owner
        trustedVerifier = owner();
        allowBatch = false;
    }

    fallback() external {}

    receive() external payable {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function pause() public onlyOwner {
        PausableUpgradeable._pause();
    }

    function unpause() public onlyOwner {
        PausableUpgradeable._unpause();
    }

    function updateTrustedVerifier(address _trustedVerifier) external onlyOwner {
        trustedVerifier = _trustedVerifier;
        emit NewTrustedVerifier(_trustedVerifier);
    }

    function updateAllowBatch(bool _allowBatch) external onlyOwner {
        allowBatch = _allowBatch;
        emit AllowBatchOrdersUpdate(_allowBatch);
    }

    function batchMatchOrders(ASC20Order[] calldata orders, address recipient) public payable nonReentrant whenNotPaused {
        require(allowBatch, "Batch operation is not allowed");
        require(orders.length <= 20, "Too much orders");
        uint16 matched = 0; 
        uint256 userBalance = msg.value;
        for (uint i=0; i<orders.length; i++) {
            ASC20Order calldata order = orders[i];

            // Verify whether order availability
            bytes32 verifyHash = keccak256(abi.encodePacked(order.seller, order.listId));
            if (cancelledOrFilled[verifyHash] || order.nonce != userNonces[order.seller]) {
                // Don't throw error
                continue;
            }

            // Verify the order
            _verifyOrder(order, true);

            
            uint256 orderAmount = order.price * order.amount;
            require(userBalance >= orderAmount, "Insufficient balance");
            userBalance -= orderAmount;

            // Execute the transaction
            _executeOrder(order, recipient, verifyHash, orderAmount);

            matched++;
        }

        if (matched == 0) {
            revert NoOrdersMatched();
        }

        // refund balance
        if (userBalance > 0) {
            _transferETHWithGasLimit(msg.sender, userBalance, _GAS_STIPEND_NO_STORAGE_WRITES);
        }
    }

    function executeOrder(ASC20Order calldata order, address recipient) public payable override nonReentrant whenNotPaused {
        // Check the maker ask order
        bytes32 verifyHash = _verifyOrderHash(order, true);

        // Execute the transaction
        _executeOrder(order, recipient, verifyHash, msg.value);
    }

    function cancelOrder(ASC20Order calldata order) public override nonReentrant whenNotPaused {
        // Check the maker ask order
        bytes32 verifyHash = _verifyOrderHash(order, false);

        // Execute the transaction
        _cancelOrder(order, verifyHash);
    }

    /**
     * @dev Cancel multiple orders
     * @param orders Orders to cancel
     */
    function cancelOrders(ASC20Order[] calldata orders) external override nonReentrant whenNotPaused {
        for (uint8 i = 0; i < orders.length; i++) {
            bytes32 verifyHash = _verifyOrderHash(orders[i], false);
            _cancelOrder(orders[i], verifyHash);
        }
    }

    /**
     * @notice Verify the validity of the asc20 token order
     * @param order maker asc20 token order
     */
    function _verifyOrderHash(ASC20Order calldata order, bool verifySeller) internal view returns (bytes32) {



        // Verify whether order availability
        bytes32 verifyHash = keccak256(abi.encodePacked(order.seller, order.listId));
        if (cancelledOrFilled[verifyHash] || order.nonce != userNonces[order.seller]) {
            revert NoncesInvalid();
        }

        _verifyOrder(order, verifySeller);


        return verifyHash;
    }

     /**
     * @notice Verify the validity of the asc20 token order
     * @param order maker asc20 token order
     */
    function _verifyOrder(ASC20Order calldata order, bool verifySeller) internal view  {
        // Verify the signer is not address(0)
        if (order.seller == address(0)) {
            revert SignerInvalid();
        }
        // Verify the validity of the signature
        bytes32 orderHash = order.hash();
        address singer = verifySeller ? order.seller : trustedVerifier;
        bool isValid = _verify(
            orderHash,
            singer,
            order.v,
            order.r,
            order.s,
            _domainSeparatorV4()
        );
        
        if (!isValid) {
            revert SignatureInvalid();
        }
    }

    function _executeOrder(ASC20Order calldata order, address recipient, bytes32 verifyHash, uint256 userBalance) internal {
        uint256 toBePaid = order.price * order.amount;
        if (toBePaid != userBalance) {
            revert MsgValueInvalid();
        }

        // Verify the recipient is not address(0)
        require(recipient != address(0), "invalid recipient");

        // Verify whether order has expired
        if ((order.listingTime > block.timestamp) || (order.expirationTime < block.timestamp) ) {
            revert OrderExpired();
        }

        // Update order status to true (prevents replay)
        cancelledOrFilled[verifyHash] = true;

        // Pay eths
        _transferEths(order);

        emit avascriptions_protocol_TransferASC20TokenForListing(order.seller, recipient, order.listId);

        emit ASC20OrderExecuted(
            order.seller,
            recipient,
            order.listId,
            order.ticker,
            order.amount,
            order.price,
            order.creatorFeeRate,
            uint64(block.timestamp)
        );
    }

    function _cancelOrder(ASC20Order calldata order, bytes32 verifyHash) internal {
        if (order.expirationTime < block.timestamp) {
            revert ExpiredSignature();
        }

        // Update order status to true (prevents replay)
        cancelledOrFilled[verifyHash] = true;

        emit avascriptions_protocol_TransferASC20TokenForListing(order.seller, order.seller, order.listId);

        emit ASC20OrderCanceled(order.seller, order.listId, uint64(block.timestamp));
    }

    function _transferEths(ASC20Order calldata order) internal {
        uint256 finalSellerAmount = order.price * order.amount;

        // Pay protocol fee
        if (order.creatorFeeRate >= 0) {
            uint256 protocolFeeAmount = finalSellerAmount * order.creatorFeeRate / 10000;
            finalSellerAmount -= protocolFeeAmount;
            if (order.creator != address(this)) {
                _transferETHWithGasLimit(order.creator, protocolFeeAmount, _GAS_STIPEND_NO_STORAGE_WRITES);
            }
        }

        _transferETHWithGasLimit(order.seller, finalSellerAmount, _GAS_STIPEND_NO_STORAGE_WRITES);
    }

    /**
     * @notice It transfers ETH to a recipient with a specified gas limit.
     * @param to Recipient address
     * @param amount Amount to transfer
     * @param gasLimit Gas limit to perform the ETH transfer
     */
    function _transferETHWithGasLimit(address to, uint256 amount, uint256 gasLimit) internal {
        bool success;
        assembly {
            success := call(gasLimit, to, amount, 0, 0, 0, 0)
        }
        if (!success) {
            revert ETHTransferFailed();
        }
    }

    function _verify(bytes32 orderHash, address signer, uint8 v, bytes32 r, bytes32 s, bytes32 domainSeparator) internal pure returns (bool) {
        require(v == 27 || v == 28, "Invalid v parameter");
        // is need Bulk?
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, orderHash));

        address recoveredSigner = ecrecover(digest, v, r, s);
        if (recoveredSigner == address(0)) {
            return false;
        } else {
            return signer == recoveredSigner;
        }
    }

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        Address.sendValue(to, amount);
    }

    function withdrawUnexpectedERC20(address token, address to, uint256 amount) external onlyOwner {
        IERC20Upgradeable(token).safeTransfer(to, amount);
    }


}