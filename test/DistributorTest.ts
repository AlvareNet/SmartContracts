import chai from "chai";
import { ethers, network } from "hardhat";
import { BigNumber, Signer } from "ethers";
import { solidity } from "ethereum-waffle";
import fetch from "node-fetch";
chai.use(solidity);
const { expect } = chai;
import {  MarketingDistributor__factory, ProxyFunctions, ProxyFunctions__factory, IERC20__factory, MarketingDistributor } from "../typechain"
import { assert } from "console";

const MarketingWallet = "0x7D34b70F1B121EfcF677668557FD1e0fC4e667BF";
const ITWallet = "0xeEA7bF8c43b5265b7Bb40807D237aE5465548851";
const SavingsWallet = "0x2d539cFA1fcA26ef936Ec9faBab7B40806c706d1";
const ExchangeWallet = "0x11D48c535f2a01C7953699C88696F23921043436";
const SalaryWallet = "0x660D7A51608442ae30151A13F50bfb53f95cE88A";
const ProxyContract = "0xa3e476f69e28b01432456b4d827b3f36caa60f43";
const BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56";

describe("Testing Marketing Distributor", function(){
    let ProxyInstance: ProxyFunctions;
    let Distributor : MarketingDistributor;
    let accounts: Signer[];
    it("Deploy token, creator should be default admin", async function () {
        accounts = await ethers.getSigners();
        const DistributorFactory = new MarketingDistributor__factory(accounts[0]);
        Distributor = await DistributorFactory.deploy(MarketingWallet, ITWallet, SalaryWallet, ExchangeWallet, SavingsWallet, ProxyContract, BUSD);
        await Distributor.deployed()
        ProxyInstance = ProxyFunctions__factory.connect(ProxyContract, accounts[0]);
        await ProxyInstance.deployed()
        expect(await Distributor.getRoleMember(await Distributor.DEFAULT_ADMIN_ROLE(), 0)).to.equal(await accounts[0].getAddress());
    })

    it("Deployer should be admin of ProxyInstance", async function () {
        expect(await ProxyInstance.hasRole(await ProxyInstance.DEFAULT_ADMIN_ROLE(), await accounts[0].getAddress()));
    })

    it("Marketing distributor should be set to withdrawer role", async function () {
        await ProxyInstance.grantRole(await ProxyInstance.MARKETING_WITHDRAW_ROLE(), Distributor.address)
        expect(await ProxyInstance.hasRole(await ProxyInstance.MARKETING_WITHDRAW_ROLE(), Distributor.address));
    })

    it("Marketing distributor send the right amount to each account", async function () {
        const BUSDInstance = IERC20__factory.connect(BUSD, accounts[0]);
        await BUSDInstance.deployed();
        const MarketingBalance = await BUSDInstance.balanceOf(MarketingWallet);
        const SalaryBalance = await BUSDInstance.balanceOf(SalaryWallet);
        const Itbalance = await BUSDInstance.balanceOf(ITWallet);
        const ExchangeBalance = await BUSDInstance.balanceOf(ExchangeWallet);
        const SavingsBalance = await BUSDInstance.balanceOf(SavingsWallet);

        const ProxyBalance = await BUSDInstance.balanceOf(ProxyContract);
        await (await Distributor.distribute()).wait(1);
        const DistributedTokens = ProxyBalance.sub(await BUSDInstance.balanceOf(ProxyContract));

        //Marketing Balance
        const MarketingDifference = (await BUSDInstance.balanceOf(MarketingWallet)).sub(MarketingBalance);
        const ExpectedMarketing = DistributedTokens.mul(50).div(100);
        expect(MarketingDifference).to.equal(ExpectedMarketing);

        //IT servie Balance
        const ITDifference = (await BUSDInstance.balanceOf(ITWallet)).sub(Itbalance);
        const ExpectedIT = DistributedTokens.mul(5).div(100);
        expect(ITDifference).to.equal(ExpectedIT);

        //Salary balance
        const SalaryDifference = (await BUSDInstance.balanceOf(SalaryWallet)).sub(SavingsBalance);
        const ExpectedSalary = DistributedTokens.mul(20).div(100);
        expect(SalaryDifference).to.equal(ExpectedSalary);

        //Exchange balance
        const ExchangeDifference = (await BUSDInstance.balanceOf(ExchangeWallet)).sub(ExchangeBalance);
        const ExpectedExchange = DistributedTokens.mul(10).div(100);
        expect(ExchangeDifference).to.equal(ExpectedExchange);

        //Savings balance
        const SavingsDifference = (await BUSDInstance.balanceOf(SavingsWallet)).sub(SavingsBalance);
        const ExpectedSavings = DistributedTokens.mul(15).div(100);
        expect(SavingsDifference).to.equal(ExpectedSavings);
        
        const totalWithdrawn = ProxyBalance.sub(await BUSDInstance.balanceOf(ProxyContract)).sub(await BUSDInstance.balanceOf(Distributor.address));
        const totalRecieved = SavingsDifference.add(ExchangeDifference).add(SalaryDifference).add(ITDifference).add(MarketingDifference)
        expect(totalRecieved).to.equal(totalWithdrawn);
    })



})