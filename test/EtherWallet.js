const { ethers } = require("hardhat");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("EtherWallet", () => {
  async function deployEtherWalletFixture() {
    const [owner] = await ethers.getSigners();
    const EtherWallet = await ethers.getContractFactory("EtherWallet");
    const etherWallet = await EtherWallet.deploy();

    return { etherWallet, owner }
  }

  it("success", async () => {
    const { etherWallet, owner } = await loadFixture(deployEtherWalletFixture);
    
    expect(await ethers.provider.getBalance(etherWallet.address)).to.eql(ethers.BigNumber.from(0))
    await owner.sendTransaction({
      to: etherWallet.address,
      value: ethers.utils.parseEther("1.0")
    });

    expect(await ethers.provider.getBalance(etherWallet.address)).to.eql(ethers.BigNumber.from(ethers.utils.parseEther("1.0")))

    await etherWallet.connect(owner).withdraw(ethers.utils.parseEther("0.5"))
    expect(await ethers.provider.getBalance(etherWallet.address)).to.eql(ethers.BigNumber.from(ethers.utils.parseEther("0.5")))
  })
})