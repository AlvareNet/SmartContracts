import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import "@nomiclabs/hardhat-etherscan";
import { HardhatUserConfig } from 'hardhat/types'
const { mnemonic, bscscan } = require('./secrets.json');

const config: HardhatUserConfig = {
  defaultNetwork: "testnet",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
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