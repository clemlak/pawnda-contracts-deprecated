/* eslint-env node */
/* global artifacts */

const Pawnda = artifacts.require('Pawnda');
const DummyToken = artifacts.require('DummyToken');
const DummyNifties = artifacts.require('DummyNifties');

function deployContracts(deployer, network) {
  if (network === 'ropsten' || network === 'development') {
    deployer.deploy(Pawnda);
    deployer.deploy(DummyToken);
    deployer.deploy(DummyNifties);
  }
}

module.exports = deployContracts;
