import { ethers, run } from "hardhat";
import fetch from "node-fetch";

import { AlvareNet, ProxyFunctions__factory, AlvareNet__factory, MerkleDistributor, MerkleDistributor__factory, SAMARI, SAMARI__factory, SLOTHI, SLOTHI__factory } from "../typechain";

const settingsLink = "https://raw.githubusercontent.com/AlvareNet/AirdropData/Dualcontract/output/settings.json"
const samafactor = 70;

const networks: { [key: number]: { router: string, pairtoken: string, slth: string, sama: string, gnosis: string } } = {
  56: {
    pairtoken: "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    router: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    slth: "0xb255cddf7fbaf1cbcc57d16fe2eaffffdbf5a8be",
    sama: "0x5B9dbeBbad94b8C6467Af9e8A851Bb120F9601c6",
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
  const routeraddress = networks[chainId].router
  const pairtokenaddress = networks[chainId].pairtoken
  const signers = await ethers.getSigners();
  let SamaInstance: SAMARI | null = null;
  let SlthInstance: SLOTHI | null = null;
  if (chainId != 56) {
    var SlthFactory = new SLOTHI__factory(signers[0]);
    var SamaFactory = new SAMARI__factory(signers[0]);
    SamaInstance = await SamaFactory.deploy();
    SlthInstance = await SlthFactory.deploy();
    await SamaInstance.deployed();
    await SlthInstance.deployed();
    networks[chainId].sama = SamaInstance.address;
    networks[chainId].slth = SlthInstance.address;
  }



  const AlvareNETfactory = new AlvareNet__factory(signers[0]);
  const AlvareNETinstance = await AlvareNETfactory.deploy();

  await AlvareNETinstance.deployed();

  console.log("AlvareNet deployed to:", AlvareNETinstance.address);

  const ProxyFactory = new ProxyFunctions__factory(signers[0]);
  const ProxyInstance = await ProxyFactory.deploy(AlvareNETinstance.address, routeraddress, pairtokenaddress);

  await ProxyInstance.deployed();

  console.log("ProxyInstance deployed to:", ProxyInstance.address);

  let pairaddess = await ProxyInstance.uniswapV2Pair();
  console.log("New pair is:", pairaddess)

  await AlvareNETinstance.setproxyContract(ProxyInstance.address);
  console.log("ProxyInstance now set in token contract!")

  var alvadminrole = await AlvareNETinstance.DEFAULT_ADMIN_ROLE();
  var alvjanitorrole = await AlvareNETinstance.JANITOR_ROLE();
  var alvtokenomicsrole = await AlvareNETinstance.TOCENOMICS_ROLE();
  var proxyadminrole = await ProxyInstance.DEFAULT_ADMIN_ROLE();
  var proxyfeerole = await ProxyInstance.FEE_ROLE();
  var proxymarketingrole = await ProxyInstance.MARKETING_WITHDRAW_ROLE();
  var proxypauserole = await ProxyInstance.PAUSE_ROLE();
  var proxyjanitorrole = await ProxyInstance.JANITOR_ROLE();

  const MerkleFactory = new MerkleDistributor__factory(signers[0]);
  const MerkleInstance = await MerkleFactory.deploy(AlvareNETinstance.address, settings.merkleroot, networks[chainId].slth, networks[chainId].sama, samafactor);
  
  await MerkleInstance.deployed()
  
  console.log("MerkleDistributer address: " + MerkleInstance.address);

  await (await AlvareNETinstance.excludeFromFee(MerkleInstance.address)).wait(1);
  await (await AlvareNETinstance.excludeFromFee(networks[chainId].gnosis)).wait(1);
  await (await AlvareNETinstance.grantRole(alvadminrole, networks[chainId].gnosis)).wait(1)
  await (await AlvareNETinstance.grantRole(alvjanitorrole, networks[chainId].gnosis)).wait(1)
  await (await AlvareNETinstance.grantRole(alvtokenomicsrole, networks[chainId].gnosis)).wait(1)
  await (await ProxyInstance.grantRole(proxyadminrole, networks[chainId].gnosis)).wait(1)
  await (await ProxyInstance.grantRole(proxyfeerole, networks[chainId].gnosis)).wait(1)
  await (await ProxyInstance.grantRole(proxymarketingrole, networks[chainId].gnosis)).wait(1)
  await (await ProxyInstance.grantRole(proxypauserole, networks[chainId].gnosis)).wait(1)
  await (await ProxyInstance.grantRole(proxyjanitorrole, networks[chainId].gnosis)).wait(1)
  var total = ethers.BigNumber.from(settings.slthtotal).add(ethers.BigNumber.from(settings.samatotal).mul(samafactor))
  await (await AlvareNETinstance.transfer(MerkleInstance.address, total)).wait(1);
  await (await AlvareNETinstance.transfer(networks[chainId].gnosis, await AlvareNETinstance.balanceOf(signers[0].address))).wait(1)

  if (chainId == 56 || chainId == 97) {
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

    console.log("Verifying MerkleDistributer contract!")
    await run("verify:verify", {
      address: MerkleInstance.address,
      constructorArguments: [
        AlvareNETinstance.address, settings.merkleroot, networks[chainId].slth, networks[chainId].sama, samafactor
      ]
    })
    if (SlthInstance) {
      console.log("Verifying Test Slothi contract!")
      await run("verify:verify", {
        contract: "contracts/test_slothi.sol:SLOTHI",
        address: SlthInstance.address
      })
    }
    if (SamaInstance) {
      console.log("Verifying Test Slothi contract!")
      await run("verify:verify", {
        contract: "contracts/test_samari.sol:SAMARI",
        address: SamaInstance.address
      })
    }
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
