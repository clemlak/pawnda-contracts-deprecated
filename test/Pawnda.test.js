/* eslint-env node, mocha */
/* global artifacts, contract, assert */

const Pawnda = artifacts.require('Pawnda');
const DummyToken = artifacts.require('DummyToken');
const DummyNifties = artifacts.require('DummyNifties');

const {
  toWei,
  fromWei,
  soliditySha3,
  BN,
} = require('web3-utils');

const Accounts = require('web3-eth-accounts');

const acc = new Accounts('http://1270.0.0.1:8545');

const {
  constants,
  expectEvent,
} = require('@openzeppelin/test-helpers');

const {
  ZERO_ADDRESS,
} = constants;

async function setupContext(
  pawnda,
  dummyToken,
  dummyNifties,
  borrower,
  lender,
) {
  await dummyNifties.claimFreeNifty({
    from: borrower,
  });

  await dummyToken.claimFreeTokens(toWei('100'), {
    from: lender,
  });

  await dummyNifties.approve(pawnda.address, 0, {
    from: borrower,
  });

  await dummyToken.approve(pawnda.address, toWei('100'), {
    from: lender,
  });
}

contract('Pawnda', (accounts) => {
  let pawnda;
  let dummyToken;
  let dummyNifties;
  const borrower = accounts[1];
  const lender = accounts[2];
  const randomUser = accounts[3];

  describe('-> Good behaviors', async () => {
    beforeEach(async () => {
      dummyToken = await DummyToken.new();
      dummyNifties = await DummyNifties.new();
      pawnda = await Pawnda.new();
    });

    it('Should verify the signer', async () => {
      await setupContext(pawnda, dummyToken, dummyNifties, borrower, lender);

      const timeframe = 60 * 60 * 24 * 7;
      const deadline = Math.floor(Date.now() / 1000) + timeframe;

      const hashedData = await pawnda.getHashedData(
        [
          borrower,
          ZERO_ADDRESS,
          dummyToken.address,
        ],
        [
          dummyNifties.address,
        ],
        [
          '0',
        ],
        [
          '0',
          '0',
          toWei('100'),
          '10000',
          deadline,
        ],
      );

      const signedData = acc.sign(
        hashedData,
        '0xb8590d1d80f33d27ad26331a6126987d728897a0f92581c280236ffae1568c0e',
      );

      const signer = await pawnda.getSigner(
        signedData.signature,
        [
          borrower,
          ZERO_ADDRESS,
          dummyToken.address,
        ],
        [
          dummyNifties.address,
        ],
        [
          '0',
        ],
        [
          '0',
          '0',
          toWei('100'),
          '10000',
          deadline,
        ],
      );

      assert.equal(signer, borrower, 'Signer is not the borrower');
    });

    it('Should create a loan', async () => {
      await setupContext(pawnda, dummyToken, dummyNifties, borrower, lender);

      const timeframe = 60 * 60 * 24 * 7;
      const deadline = Math.floor(Date.now() / 1000) + timeframe;

      const loanAmount = toWei('100');
      const rate = '100';

      const hashedData = await pawnda.getHashedData(
        [
          borrower,
          ZERO_ADDRESS,
          dummyToken.address,
        ],
        [
          dummyNifties.address,
        ],
        [
          '0',
        ],
        [
          '0',
          '0',
          loanAmount,
          rate,
          deadline,
        ],
      );

      const signedData = acc.sign(
        hashedData,
        '0xb8590d1d80f33d27ad26331a6126987d728897a0f92581c280236ffae1568c0e',
      );

      const receipt = await pawnda.createLoan(
        [
          borrower,
          ZERO_ADDRESS,
          dummyToken.address,
        ],
        [
          dummyNifties.address,
        ],
        [
          '0',
        ],
        [
          '0',
          '0',
          loanAmount,
          rate,
          deadline,
        ],
        signedData.signature,
        '0x0000000000000000000000000000000000000000', {
          from: lender,
        },
      );

      expectEvent(receipt, 'LoanCreated', {
        loanId: '0',
        borrower,
        lender,
      });

      const loan = await pawnda.loans(0);
      const expectedDebt = new BN(loanAmount).mul(new BN(rate)).div(new BN('10000'));

      assert.equal(loan.borrower, borrower, 'Borrower is wrong');
      assert.equal(loan.lender, lender, 'Lender is wrong');
      assert.equal(loan.currency, dummyToken.address, 'Currency is wrong');
      assert.equal(loan.amount, toWei('100'), 'Amount is wrong');
      assert.isOk(loan.rate.eq(new BN(rate)), 'Rate is wrong');
      assert.isOk(loan.deadline.eq(new BN(deadline)), 'Deadline is wrong');
      assert.isOk(loan.debt.eq(expectedDebt), 'Debt is wrong');
      assert.isOk(loan.isOpen, 'Loan status is wrong');
    });

    it('Should create a loan and pay back a part of the debt', async () => {
      await setupContext(pawnda, dummyToken, dummyNifties, borrower, lender);

      const timeframe = 60 * 60 * 24 * 7;
      const deadline = Math.floor(Date.now() / 1000) + timeframe;

      const loanAmount = toWei('100');
      const rate = '100';

      const hashedData = await pawnda.getHashedData(
        [
          borrower,
          ZERO_ADDRESS,
          dummyToken.address,
        ],
        [
          dummyNifties.address,
        ],
        [
          '0',
        ],
        [
          '0',
          '0',
          loanAmount,
          rate,
          deadline,
        ],
      );

      const signedData = acc.sign(
        hashedData,
        '0xb8590d1d80f33d27ad26331a6126987d728897a0f92581c280236ffae1568c0e',
      );

      await pawnda.createLoan(
        [
          borrower,
          ZERO_ADDRESS,
          dummyToken.address,
        ],
        [
          dummyNifties.address,
        ],
        [
          '0',
        ],
        [
          '0',
          '0',
          loanAmount,
          rate,
          deadline,
        ],
        signedData.signature,
        '0x0000000000000000000000000000000000000000', {
          from: lender,
        },
      );

      const loan = await pawnda.loans(0);

      await dummyToken.claimFreeTokens(toWei('200'), {
        from: borrower,
      });

      await dummyToken.approve(pawnda.address, toWei('200'), {
        from: borrower,
      });

      await pawnda.payBackLoan(
        0,
        loan.debt.div(new BN(2)), {
          from: borrower,
        },
      );

      const updatedLoan = await pawnda.loans(0);

      const expectedDebt = loan.debt.div(new BN(2));

      assert.isOk(updatedLoan.debt.eq(expectedDebt), 'Debt is wrong');
    });
  });
});
