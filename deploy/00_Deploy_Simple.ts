import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, upgrades, getNamedAccounts, network } = hre
  const { deploy, execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  log(`Deploying contracts with the account: ${deployer}`)
  log(chalk.yellow(`Network Name: ${network.name}`))
  log('----------------------------------------------------')

  const name: { [key: string]: any } = {}

    name[`name`] = 'ApeCoin'
    name[`symbol`] = 'APE'
    name[`totalSupply_`] = '1000000000000000000000000000'
    args: Object.values(name)

  const deploymentName = 'SimpleToken'
  const SimpleToken = await deploy(deploymentName, {
    contract: 'SimpleToken',
    from: deployer,
    log: true,
    args:Object.values(name),
    skipIfAlreadyDeployed: true,
  })

  log(`You have deployed an contract to ${SimpleToken.address}`)

  log(`Could be found at ....`)
  log(chalk.yellow(`/deployments/${network.name}/${deploymentName}.json`))

  for (const i in name) {
    log(chalk.yellow(`Argument: ${i} - value: ${name[i]}`))
  }

  if (SimpleToken.newlyDeployed) {
    try {
      await hre.run('verify:verify', {
        address: SimpleToken.address,
        constructorArguments: Object.values(name),
        contract: "contracts/SimpleToken.sol:SimpleToken"
      })
    } catch (err) {
      console.log(err)
    }
  }

  log(
    `Verify with:\n npx hardhat verify --network rinkeby --contract contracts/SimpleToken.sol:SimpleToken ${
      SimpleToken.address
    } ${Object.values(name).toString().replace(/,/g, ' ')}`,
  )

  log(chalk.cyan(`Ending Script.....`))
  log(chalk.cyan(`.....`))
}
export default func
func.tags = ['all', 'Simple']
