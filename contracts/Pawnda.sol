/* solhint-disable function-max-lines, not-rely-on-time */

pragma solidity 0.5.10;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @title A decentralized pawn shop (first implementation)
 * @dev This contract is the base of our project
 */
contract Pawnda is Ownable {
    mapping (address => uint256) public nonces;
    mapping (bytes => bool) public canceledPawnRequests;

    // Current fee charged by Pawnda (expressed in per ten thousand!)
    uint16 public fee = 10;

    // Delay (in days) requested to save a collateral from being stuck in the contract
    uint32 public saveCollateralDelay = 180;

    // Defines the structure of a pawn
    struct Pawn {
        address customer;
        address broker;
        address collateralAddress;
        uint256 collateralId;
        address currencyAddress;
        uint256 amount;
        uint16 rate;
        uint32 loanDeadline;
        uint256 reimbursedAmount;
        bool isOpen;
    }

    // Is emitted when a new pawn occurs
    event PawnCreated(
        uint256 pawnId,
        address indexed customer,
        address indexed broker
    );

    Pawn[] public pawns;

    /**
     * @dev Pawns a new collateral
     * @param customer The address of the customer
     * @param customerNonce The nonce of the customer
     * @param broker The address of the broker
     * @param brokerNonce The nonce of the broker
     * @param collateralAddress The address of the collateral
     * @param collateralId The id of the collateral
     * @param currencyAddress The address of the currency
     * @param amount The amount requested by the customer
     * @param rate The rate of the loan (expressed in per ten thousand!)
     * @param loanDeadline The deadline of the loan
     * @param customerSig The signature of the customer
     * @param brokerSig The signature of the broker
     */
    function pawnCollateral(
        address customer,
        uint256 customerNonce,
        address broker,
        uint256 brokerNonce,
        address collateralAddress,
        uint256 collateralId,
        address currencyAddress,
        uint256 amount,
        uint16 rate,
        uint32 loanDeadline,
        bytes calldata customerSig,
        bytes calldata brokerSig
    ) external {
        require(
            customer == getSigner(
                customerSig,
                customer,
                customerNonce,
                broker,
                brokerNonce,
                collateralAddress,
                collateralId,
                currencyAddress,
                amount,
                rate,
                loanDeadline
            ),
            "Customer is not the signer"
        );

        require(
            broker == getSigner(
                brokerSig,
                customer,
                customerNonce,
                broker,
                brokerNonce,
                collateralAddress,
                collateralId,
                currencyAddress,
                amount,
                rate,
                loanDeadline
            ),
            "Broker is not the signer"
        );

        ERC20 currency = ERC20(currencyAddress);
        ERC721 collateral = ERC721(collateralAddress);

        require(
            currency.allowance(broker, address(this)) >= amount,
            "Contract is not allowed to manipulate broker funds"
        );

        require(
            collateral.getApproved(collateralId) == address(this),
            "Contract is not allowed to manipulate customer collateral"
        );

        // Stores the collateral in the contract
        require(
            collateral.transferFrom(customer, address(this), collateralId),
            "Collateral transfer failed"
        );

        // Calculates the fee that needs to be charged
        uint256 fees = SafeMath.div(
            SafeMath.mul(
                amount,
                fee
            ),
            10000
        );

        require(
            currency.transferFrom(broker, customer, SafeMath.sub(amount, fees)),
            "Funds transfer to the customer failed"
        );

        require(
            currency.transferFrom(broker, address(this), fees),
            "Fees transfer failed"
        );

        uint256 pawnId = pawns.push(
            Pawn({
                customer: customer,
                broker: broker,
                collateralAddress: collateralAddress,
                collateralId: collateralId,
                currencyAddress: currencyAddress,
                amount: amount,
                rate: rate,
                loanDeadline: loanDeadline,
                isOpen: true
            })
        ) - 1;

        emit PawnCreated(pawnId, customer, broker);
    }

    /**
     * @dev Pays back a loan
     * @param pawnId The id of the pawn
     * @param amount The amount to pay back
     */
    function payBackLoan(
        uint256 pawnId,
        uint256 amount
    ) external {
        require(
            msg.sender == pawns[pawnId].customer,
            "Only the customer can pay back a loan"
        );

        require(
            pawns[pawnId].loanDeadline > now,
            "Deadline has been reached"
        );

        require(
            pawns[pawnId].isOpen,
            "Pawn is already closed"
        );

        // Calculates the amount the customer must reimburse
        uint256 expectedAmount = SafeMath.div(
            SafeMath.mul(
                pawns[pawnId].amount,
                pawns[pawnId].rate
            ),
            10000
        );

        require(
            SafeMath.add(pawns[pawnId].reimbursedAmount, amount) <= expectedAmount,
            "Too much funds were sent"
        );

        ERC20 currency = ERC20(pawns[pawnId].currencyAddress);

        require(
            currency.allowance(pawns[pawnId].customer, address(this)) >= amount,
            "Contract is not allowed to transfer customer funds"
        );

        require(
            currency.transferFrom(pawns[pawnId].customer, pawns[pawnId].broker, amount),
            "Funds could not be transferred"
        );

        pawns[pawnId].reimbursedAmount = SafeMath.add(pawns[pawnId].reimbursedAmount, amount);

        if (pawns[pawnId].reimbursedAmount == expectedAmount) {
            pawns[pawnId].isOpen = false;
        }
    }

    /**
     * @dev Gets a collateral back
     * @param pawnId The id of a specific pawn
     */
    function getCollateralBack(
        uint256 pawnId
    ) external {
        require(
            pawns[pawnId].isOpen == false,
            "Pawn is not closed"
        );

        ERC721 collateral = ERC721(pawns[pawnId].collateralAddress);

        require(
            collateral.ownerOf(pawns[pawnId].collateralId) == address(this),
            "Collateral has already been transferred"
        );

        require(
            collateral.transferFrom(address(this), customer, pawns[pawnId].collateralId),
            "Collateral transfer failed"
        );
    }

    /**
     * @dev Transfers the funds from the contract to the owner
     * @param currencyAddress The address of the contract of a specific currency
     * @param amount The amount to be transferred
     */
    function getFunds(
        address currencyAddress,
        uint256 amount
    ) external onlyOwner() {
        ERC20 currency = ERC20(currencyAddress);

        require(
            currency.transfer(owner(), amount),
            "Funds could not be transferred"
        );
    }

    /**
     * @dev Saves a collateral from being stuck in the contract if nobody asked for it after 180 days
     * @param pawnId The id of a specific pawn
     * @param collateralAddress The address of the contract of the collateral
     * @param collateralId The id of the collateral
     */
    function saveCollateral(
        uint256 pawnId,
        address collateralAddress,
        address collateralId
    ) external onlyOwner() {
        require(
            pawns[pawnId].isOpen == false,
            "Pawn has been closed"
        );

        require(
            now > pawns[pawnId].loanDeadline + saveCollateralDelay,
            "Collateral can not be saved yet"
        );

        ERC721 collateral = ERC721(collateralAddress);

        require(
            collateral.transfer(owner(), collateralId),
            "Collateral could not be transferred"
        );
    }

    function getSigner(
        bytes memory signature,
        address customer,
        uint256 customerNonce,
        address broker,
        uint256 brokerNonce,
        address collateralAddress,
        uint256 collateralId,
        address currencyAddress,
        uint256 amount,
        uint16 rate,
        uint32 loanDeadline
    ) public pure returns (
        address signer
    ) {
        bytes32 typeHash = keccak256(abi.encodePacked(
            "address customer",
            "uint256 customerNonce",
            "address broker",
            "uint256 brokerNonce",
            "address collateralAddress",
            "uint256 collateralId",
            "address currencyAddress",
            "uint256 amount",
            "uint16 rate",
            "uint32 loanDeadline"
        ));

        bytes32 valueHash = keccak256(abi.encodePacked(
            customer,
            customerNonce,
            broker,
            brokerNonce,
            collateralAddress,
            collateralId,
            currencyAddress,
            amount,
            rate,
            loanDeadline
        ));

        return recoverSigner(
            keccak256(abi.encodePacked(typeHash, valueHash)),
            signature
        );
    }

    function splitSignature(
        bytes memory signature
    ) private pure returns (
        uint8,
        bytes32,
        bytes32
    ) {
        require(signature.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) private pure returns (
        address signer
    ) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        (v, r, s) = splitSignature(signature);

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return address(0);
        } else {
            return ecrecover(hash, v, r, s);
        }
    }
}
