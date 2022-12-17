import { ethers, network } from "hardhat";
import { GelatoOpsSDK, GELATO_ADDRESSES, isGelatoOpsSupported } from "@gelatonetwork/ops-sdk";

const goerliDeploy = async (chainId: number) => {
  console.log('-----Fund Contract Tasks-----\n');
  const [ signer ] = await ethers.getSigners();
  const dcaFactory = await ethers.getContractFactory("SimpleDCATask");
  const dca = await dcaFactory.attach('0x156838ed2A1413B63fD334E1743Fd06195aA77B2');

  const tx = await dca.deposit({ value: ethers.utils.parseEther('0.04') });
  console.log('Transaction created: '+tx.hash);
  const fundTx = await tx.wait();
  console.log(`fund txHash: ${fundTx.transactionHash}`);
}

const main = async () => {
  const chainId = network.config.chainId as number;
  if (!isGelatoOpsSupported(chainId)) throw new Error(`Gelato Ops network not supported (${chainId})`);

  if (chainId === 1) {
    console.log('-----Mainnet-----')
    console.log('TODO');
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
