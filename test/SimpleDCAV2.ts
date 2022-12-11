import { expect } from 'chai';
import { ethers } from 'hardhat';
import { USDC_MAINNET_ADDRESS, WBTC_MAINNET_ADDRESS, WETH9_MAINNET_ADDRESS } from '../constants';
import { SimpleDCAV2 } from '../typechain-types/contracts/SimpleDCAV2';

describe('SimpleDCAV2', () => {
  let contract: SimpleDCAV2;
  let contractFactory;

  const deployContract = async () => {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const tokens = [
      { symbol: 'USDC', addr: USDC_MAINNET_ADDRESS },
      { symbol: 'WETH', addr: WETH9_MAINNET_ADDRESS},
      { symbol: 'WBTC', addr: WBTC_MAINNET_ADDRESS }
    ];

    contractFactory = await ethers.getContractFactory('SimpleDCAV2');
    const deploy = await contractFactory.deploy(tokens);
    contract = await deploy.deployed();
  };

  // deploy contract only once
  before(async () => await deployContract());

  describe('Deployment', () => {
    it('should be deployed', () => {
      expect(contract).to.not.be.undefined;
    })

    it('should have setted token addresses', async () => {
      const usdc = await contract.tokenAddresses('USDC');
      expect(usdc).to.equal(USDC_MAINNET_ADDRESS);
      const wbtc = await contract.tokenAddresses('WBTC');
      expect(wbtc).to.equal(WBTC_MAINNET_ADDRESS);
      const weth = await contract.tokenAddresses('WETH');
      expect(weth).to.equal(WETH9_MAINNET_ADDRESS);
    });
  });

  xdescribe('Interactions - // TODO', () => {
    it('')
  })
});