pragma solidity 0.5.10;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


/**
 * @title An amazing project called Pawnda
 * @dev This contract is the base of our project
 */
contract Pawnda {
    mapping (address => uint256) public nonces;
    mapping (bytes => bool) public canceledPawnRequests;

    struct Pawn {
        address customer;
        address broker;
        address collateralAddress;
        uint256 collateralId;
        address currencyAddress;
        uint256 amount;
        uint16 rate;
        uint32 loanDeadline;
        bool isClosed;
    }

    Pawn[] public pawns;

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
