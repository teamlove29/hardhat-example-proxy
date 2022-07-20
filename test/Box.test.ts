
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers,upgrades } from "hardhat";

describe("Box deploy", () => {
  var contract: Contract

  let Box, box: Contract

  beforeEach(async () => {
    Box = await ethers.getContractFactory("Box");
    box = await upgrades.deployProxy(Box, [42], { initializer: 'store' })
  })

  it("retrieve returns a value previously initialized", async () => {
    expect((await box.retrieve()).toString()).to.equal('42')
    expect(() => { box.increment() }).to.throw(TypeError)
  })

  it('upgrades', async function () {
    const BoxV2 = await ethers.getContractFactory("BoxV2")
    box = await upgrades.upgradeProxy(box.address, BoxV2)
    await box.increment()
    let result = await box.retrieve()
    expect(result).to.equal(43)
  })
})
