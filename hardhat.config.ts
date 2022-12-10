import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-ganache';

import dotenv from 'dotenv';

dotenv.config();

const INFURA_KEY = process.env.INFURA_KEY!;
const ALCHEMY_KEY = process.env.ALCHEMY_KEY!;
const METAMASK_DEV_PK = process.env.METAMASK_DEV_PK!;

const config: HardhatUserConfig = {
  solidity: '0.8.17',
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${INFURA_KEY}`
      }
    },
    goerli: {
      // url: `https://goerli.infura.io/v3/${INFURA_KEY}`
      url: `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [ METAMASK_DEV_PK ]
    }
  }
};

export default config;
