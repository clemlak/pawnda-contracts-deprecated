/* eslint-env node, mocha */
/* global artifacts, contract, it, assert */

const Pawnda = artifacts.require('Pawnda');

let pawnda;

contract('Pawnda', (accounts) => {
  it('Should deploy an instance of the Pawnda contract', () => Pawnda.deployed()
    .then((instance) => {
      pawnda = instance;
    }));

  it('Should find the signer of the signature', () => pawnda.getSigner(
    '0x18eb94f603e016b21b710baa63c0c3ff021d5bc2448a2abbbab8d1464ea944f605b0e3b0c8967d2e6b2d69750d96e0f2473e94d9402bca92092acf3fa91d8c991c',
    '0xc1B6BFff024E52243Bb66953559c8FEA377d552c',
    '0',
    '0x92Cb2E864aefabf0c319aee79464e8aae70c95dD',
    '0',
    '0x653036dDd25CeB5Ecc2D933f27e33D95C23F1043',
    '42',
    '0x653036dDd25CeB5Ecc2D933f27e33D95C23F1043',
    '150',
    '1',
    '999',
  )
    .then((signer) => {
      assert.equal(signer, '0xc1B6BFff024E52243Bb66953559c8FEA377d552c', 'Signer is wrong');
    }));

  it('Should find the other signer of the signature', () => pawnda.getSigner(
    '0xd7f120e15a9905a963897f4c912c06f65465e40e006e10fb5365f0d39112cc666e19f38864654c00ff2b6fe98048d162c80ff43251993e806764b1faaf40f4ac1b',
    '0xc1B6BFff024E52243Bb66953559c8FEA377d552c',
    '0',
    '0x92Cb2E864aefabf0c319aee79464e8aae70c95dD',
    '0',
    '0x653036dDd25CeB5Ecc2D933f27e33D95C23F1043',
    '42',
    '0x653036dDd25CeB5Ecc2D933f27e33D95C23F1043',
    '150',
    '1',
    '999',
  )
    .then((signer) => {
      assert.equal(signer, '0x92Cb2E864aefabf0c319aee79464e8aae70c95dD', 'Signer is wrong');
    }));
});
