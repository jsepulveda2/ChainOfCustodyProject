require("@nomicfoundation/hardhat-toolbox");
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-truffle5');
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.10",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8546"
    },
    hardhat: {
      // See its defaults
    }
  }
};