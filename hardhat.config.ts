import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-ganache';

import dotenv from 'dotenv';

dotenv.config();

const INFURA_KEY = process.env.INFURA_KEY!;
const ALCHEMY_MAIN_KEY = process.env.ALCHEMY_MAIN_KEY!;
const ALCHEMY_GOERLI_KEY = process.env.ALCHEMY_GOERLI_KEY;
const METAMASK_DEV_PK = process.env.METAMASK_DEV_PK!;

const config: HardhatUserConfig = {
  solidity: '0.8.17',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      chainId: 1,
      forking: {
        // url: `https://mainnet.infura.io/v3/${INFURA_KEY}`,
        url: `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_MAIN_KEY}`,
        blockNumber: 8111185 // set a block number from 10/12/22 so it doesnt have to fetch new data everytime
      }
    },
    goerli: {
      chainId: 5,
      // url: `https://goerli.infura.io/v3/${INFURA_KEY}`
      url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_GOERLI_KEY}`,
      accounts: [ METAMASK_DEV_PK ]
    }
  }
};

export default config;
