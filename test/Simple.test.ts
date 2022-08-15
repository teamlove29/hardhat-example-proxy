
import chai from 'chai';
import { Contract } from "ethers";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

chai.use(solidity);
const { expect } = chai;

describe("SimpleToken", () => {    
    let SimpleToken, simpleToken: Contract

    let deployer: SignerWithAddress;

  beforeEach(async () => {
    [deployer] = await ethers.getSigners();
    SimpleToken = await ethers.getContractFactory("SimpleToken");
    simpleToken = await SimpleToken.deploy("SimpleToken", "APE", "1000000000000000000000000000")
  })

  it("Assigns initial balance", async () => {
    expect(await simpleToken.balanceOf(deployer.address)).to.equal("1000000000000000000000000000")
  })
})
