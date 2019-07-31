/* eslint-env node, mocha */
/* global artifacts, contract, it, assert, web3 */

const Pawnda = artifacts.require('Pawnda');
const DummyToken = artifacts.require('DummyToken');
const DummyNifties = artifacts.require('DummyNifties');

const Web3 = require('web3');

const provider = new Web3('http://127.0.0.1:8545');

let pawnda;
let dummyToken;
let dummyNifties;

const data = [
  {
    type: 'address',
    name: 'customer',
    value: '0xc1B6BFff024E52243Bb66953559c8FEA377d552c',
  },
];

contract('Pawnda', (accounts) => {
  it('Should deploy an instance of the DummyToken contract', () => DummyToken.deployed()
    .then((instance) => {
      dummyToken = instance;
    }));

  it('Should deploy an instance of the DummyNifties contract', () => DummyNifties.deployed()
    .then((instance) => {
      dummyNifties = instance;
    }));

  it('Should deploy an instance of the Pawnda contract', () => Pawnda.deployed()
    .then((instance) => {
      pawnda = instance;
    }));

  it('Should claim a test NFT', () => dummyNifties.claimFreeNifty({
    from: accounts[0],
  }));

  it('Should check the owner of the NFT 0', () => dummyNifties.ownerOf(0)
    .then((owner) => {
      assert.equal(owner, accounts[0], 'Owner is wrong');
    }));

  it('Should claim test tokens', () => dummyToken.claimFreeTokens(web3.utils.toWei('1'), {
    from: accounts[1],
  }));

  it('Should check the balance of user 1', () => dummyToken.balanceOf(accounts[1])
    .then((balance) => {
      assert.equal(balance, web3.utils.toWei('1'), 'Account 1 balance is wrong');
    }));

  it('Should sign a pawn request', () => {
    provider.eth.accounts.wallet.add('0x4e99f11a187eab838e84957f3b6b7a6931baf9e253bcf661b0d6c070797299a6');

    return provider.currentProvider.send({
      method: 'eth_signTypedData',
      params: [data, '0xC6069235b8dFF9051Cc71a4D0802427Ed7730a2E'],
      from: '0xC6069235b8dFF9051Cc71a4D0802427Ed7730a2E',
    }, (error, result) => {
      if (error) {
        console.log(error);
      }

      console.log(result);
    });
  });
});
