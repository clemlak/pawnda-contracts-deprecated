/* solhint-disable function-max-lines, not-rely-on-time */

pragma solidity 0.5.13;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";


contract ERC20OrERC721Token {
    function transferFrom(address sender, address recipient, uint256 amount) public;
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
        uint256 debt;
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
            "Borrower is not the signer"
        );

        if (parties[1] != address(0)) {
            require(
                parties[1] == getSigner(
                    lenderSig,
                    parties,
                    collateralsContracts,
                    collateralsValues,
                    data
                ),
                "Lender is not the signer"
            );
        }

        address lender;

        if (parties[1] == address(0)) {
            lender = msg.sender;
        } else {
            lender = parties[1];
        }

        require(data[0] == nonces[parties[0]], "Wrong borrower nonce");

        require(data[1] == nonces[lender], "Wrong lender nonce");

        require(data[4] > now, "Loan deadline already reached");

        require(collateralsContracts.length == collateralsValues.length, "Collaterals do not match");

        for (uint256 i = 0; i < collateralsContracts.length; i += 1) {
            ERC20OrERC721Token token = ERC20OrERC721Token(collateralsContracts[i]);

            token.transferFrom(parties[0], address(this), collateralsValues[i]);
        }

        uint256 fees = SafeMath.div(
            SafeMath.mul(
                data[2],
                fee
            ),
            10000
        );

        ERC20 currency = ERC20(parties[2]);

        require(currency.transferFrom(lender, parties[0], SafeMath.sub(data[2], fees)), "7");

        require(currency.transferFrom(lender, address(this), fees), "8");

        pushLoan(
            [
                parties[0],
                lender,
                parties[2]
            ],
            collateralsContracts,
            collateralsValues,
            data
        );

        nonces[parties[0]] = SafeMath.add(nonces[parties[0]], 1);
        nonces[lender] = SafeMath.add(nonces[lender], 1);
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
            "Sender is not the borrower"
        );

        require(
            loans[loanId].deadline > now,
            "10"
        );

        require(
            amount <= loans[loanId].debt,
            "11"
        );

        ERC20 currency = ERC20(loans[loanId].currency);

        require(
            currency.transferFrom(loans[loanId].borrower, loans[loanId].lender, amount),
            "12"
        );

        loans[loanId].debt = SafeMath.sub(loans[loanId].debt, amount);
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

        require(
            loans[loanId].debt == 0,
            "14"
        );

        for (uint256 i = 0; i < loans[loanId].collateralsContracts.length; i += 1) {
            ERC20OrERC721Token token = ERC20OrERC721Token(loans[loanId].collateralsContracts[i]);

            token.transferFrom(address(this), loans[loanId].borrower, loans[loanId].collateralsValues[i]);

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
                lender: parties[1],
                collateralsContracts: collateralsContracts,
                collateralsValues: collateralsValues,
                currency: parties[2],
                amount: data[2],
                rate: data[3],
                deadline: data[4],
                debt: SafeMath.mul(data[2], data[3]) / 10000,
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
    ) public view returns (
        address
    ) {
        bytes32 hashedData = getHashedData(
            parties,
            collateralsContracts,
            collateralsValues,
            data
        );

        return recover(
            hashedData,
            signature
        );
    }

    function getHashedData(
        address[3] memory parties,
        address[] memory collateralsContracts,
        uint256[] memory collateralsValues,
        uint256[5] memory data
    ) public pure returns (
        bytes32
    ) {
        bytes32 typesHash = keccak256(abi.encodePacked(
            "address[] parties",
            "address[] collateralsContracts",
            "uint256[] collateralsValues",
            "uint256[] data"
        ));

        bytes32 valuesHash = keccak256(abi.encodePacked(
            parties,
            collateralsContracts,
            collateralsValues,
            data
        ));

        return keccak256(abi.encodePacked(typesHash, valuesHash));
    }

    function recover(
        bytes32 hashedData,
        bytes memory signature
    ) public pure returns (
        address
    ) {
        return ECDSA.recover(
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hashedData)
            ),
            signature
        );
    }
}
