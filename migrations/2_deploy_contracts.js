/* eslint-env node */
/* global artifacts */

const Pawnda = artifacts.require('Pawnda');

function deployContracts(deployer) {
  deployer.deploy(Pawnda);
}

module.exports = deployContracts;
