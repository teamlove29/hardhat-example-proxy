import { expect } from 'chai'
import { BigNumber as EthersBN, constants, Contract } from 'ethers'
import { ethers } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('Worldician deploy', () => {
  let Worldician, worldicianToken: Contract
  let snapshotId: number
  let deployer: SignerWithAddress
  let account0: SignerWithAddress;
  let account1: SignerWithAddress;
  let account2: SignerWithAddress;
  let adminDAO: SignerWithAddress;
  let weth = '0xc778417e063141139fce010982780140aa0cd5ab'

  before(async () => {
    [deployer,account0,account1,account2,adminDAO] = await ethers.getSigners()
  })

  beforeEach(async () => {
    Worldician = await ethers.getContractFactory('WorldicianToken')
    worldicianToken = await Worldician.deploy(deployer.address, weth, adminDAO.address)
    snapshotId = await ethers.provider.send('evm_snapshot', [])
  })

  afterEach(async () => {
    await ethers.provider.send('evm_revert', [snapshotId])
  })

  it('should set name', async () => {
    expect(await worldicianToken.name()).to.eq('Worldicians')
  })

  it('should set symbol', async () => {
    expect(await worldicianToken.symbol()).to.eq('WORLDICIAN')
  })

  it('should allow minter to mint a noun to itself', async () => {
    const receipt = await (await worldicianToken.mint()).wait()
    const houseCreated = receipt.events?.[3]
    expect(houseCreated?.event).to.eq('WorldicianCreated')
    expect(houseCreated?.args?.tokenId).to.eq(1)
    expect(await worldicianToken.totalSupply()).to.eq(1)
    expect(await worldicianToken.ownerOf(1)).to.eq(deployer.address)
  })

  it('should not allow mint > 444', async () => {
    for(let i = 1; i <= 444; i++) {
      await (await worldicianToken.mint()).wait()
    }

    await expect(worldicianToken.mint()).to.be.revertedWith(
      'WorldicianToken: Max Supply!',
    );
    
    expect(await worldicianToken.totalSupply()).to.eq(444)
  })

  it('should mint > 444, 445 to adminDAO', async () => {
    for(let i = 1; i <= 444; i++) {
      await (await worldicianToken.mint()).wait()
    }
    await (await worldicianToken.setMaxSupply(445)).wait()
    await (await worldicianToken.mint()).wait()
    expect(await worldicianToken.totalSupply()).to.eq(445)
    expect(await worldicianToken.ownerOf(445)).to.eq(adminDAO.address)
  })

  // it('should emit two transfer logs on mint', async () => {

  // })

  it('should offer worldicianToken', async () => {
    // await (await worldicianToken.mint()).wait()

    // const deposit = await worldicianToken
    //   .connect(account1)
    //   .deposit({ value: 100,
    //   });
    // await deposit.wait();
    // expect(await worldicianToken.ethBalance(account1.address)).to.eq(100)
    // console.log(await worldicianToken.hashToSign(deployer.address,account1.address,0,[1],100,[],1660655632,1))
    const hash =  await worldicianToken.hashToSign(deployer.address,account1.address,0,[1],100,[],1660755776,1)
    const sign = await deployer.signMessage(hash)

    console.log('hash',hash);
    console.log('deployer',deployer.address);
    console.log('account1',account1.address);
    console.log('sign', sign);

    console.log(await worldicianToken.tradeValid(deployer.address,account1.address,0,[1],100,[],1660755776,1,sign));
  })


  // it('should offer worldicianToken + eth', async () => {

  // })

  // it('should cancel offer', async () => {

  // })

  // it('should accept offer', async () => {

  // })

    // console.log("maxSupply:",EthersBN.from(await worldicianToken.totalSupply()).toString());

  // it('should not allow minter other person', async () => {
  //   let otherGuy = worldicianToken.connect(account0);

  //   await expect(otherGuy.mint()).to.be.revertedWith('Sender is not the minter');
  // });


  // it('should emit two transfer logs on mint', async () => {
  //   const [, , creator, minter] = await ethers.getSigners();

  //   await (await worldicianToken.mint()).wait();

  //   await (await worldicianToken.setMinter(minter.address)).wait();
  //   await (await worldicianToken.transferOwnership(creator.address)).wait();

  //   const tx = worldicianToken.connect(minter).mint();

  //   await expect(tx)
  //     .to.emit(worldicianToken, 'Transfer')
  //     .withArgs(constants.AddressZero, creator.address, 2);
  //   await expect(tx).to.emit(worldicianToken, 'Transfer').withArgs(creator.address, minter.address, 2);
  // });

  // describe('contractURI', async () => {
  //   it('should return correct contractURI', async () => {
  //     expect(await worldicianToken.contractURI()).to.eq(
  //       'ipfs://QmZi1n79FqWt2tTLwCqiy6nLM6xLGRsEPQ5JmReJQKNNzX',
  //     )
  //   })
  //   it('should allow owner to set contractURI', async () => {
  //     await worldicianToken.setContractURIHash('ABC123')
  //     expect(await worldicianToken.contractURI()).to.eq('ipfs://ABC123')
  //   })
  //   it('should not allow non owner to set contractURI', async () => {
  //     const [, nonOwner] = await ethers.getSigners()
  //     await expect(
  //       worldicianToken.connect(nonOwner).setContractURIHash('BAD'),
  //     ).to.be.revertedWith('Ownable: caller is not the owner')
  //   })
  // })
})
