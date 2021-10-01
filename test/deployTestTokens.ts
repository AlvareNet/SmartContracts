import chai from "chai";
import { ethers, network } from "hardhat";
import { BigNumber, Signer } from "ethers";
import { solidity } from "ethereum-waffle";
import fetch from "node-fetch";
chai.use(solidity);
const { expect } = chai;
import { MerkleDistributor, MerkleDistributor__factory, AlvareNet, AlvareNet__factory, SAMARI, SAMARI__factory } from "../typechain"
import { assert } from "console";

describe("Merkle Distributer", function () {
    this.timeout(0);
    let accounts: Signer[];
    const provider = new ethers.providers.JsonRpcProvider()
    let MerkleContract: MerkleDistributor;
    let AlvareContract: AlvareNet;
    let mapping: ({ start: string, stop: string, file: string }[]);
    let data: { [key: string]: { index: number, contract: string; amount: string, proof: string[] }[] } = {}
    let settings: { merkleroot: string, slthtotal: string, samatotal: string }
    let SlothiAddress = "0x5B9dbeBbad94b8C6467Af9e8A851Bb120F9601c6";
    let SamariAddress = "0xb255cddf7fbaf1cbcc57d16fe2eaffffdbf5a8be";
    const testobject = [1, 2, 3, 4, 5]
    it("Get Airdrop Data", async function () {
        settings = await (await fetch("https://raw.githubusercontent.com/AlvareNet/AirdropData/Dualcontract/output/settings.json")).json() as { merkleroot: string, slthtotal: string, samatotal: string }
        mapping = await (await fetch("https://raw.githubusercontent.com/AlvareNet/AirdropData/Dualcontract/output/mappings.json")).json() as ({ start: string, stop: string, file: string }[])

        for await (var contents of mapping.map(chunkfile => {
            return (fetch("https://raw.githubusercontent.com/AlvareNet/AirdropData/Dualcontract/output/" + chunkfile.file)).then(result => result.json()) as Promise<{ [key: string]: { index: number, contract: string; amount: string, proof: string[] }[] }>
        })) {
            data = Object.assign(data, contents)
        }
        expect(mapping && settings && data)
    })
    it("Deploy Alvare Token", async function () {
        accounts = await ethers.getSigners();
        var AlvareFactory = new AlvareNet__factory(accounts[0]);
        AlvareContract = await AlvareFactory.deploy();
        expect(await AlvareContract.balanceOf(await accounts[0].getAddress())).to.equal(await AlvareContract.totalSupply())
    })
    it("Deploy Merkle Distributor", async function () {

        var MerkleFactory = new MerkleDistributor__factory(accounts[0])

        MerkleContract = await MerkleFactory.deploy(AlvareContract.address.toString(), settings.merkleroot, SlothiAddress, SamariAddress, 70)
        expect(await MerkleContract.getBalance(10)).to.equal(BigNumber.from(10))
    })
    it("Send to Merkle Contract", async function () {
        var total = BigNumber.from(settings.slthtotal).add((BigNumber.from(settings.samatotal).mul(70)))
        await (await AlvareContract.transfer(MerkleContract.address.toString(), total)).wait(1)
        expect(await AlvareContract.balanceOf(MerkleContract.address.toString())).to.equal(total)
    })
    it("Checking entries ", async function () {
        var errorcounter = 0;
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x1F79B8aef7854D86e2cC89Ada44CB95a33cd72Cf"],
          });
        var SamariOwner = await ethers.provider.getSigner(ethers.utils.getAddress("0x1F79B8aef7854D86e2cC89Ada44CB95a33cd72Cf"))
        await (await SamariOwner.sendTransaction({
            to: "0xb255cddf7fbaf1cbcc57d16fe2eaffffdbf5a8be",
            data: "0x3f4ba83a"
        })).wait(1)
        var SamariContract = SAMARI__factory.connect(SamariAddress, accounts[0]);
        var SlothiContarct = SAMARI__factory.connect(SlothiAddress, accounts[0]);
        var samatransactions = 0;
        var slothitransactions = 0;
        for (const key of Object.keys(data)) {
            let entry = data[key]
            await network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [key],
              });
            await network.provider.send("hardhat_setBalance", [
                key,
                "0xFFFFFFFFFFFFFFFFFFFFFFFF",
            ]);
            var signerOverride = await ethers.provider.getSigner(ethers.utils.getAddress(key))
            var tokencontract
            var distributecontract = MerkleContract.connect(signerOverride)
            for (const element of entry) {
                var tokencontract;
                if(element.contract.toLowerCase() == SlothiAddress.toLowerCase()){
                    tokencontract = SlothiContarct.connect(signerOverride);
                    samatransactions++;
                }
                else{
                    tokencontract = SamariContract.connect(signerOverride);
                    slothitransactions++;
                }
                await (await tokencontract.approve(MerkleContract.address.toString(), ethers.constants.MaxUint256));
                try{
                    let tx = await (await distributecontract.claim(element.index, key, element.amount, element.contract, element.proof)).wait()
                }
                catch(error) {
                    errorcounter++;
                    var name = (await tokencontract.name())
                    console.log((error as Error).message)
                    console.log(name + ": " + key + " : " + BigNumber.from(element.amount).div(1000000000).toString())
                    console.log(element.index)
                }
                

            };
        }
        console.log("Samari transactions: " + samatransactions.toString())
        console.log("Slothi transactions: " + slothitransactions.toString())
        console.log("Total fails: " + errorcounter.toString())
        console.log(await AlvareContract.balanceOf(MerkleContract.address))
        assert(true);
    })
});
