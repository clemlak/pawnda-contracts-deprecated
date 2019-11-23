/* eslint-env node, mocha */
/* global artifacts, contract, assert */

const Pawnda = artifacts.require('Pawnda');
const DummyToken = artifacts.require('DummyToken');
const DummyNifties = artifacts.require('DummyNifties');

const {
  toWei,
} = require('web3-utils');

const {
  constants,
} = require('@openzeppelin/test-helpers');

const {
  ZERO_ADDRESS,
} = constants;

const ethSigUtil = require('eth-sig-util');

function returnData(
  parties,
  collateralsContracts,
  collateralsValues,
  data,
) {
  return [
    {
      type: 'address[]',
      name: 'parties',
      value: parties,
    },
    {
      type: 'address[]',
      name: 'collateralsContracts',
      value: collateralsContracts,
    },
    {
      type: 'uint256[]',
      name: 'collateralsValues',
      value: collateralsValues,
    },
    {
      type: 'uint256[]',
      name: 'data',
      value: data,
    },
  ];
}

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

  beforeEach(async () => {
    dummyToken = await DummyToken.deployed();
    dummyNifties = await DummyNifties.deployed();
    pawnda = await Pawnda.deployed();
  });

  describe('-> Good behaviors', async () => {
    it('Should sign data as a borrower', async () => {
      await setupContext(pawnda, dummyToken, dummyNifties, borrower, lender);

      const timeframe = 60 * 60 * 24 * 7;
      const deadline = Math.floor(Date.now() / 1000) + timeframe;

      const data = returnData(
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
          '100',
          '10000',
          deadline,
        ],
      );

      const privateKeyBuffer = Buffer.from('fea9f43334b1bc9dd4181dfb017bc31c89a2c93432d5846195a396250266e082', 'hex');

      const borrowerSig = ethSigUtil.signTypedDataLegacy(privateKeyBuffer, {
        data,
      });

      console.log(borrowerSig);

      const signer = await pawnda.getSigner(
        borrowerSig,
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
          '100',
          '10000',
          deadline,
        ],
      );

      console.log(signer);

      assert.equal(signer, borrowerSig, 'Signer is not the borrower');
    });
  });
});
