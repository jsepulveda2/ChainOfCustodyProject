/* eslint-disable prefer-const */
/* global artifacts */

const CoC = artifacts.require("EvidenceChainOfCustody");
const ACToken = artifacts.require("EvidenceAccessControl");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(ACToken, accounts[0]);
  const acToken = await ACToken.deployed();

  await deployer.deploy(CoC, acToken.address);
  const coc = await CoC.deployed();

  // set the admin of AC Token to be the CoC contract
  await acToken.setAdmin(coc.address, { from: accounts[0] });
};