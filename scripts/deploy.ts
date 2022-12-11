import { ethers, network } from "hardhat";
import { GelatoOpsSDK, GELATO_ADDRESSES, isGelatoOpsSupported } from "@gelatonetwork/ops-sdk";
import { TokenAddr } from "../interfaces";
import { getUSDCTokenPairs } from "./queries";
import { USDC_GOERLI_ADDRESS, USDC_MAINNET_ADDRESS, WBTC_GOERLI_ADDRESS, WETH_GOERLI_ADDRESS } from "../constants";

const mainnetDeploy = async (chainId: number) => {
  console.log('----- Fetching Tokens data -----\n');
  const { usdcFirst, usdcSecond } = await getUSDCTokenPairs();
  const uniqueSymbols = new Set<string>();
  const allowedSwapTokens: TokenAddr[] = [ { addr: USDC_MAINNET_ADDRESS, symbol: 'USDC'} ];

  [ ...usdcFirst, ...usdcSecond ].map((pool) =>{
    let tokenToAdd: TokenAddr = undefined!;
    if (pool.token0?.symbol.toLowerCase() === 'USDC'.toLowerCase()) {
      tokenToAdd = { symbol: pool.token1?.symbol!, addr: pool.token1?.id! };
    } else if (pool.token1?.symbol.toLowerCase() === 'USDC'.toLowerCase()) {
      tokenToAdd = { symbol: pool.token0?.symbol!, addr: pool.token0?.id! };
    }
    if (!uniqueSymbols.has(tokenToAdd?.symbol)) {
      allowedSwapTokens.push(tokenToAdd);
      uniqueSymbols.add(tokenToAdd?.symbol);
    } // else skip token
  });
  console.log('----- Tokens data Fetched-----\n');

  console.log('----- Deploying Contract -----\n');
  const [ signer ] = await ethers.getSigners();
  const gelatoOps = new GelatoOpsSDK(chainId, signer);
  const dcaFactory = await ethers.getContractFactory("SimpleDCATask");
  const dca = await dcaFactory.deploy(GELATO_ADDRESSES[chainId].ops, signer.address, allowedSwapTokens);
  
  await dca.deployed();
  console.log('----- Contract Deployed -----\n');
  console.log('Owner: ' + signer.address);
  console.log('Contract: ' + dca.address);
};

const goerliDeploy = async (chainId: number) => {
  const allowedSwapTokens: TokenAddr[] = [
    { symbol: 'USDC', addr: USDC_GOERLI_ADDRESS },
    { symbol: 'WETH', addr: WETH_GOERLI_ADDRESS },
    { symbol: 'WBTC', addr: WBTC_GOERLI_ADDRESS }
  ];
  console.log('----- Deploying Contract -----\n');
  const [ signer ] = await ethers.getSigners();
  const gelatoOps = new GelatoOpsSDK(chainId, signer);
  const dcaFactory = await ethers.getContractFactory("SimpleDCATask");
  const dca = await dcaFactory.deploy(GELATO_ADDRESSES[chainId].ops, signer.address, allowedSwapTokens);
  
  await dca.deployed();
  console.log('----- Contract Deployed -----\n');
  console.log('Owner: ' + signer.address);
  console.log('Contract: ' + dca.address);
}

const main = async () => {
  const chainId = network.config.chainId as number;
  if (!isGelatoOpsSupported(chainId)) throw new Error(`Gelato Ops network not supported (${chainId})`);

  if (chainId === 1) {
    console.log('-----Mainnet-----')
    await mainnetDeploy(chainId);
  } else if (chainId === 5) {
    console.log('-----Goerli-----')
    await goerliDeploy(chainId);
  } else {
    throw new Error('Contract is only supported in Goerli network');
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
