import { HardhatUserConfig } from 'hardhat/config'
import dotenv from 'dotenv'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-web3'
import '@openzeppelin/hardhat-upgrades'
import 'hardhat-deploy-ethers'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import 'solidity-coverage'
import 'hardhat-tracer'
import 'hardhat-log-remover'
import 'hardhat-storage-layout'
import '@tenderly/hardhat-tenderly'

dotenv.config()

const API_URL = process.env.INFURA_PROJECT_ID
const PRIVATE_KEY = ''
const ETHERSCAN_KEY = process.env.ETHERSCAN_API_KEY

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.5.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100,
          },
        },
      },
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            '*': {
              '*': ['storageLayout'],
            },
          },
        },
      },
      {
        version: '0.8.13',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            '*': {
              '*': ['storageLayout'],
            },
          },
        },
      },
    ],
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_KEY,
  },
  paths: {
    // sources: './src',
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
    deploy: './deploy',
    deployments: './deployments',
    imports: './imports',
  },

  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  // defaultNetwork: 'rinkeby',
  networks: {
    rinkeby: {
      url: API_URL,
      // accounts: [`0x${PRIVATE_KEY}`],
      accounts: process.env.MNEMONIC
        ? { mnemonic: process.env.MNEMONIC }
        : [`0x${PRIVATE_KEY}`],
      saveDeployments: true,
    },
    hardhat: {
      chainId: 1337,
      initialBaseFeePerGas: 0,
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  namedAccounts: {
    deployer: 0,
  },
  mocha: {
    timeout: 300000,
  },
}

export default config
