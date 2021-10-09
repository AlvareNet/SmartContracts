import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import "@nomiclabs/hardhat-etherscan";
import { HardhatUserConfig } from 'hardhat/types'
const { mnemonic, bscscan } = require('./secrets.json');

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      forking: {
        url: "https://speedy-nodes-nyc.moralis.io/811503707c61a97215f6e251/bsc/mainnet/archive",
        blockNumber: 9359739
      }
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 10000000000,
      accounts: {mnemonic: mnemonic}
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 10000000000,
      accounts: {mnemonic: mnemonic}
    }
  },
  etherscan: {
    apiKey: bscscan
  },
  solidity: {
    compilers: [{ version: '0.8.4', settings: {} }],
  },
}

export default config