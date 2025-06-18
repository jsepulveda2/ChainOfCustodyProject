/* eslint-disable prefer-const */
/* global artifacts */

const CoC = artifacts.require("EvidenceChainOfCustody");
const ACToken = artifacts.require("EvidenceAccessControl");


module.exports = function (deployer, network, accounts) {
  // using coinbase account to deploy smart contract
  deployer.deploy(ACToken, accounts[0]).then(() => {
    return deployer.deploy(CoC, ACToken.address);
  })
}