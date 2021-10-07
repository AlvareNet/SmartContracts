import chai from "chai";
import { ethers, network } from "hardhat";
import { BigNumber, Signer } from "ethers";
import { solidity } from "ethereum-waffle";
import fetch from "node-fetch";
chai.use(solidity);
const { expect } = chai;
import { AlvareNet, AlvareNet__factory, ProxyFunctions, ProxyFunctions__factory } from "../typechain"
import { assert } from "console";

describe("Testing Pause function", function(){
    let ProxyInstance: ProxyFunctions;
    let AlvareNETinstance: AlvareNet;
    const routeraddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    const pairtokenaddress = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
    let accounts: Signer[];
    it("Deploy token", async function () {
        accounts = await ethers.getSigners();
      
        const AlvareNETfactory = new AlvareNet__factory(accounts[0]);
        AlvareNETinstance = await AlvareNETfactory.deploy();
      
        await AlvareNETinstance.deployed();
      
        console.log("AlvareNet deployed to:", AlvareNETinstance.address);
      
        const ProxyFactory = new ProxyFunctions__factory(accounts[0]);
        ProxyInstance = await ProxyFactory.deploy(AlvareNETinstance.address, routeraddress, pairtokenaddress);
      
        await ProxyInstance.deployed();
      
        console.log("ProxyInstance deployed to:", ProxyInstance.address);
      
        let pairaddess = await ProxyInstance.uniswapV2Pair();
        console.log("New pair is:", pairaddess)
      
        await AlvareNETinstance.setproxyContract(ProxyInstance.address);
        console.log("ProxyInstance now set in token contract!")
        await AlvareNETinstance.changeProxyState(true);
        expect(true);
    })

    it("Test unpaused transfer", async function () {
        var fail = false;
        try{
            var tmpAlvareNet = AlvareNet__factory.connect(AlvareNETinstance.address, accounts[1])
            var tx = await AlvareNETinstance.transfer(await accounts[1].getAddress(), 10000);
            await tx.wait(1)
            tx = await tmpAlvareNet.transfer(await accounts[2].getAddress(), 10000 );
            await tx.wait(1)
        }
        catch(error){
            console.log(error)
            fail = true;
            console.log("This should not happen")
        }
        expect(!fail);
    })

    it("Test paused transfer", async function () {
        var fail1 = false;
        try{
            await ProxyInstance.pause();
            var tx = await AlvareNETinstance.transfer(await accounts[1].getAddress(), 10000);
            await tx.wait(1)
        }
        catch(error){
            console.log(error)
            fail1 = true;
            console.log("This should not happen")
        }
        var fail2 = true;
        try{
            var tmpAlvareNet = AlvareNet__factory.connect(AlvareNETinstance.address, accounts[1])
            tx = await tmpAlvareNet.transfer(await accounts[3].getAddress(), 10000);
            await tx.wait(1)
        }
        catch(error){
            fail2 = false;
            console.log("Not allowed tx failed")
        }
        var fail3 = false;
        try{
            await ProxyInstance.unpause()
            var tmpAlvareNet = AlvareNet__factory.connect(AlvareNETinstance.address, accounts[1])
            tx = await tmpAlvareNet.transfer(await accounts[3].getAddress(), 10000);
            await tx.wait(1)
        }
        catch(error){
            console.log(error)
            fail3 = true;
            console.log("Failed in 3rd send")
        }
        var fail4 = false;
        try{
            await ProxyInstance.pause()
            await ProxyInstance.grantRole(await ProxyInstance.PAUSE_ROLE(), await accounts[3].getAddress())
            var tmpAlvareNet = AlvareNet__factory.connect(AlvareNETinstance.address, accounts[3])
            tx = await tmpAlvareNet.transfer(await accounts[2].getAddress(), 5000);
            await tx.wait(1)
        }
        catch(error){
            console.log(error)
            fail4 = true;
            console.log("Failed in last send")
        }

        expect(!fail1 && !fail2 && !fail3 && !fail4);
    })
})