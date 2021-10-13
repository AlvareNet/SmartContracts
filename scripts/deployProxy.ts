import { ethers, run } from "hardhat";
import fetch from "node-fetch";

import { AlvareNet, ProxyFunctions__factory, AlvareNet__factory, MerkleDistributor, MerkleDistributor__factory, SAMARI, SAMARI__factory, SLOTHI, SLOTHI__factory } from "../typechain";

const samafactor = 70;

const networks: { [key: number]: { router: string, pairtoken: string, slth: string, sama: string, gnosis: string } } = {
  56: {
    pairtoken: "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    router: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    sama: "0xb255cddf7fbaf1cbcc57d16fe2eaffffdbf5a8be",
    slth: "0x5B9dbeBbad94b8C6467Af9e8A851Bb120F9601c6",
    gnosis: "0x6770E2C100280EdFf9B7D0A99e636b6fa06f3CBd"
  },
  97: {
    pairtoken: "0x8301f2213c0eed49a7e28ae4c3e91722919b8b47",
    router: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    slth: "",
    sama: "",
    gnosis: ""
  },
  1337: {
    pairtoken: "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    router: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    slth: "",
    sama: "",
    gnosis: ""
  }
}

async function main() {
    const settings = await (await fetch("https://raw.githubusercontent.com/AlvareNet/AirdropData/Final/output/settings.json")).json() as { merkleroot: string, slthtotal: string, samatotal: string }
    const { chainId } = await ethers.provider.getNetwork()
    console.log(chainId.toString());
    const signers = await ethers.getSigners();
    const AlvareAddress = "0x2488f8ce316cfaa9d9094c87fff02e4552ac2dbd";
    var proxyFactory = new ProxyFunctions__factory(signers[0])
    var ProxyInstance = await proxyFactory.deploy(AlvareAddress, "0x10ED43C718714eb63d5aA57B78B54704E256024E", "0xe9e7cea3dedca5984780bafc599bd69add087d56")
    await ProxyInstance.deployed()
    var startTime = 1633989600;
    await (await ProxyInstance.StartReleaseFee(startTime)).wait(5)
    if (chainId == 56 || chainId == 97) {
      console.log("Verifying contracts")
      console.log("Verifying MerkleDistributer contract!")
      await run("verify:verify", {
        address: ProxyInstance.address,
        constructorArguments: [
            AlvareAddress, "0x10ED43C718714eb63d5aA57B78B54704E256024E", "0xe9e7cea3dedca5984780bafc599bd69add087d56"
        ]
      })
    }
  }
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  
