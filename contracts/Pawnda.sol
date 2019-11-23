/* solhint-disable function-max-lines, not-rely-on-time */

pragma solidity 0.5.13;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract ERC20OrERC721Token {
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
}


/**
 * @title Peer-to-peer lending backed by token-based collaterals
 * @notice This contract is the base of our project
 * @author clemlak https://github.com/clemlak
 */
contract Pawnda is Ownable {
    mapping (address => uint256) public nonces;

    // Current fee charged by Pawnda, expressed in per ten thousand
    // TODO: Add a function to update the fee
    uint256 public fee = 10;

    // Delay (in days) requested to save a collateral from being stuck in the contract
    // TODO: Add a function to update the delay
    uint256 public saveCollateralDelay = 180;

    struct Loan {
        address borrower;
        address lender;
        address[] collateralsContracts;
        uint256[] collateralsValues;
        address currency;
        uint256 amount;
        uint256 rate;
        uint256 deadline;
        uint256 reimbursed;
        bool isOpen;
    }

    event LoanCreated(
        uint256 loanId,
        address indexed borrower,
        address indexed lender
    );

    Loan[] public loans;

    /**
     * @notice Creates a new loan
     * @param parties An array of addresses: borrower, lender, currency
     * @param collateralsContracts An array of addresses for the collaterals
     * @param collateralsValues An array of values for the collaterals
     * @param data An array containing: borrowerNonce, lenderNonce, amount, rate, deadline
     * @param borrowerSig The signature of the borrower
     * @param lenderSig The signature of the lender
     */
    function createLoan(
        address[3] calldata parties,
        address[] calldata collateralsContracts,
        uint256[] calldata collateralsValues,
        uint256[5] calldata data,
        bytes calldata borrowerSig,
        bytes calldata lenderSig
    ) external {
        require(
            parties[0] == getSigner(
                borrowerSig,
                parties,
                collateralsContracts,
                collateralsValues,
                data
            ),
            "0"
        );

        require(
            parties[1] == getSigner(
                lenderSig,
                parties,
                collateralsContracts,
                collateralsValues,
                data
            ),
            "1"
        );

        require(
            data[0] == nonces[parties[0]], "2");

        require(data[1] == nonces[parties[1]], "3");

        require(data[4] > now, "4");

        require(collateralsContracts.length == collateralsValues.length, "5");

        for (uint256 i = 0; i < collateralsContracts.length; i += 1) {
            ERC20OrERC721Token token = ERC20OrERC721Token(collateralsContracts[i]);

            require(token.transferFrom(parties[0], address(this), collateralsValues[i]), "6");
        }

        uint256 fees = SafeMath.div(
            SafeMath.mul(
                data[2],
                fee
            ),
            10000
        );

        ERC20 currency = ERC20(parties[2]);

        require(currency.transferFrom(parties[1], parties[0], SafeMath.sub(data[2], fees)), "7");

        require(currency.transferFrom(parties[1], address(this), fees), "8");

        pushLoan(
            parties,
            collateralsContracts,
            collateralsValues,
            data
        );

        nonces[parties[0]] = SafeMath.add(nonces[parties[0]], 1);
        nonces[parties[1]] = SafeMath.add(nonces[parties[1]], 1);
    }

    /**
     * @notice Pays back a loan
     * @param loanId The id of the loan
     * @param amount The amount to pay back
     */
    function payBackLoan(
        uint256 loanId,
        uint256 amount
    ) external {
        require(
            msg.sender == loans[loanId].borrower,
            "9"
        );

        require(
            loans[loanId].deadline > now,
            "10"
        );

        // Calculates the amount the borrower must reimburse
        uint256 expectedAmount = SafeMath.div(
            SafeMath.mul(
                loans[loanId].amount,
                loans[loanId].rate
            ),
            10000
        );

        require(
            SafeMath.add(loans[loanId].reimbursed, amount) <= expectedAmount,
            "11"
        );

        ERC20 currency = ERC20(loans[loanId].currency);

        require(
            currency.transferFrom(loans[loanId].borrower, loans[loanId].lender, amount),
            "12"
        );

        loans[loanId].reimbursed = SafeMath.add(loans[loanId].reimbursed, amount);
    }

    /**
     * @notice Gets the collaterals back
     * @param loanId The id of a specific loan
     */
    function getCollateralsBack(
        uint256 loanId
    ) external {
        require(
            loans[loanId].isOpen == true,
            "13"
        );

        uint256 expectedAmount = SafeMath.div(
            SafeMath.mul(
                loans[loanId].amount,
                loans[loanId].rate
            ),
            10000
        );

        require(
            loans[loanId].reimbursed == expectedAmount,
            "14"
        );

        for (uint256 i = 0; i < loans[loanId].collateralsContracts.length; i += 1) {
            ERC20OrERC721Token token = ERC20OrERC721Token(loans[loanId].collateralsContracts[i]);

            require(
                token.transferFrom(address(this), loans[loanId].borrower, loans[loanId].collateralsValues[i]),
                "15"
            );
        }

        loans[loanId].isOpen = false;
    }

    /**
     * @notice Transfers the funds from the contract to the owner
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

    function pushLoan(
        address[3] memory parties,
        address[] memory collateralsContracts,
        uint256[] memory collateralsValues,
        uint256[5] memory data
    ) private {
        uint256 loanId = loans.push(
            Loan({
                borrower: parties[0],
                lender: parties[0],
                collateralsContracts: collateralsContracts,
                collateralsValues: collateralsValues,
                currency: parties[2],
                amount: data[2],
                rate: data[3],
                deadline: data[4],
                reimbursed: 0,
                isOpen: true
            })
        ) - 1;

        emit LoanCreated(loanId, parties[0], parties[1]);
    }

    function getSigner(
        bytes memory signature,
        address[3] memory parties,
        address[] memory collateralsContracts,
        uint256[] memory collateralsValues,
        uint256[5] memory data
    ) public pure returns (
        address signer
    ) {
        bytes32 typeHash = keccak256(abi.encodePacked(
            "address[] parties",
            "address[] collateralsContracts",
            "uint256[] collateralsValues",
            "uint256[] data"
        ));

        bytes32 valueHash = keccak256(abi.encodePacked(
            parties,
            collateralsContracts,
            collateralsValues,
            data
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
        require(signature.length == 65, "Wrong sig length");

        bytes32 r;
        bytes32 s;
        uint8 v;

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
