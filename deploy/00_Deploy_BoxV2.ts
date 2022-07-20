import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, upgrades, getNamedAccounts, network } = hre
  const { deploy, execute, log ,get} = deployments
  const { deployer } = await getNamedAccounts()

  log(`Deploying contracts with the account: ${deployer}`)
  log(chalk.yellow(`Network Name: ${network.name}`))
  log('----------------------------------------------------')

  const name: { [key: string]: any } = {}
  const proxyAddress = await get('Box_Proxy')

  const deploymentName = 'BoxV2'
  const Box = await deploy(deploymentName, {
    contract: 'BoxV2',
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
  })

  log(`You have deployed an Box contract to ${Box.address}`)

  log(`Could be found at ....`)
  log(chalk.yellow(`/deployments/${network.name}/${deploymentName}.json`))

  for (const i in name) {
    log(chalk.yellow(`Argument: ${i} - value: ${name[i]}`))
  }

  if (Box.newlyDeployed) {
    try {
      await execute('DefaultProxyAdmin', { from: deployer, log: true }, 'upgrade', proxyAddress.address,Box.address)
      await hre.run('verify:verify', {
        address: Box.address,
      })
    } catch (err) {
      console.log(err)
    }
  }

  log(chalk.cyan(`Ending Script.....`))
  log(chalk.cyan(`.....`))
}
export default func
func.tags = ['all', 'BoxV2']
