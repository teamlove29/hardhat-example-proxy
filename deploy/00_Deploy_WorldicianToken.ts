import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments , getNamedAccounts, network } = hre
  const { deploy, execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  log(`Deploying contracts with the account: ${deployer}`)
  log(chalk.yellow(`Network Name: ${network.name}`))
  log('----------------------------------------------------')

  const name: { [key: string]: any } = {}

    name[`_minter`] = deployer
    name[`_weth`] = '0xc778417e063141139fce010982780140aa0cd5ab'
    args: Object.values(name)

  const deploymentName = 'WorldicianToken'
  const WorldicianToken = await deploy(deploymentName, {
    contract: 'WorldicianToken',
    from: deployer,
    log: true,
    args:Object.values(name),
    skipIfAlreadyDeployed: true,
  })

  log(`You have deployed an contract to ${WorldicianToken.address}`)

  log(`Could be found at ....`)
  log(chalk.yellow(`/deployments/${network.name}/${deploymentName}.json`))

  for (const i in name) {
    log(chalk.yellow(`Argument: ${i} - value: ${name[i]}`))
  }

  if (WorldicianToken.newlyDeployed) {
    try {
      await hre.run('verify:verify', {
        address: WorldicianToken.address,
        constructorArguments: Object.values(name),
        contract: "contracts/WorldicianToken.sol:WorldicianToken"
      })
    } catch (err) {
      console.log(err)
    }
  }

  log(
    `Verify with:\n npx hardhat verify --network rinkeby --contract contracts/WorldicianToken.sol:WorldicianToken ${
      WorldicianToken.address
    } ${Object.values(name).toString().replace(/,/g, ' ')}`,
  )

  log(chalk.cyan(`Ending Script.....`))
  log(chalk.cyan(`.....`))
}
export default func
func.tags = ['all', 'Token']
