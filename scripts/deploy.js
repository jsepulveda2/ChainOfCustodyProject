// scripts/deploy.js
async function main () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  // We get the contract to deploy
  const CoC = await ethers.getContractFactory('EvidenceChainOfCustody');
  console.log('Deploying EvidenceChainOfCustody...');
  const coc = await CoC.deploy(contractOwner.address);
  await coc.deployed();
  console.log('EvidenceChainOfCustody deployed to:', coc.address);

  const ACToken = await ethers.getContractFactory('EvidenceAccessControl');
  console.log('Deploying EvidenceAccessControl...');
  const ac = await ACToken.deploy(contractOwner.address);
  await ac.deployed();
  console.log('EvidenceAccessControl deployed to:', ac.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
