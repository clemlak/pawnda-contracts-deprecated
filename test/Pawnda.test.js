/* eslint-env node, mocha */
/* global artifacts, contract, it, assert, web3 */

const Pawnda = artifacts.require('Pawnda');
const DummyToken = artifacts.require('DummyToken');
const DummyNifties = artifacts.require('DummyNifties');

const ethSigUtil = require('eth-sig-util');

let pawnda;
let dummyToken;
let dummyNifties;

let customerSig;
let brokerSig;

const loanDeadline = Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7);

function returnData(
  customer,
  collateralAddress,
  collateralId,
  currencyAddress,
  amount,
  rate,
) {
  return [
    {
      type: 'address',
      name: 'customer',
      value: customer,
    },
    {
      type: 'uint256',
      name: 'customerNonce',
      value: '0',
    },
    {
      type: 'address',
      name: 'broker',
      value: '0x0000000000000000000000000000000000000000',
    },
    {
      type: 'uint256',
      name: 'brokerNonce',
      value: '0',
    },
    {
      type: 'address',
      name: 'collateralAddress',
      value: collateralAddress,
    },
    {
      type: 'uint256',
      name: 'collateralId',
      value: collateralId,
    },
    {
      type: 'address',
      name: 'currencyAddress',
      value: currencyAddress,
    },
    {
      type: 'uint256',
      name: 'amount',
      value: amount,
    },
    {
      type: 'uint16',
      name: 'rate',
      value: rate,
    },
    {
      type: 'uint32',
      name: 'loanDeadline',
      value: loanDeadline,
    },
  ];
}

contract('Pawnda', (accounts) => {
  it('Should deploy an instance of the DummyToken contract', async () => {
    dummyToken = await DummyToken.deployed();
  });

  it('Should deploy an instance of the DummyNifties contract', async () => {
    dummyNifties = await DummyNifties.deployed();
  });

  it('Should deploy an instance of the Pawnda contract', async () => {
    pawnda = await Pawnda.deployed();
  });

  it('Should claim a test NFT', () => dummyNifties.claimFreeNifty({
    from: accounts[0],
  }));

  it('Should check the owner of the NFT 0', async () => {
    const owner = await dummyNifties.ownerOf(0);
    assert.equal(owner, accounts[0], 'Owner is wrong');
  });

  it('Should claim test tokens', () => dummyToken.claimFreeTokens(web3.utils.toWei('1'), {
    from: accounts[1],
  }));

  it('Should check the balance of user 1', async () => {
    const balance = await dummyToken.balanceOf(accounts[1]);
    assert.equal(balance, web3.utils.toWei('1'), 'Account 1 balance is wrong');
  });

  it('Should allow Pawnda to manipulate user 0 assets', () => dummyNifties.approve(pawnda.address, 0));

  it('Should allow Pawnda to manipulate user 1 funds', () => dummyToken.approve(
    pawnda.address,
    web3.utils.toWei('1'), {
      from: accounts[1],
    },
  ));

  it('Should sign as a customer', async () => {
    const data = returnData(
      accounts[0],
      dummyNifties.address,
      0,
      dummyToken.address,
      web3.utils.toWei('1'),
      10000,
    );

    const privateKeyBuffer = Buffer.from('af796b2f306df60860de622218536391987e4a78d24d7aaf2c1faf5706539ce6', 'hex');
    customerSig = ethSigUtil.signTypedDataLegacy(privateKeyBuffer, {
      data,
    });

    assert.exists(customerSig, 'Sig does not exist');

    const signer = await pawnda.getSigner(
      customerSig,
      accounts[0],
      0,
      '0x0000000000000000000000000000000000000000',
      0,
      dummyNifties.address,
      0,
      dummyToken.address,
      web3.utils.toWei('1'),
      10000,
      loanDeadline,
    );

    assert.equal(signer, accounts[0], 'Signer is not the customer');
  });

  it('Should sign as a broker', async () => {
    const data = returnData(
      accounts[0],
      dummyNifties.address,
      0,
      dummyToken.address,
      web3.utils.toWei('1'),
      10000,
    );

    const privateKeyBuffer = Buffer.from('fea9f43334b1bc9dd4181dfb017bc31c89a2c93432d5846195a396250266e082', 'hex');
    brokerSig = ethSigUtil.signTypedDataLegacy(privateKeyBuffer, {
      data,
    });

    assert.exists(brokerSig, 'Sig does not exist');

    const signer = await pawnda.getSigner(
      brokerSig,
      accounts[0],
      0,
      '0x0000000000000000000000000000000000000000',
      0,
      dummyNifties.address,
      0,
      dummyToken.address,
      web3.utils.toWei('1'),
      10000,
      loanDeadline,
    );

    assert.equal(signer, accounts[1], 'Signer is not the broker');
  });

  it('Should pawn a collateral', () => pawnda.pawnCollateral(
    [
      accounts[0],
      '0x0000000000000000000000000000000000000000',
      dummyNifties.address,
      dummyToken.address,
    ],
    [
      0,
      0,
      0,
      web3.utils.toWei('1'),
      10000,
      loanDeadline,
    ],
    customerSig,
    brokerSig, {
      from: accounts[1],
    },
  ));

  it('Should get the due amount for pawn 0', async () => {
    const res = await pawnda.getDueAmount(0);
    const amount = web3.utils.toWei('1');
    const dueAmountWithFactor = web3.utils.toBN(amount).mul(web3.utils.toBN('10000'));
    const dueAmount = dueAmountWithFactor.div(web3.utils.toBN('10000'));

    assert.equal(res.toString(), dueAmount.toString(), 'Due amount is wrong');

    await dummyToken.claimFreeTokens(web3.utils.toWei('1.1'));
  });

  it('Should allow Pawnda to manipulate user 0 funds', () => dummyToken.approve(
    pawnda.address,
    web3.utils.toWei('1.1'),
  ));

  it('Should pay back pawn 0', async () => {
    const dueAmount = await pawnda.getDueAmount(0);
    await pawnda.payBackLoan(0, dueAmount.toString());
  });

  it('Should get pawn 0', async () => {
    const pawn = await pawnda.getPawn(0);

    assert.equal(pawn[0][0], accounts[0], 'Customer is wrong');
    assert.equal(pawn[0][1], accounts[1], 'Broker is wrong');
    assert.equal(pawn[0][2], dummyNifties.address, 'Collateral address is wrong');
    assert.equal(pawn[0][3], dummyToken.address, 'Currency address is wrong');
    assert.equal(pawn[1][0], 0, 'Collateral id is wrong');
    assert.equal(pawn[1][1].toString(), web3.utils.toWei('1'), 'Amount is wrong');
    assert.equal(pawn[1][2].toString(), 10000, 'Rate is wrong');
    assert.equal(pawn[1][3].toString(), loanDeadline, 'Loan deadline is wrong');
    // assert.equal(pawn[1][4].toString(), loanDeadline, 'Loan deadline is wrong');
    assert.equal(pawn.isOpen, true, 'isOpen is wrong');
  });
});
