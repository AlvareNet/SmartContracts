import { ethers, run } from "hardhat";
import { MarketingDistributor__factory } from "../typechain";

const MarketingWallet = "0x7D34b70F1B121EfcF677668557FD1e0fC4e667BF";
const ITWallet = "0xeEA7bF8c43b5265b7Bb40807D237aE5465548851";
const SavingsWallet = "0x2d539cFA1fcA26ef936Ec9faBab7B40806c706d1";
const ExchangeWallet = "0x11D48c535f2a01C7953699C88696F23921043436";
const SalaryWallet = "0x660D7A51608442ae30151A13F50bfb53f95cE88A";
const ProxyContract = "0xa3e476f69e28b01432456b4d827b3f36caa60f43";
const BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56";

async function main() {
    const { chainId } = await ethers.provider.getNetwork()
    const signers = await ethers.getSigners();
  
  
    const MarketingDistributorFactory = new MarketingDistributor__factory(signers[0]);
    const MarketingDistributor = await MarketingDistributorFactory.deploy(MarketingWallet, ITWallet, SalaryWallet, ExchangeWallet, SavingsWallet, ProxyContract, BUSD);
    await MarketingDistributor.deployed();
    await MarketingDistributor.grantRole(await MarketingDistributor.WITHDRAWER_ROLE(), "0x7963bc2dc525186BB5b184b3d1A2c27d213E3A7b")
    await MarketingDistributor.grantRole(await MarketingDistributor.WITHDRAWER_ROLE(), "0x6770E2C100280EdFf9B7D0A99e636b6fa06f3CBd")
    await MarketingDistributor.grantRole(await MarketingDistributor.WITHDRAWER_ROLE(), signers[0].address)
    // if (chainId == 56 || chainId == 97) {
    //   console.log("Verifying contracts")
    //   console.log("Verifying MerkleDistributer contract!")
    //   await run("verify:verify", {
    //     address: MarketingDistributor.address,
    //     constructorArguments: [
    //         MarketingWallet, ITWallet, SalaryWallet, ExchangeWallet, SavingsWallet, ProxyContract, BUSD
    //     ]
    //   })
    // }
  }
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });