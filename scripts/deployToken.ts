import {  ethers, run } from "hardhat";

import { AlvareNET, ProxyFunctions__factory, AlvareNET__factory } from "../typechain";

const networks : { [key: number] : { router: string, pairtoken : string }} = {
  56 : { 
    pairtoken : "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    router : "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  },
  97 : {
    pairtoken : "0x8301f2213c0eed49a7e28ae4c3e91722919b8b47",
    router : "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"
  }
}

async function main() {
  const { chainId } = await ethers.provider.getNetwork()
  const routeraddress = networks[chainId].router
  const pairtokenaddress = networks[chainId].pairtoken

  const signers = await ethers.getSigners();

  const AlvareNETfactory = (await ethers.getContractFactory("AlvareNET", signers[0])) as AlvareNET__factory;
  const AlvareNETinstance = await AlvareNETfactory.deploy();

  await AlvareNETinstance.deployed();

  console.log("AlvareNet deployed to:", AlvareNETinstance.address);

  const ProxyFactory = (await ethers.getContractFactory("ProxyFunctions", signers[0])) as ProxyFunctions__factory;
  const ProxyInstance = await ProxyFactory.deploy(AlvareNETinstance.address, routeraddress, pairtokenaddress);

  await ProxyInstance.deployed();

  console.log("ProxyInstance deployed to:", ProxyInstance.address);

  let pairaddess = await ProxyInstance.uniswapV2Pair();
  console.log("New pair is:", pairaddess)

  await AlvareNETinstance.setproxyContract(ProxyInstance.address);
  console.log("ProxyInstance now set in token contract!")

  console.log("Verifying contracts")
  
  console.log("Verifying Token contract!")
  await run("verify:verify", {
    address: AlvareNETinstance.address,
  })

  console.log("Verifying Proxy contract!")
  await run("verify:verify", {
    address: ProxyInstance.address,
    constructorArguments: [
      AlvareNETinstance.address,
      routeraddress,
      pairtokenaddress
    ]
  })

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
