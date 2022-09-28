// const {
//   loadFixture,
// } = require("@nomicfoundation/hardhat-network-helpers");
// const hre = require("hardhat")
// const { expect } = require("chai");

// describe("ERC777OpratableUpgradable", function () {
//   async function deployERC777OpratableUpgradable() {
//     const [owner, stranger] = await ethers.getSigners();

//     const ERC777OpratableUpgradable = await ethers.getContractFactory("ERC777OpratableUpgradable");
//     const erc777 = await await hre.upgrades.deployProxy(
//       ERC777OpratableUpgradable,
//       ['TEST', 'TST', [owner.address], ethers.utils.parseEther('100000')],
//       {
//         initializer: 'initialize'
//       }
//     );

//     const FeeRecieverBasic = await ethers.getContractFactory("FeeRecieverBasic");
//     const feeReceiverBasic = await FeeRecieverBasic.deploy(erc777.address);

//     return { erc777, feeReceiverBasic, owner, stranger };
//   }


//   describe("Deployment", function () {
//     it("Should correct information", async function () {
//       const { erc777, feeReceiverBasic, owner, stranger } = await loadFixture(deployERC777OpratableUpgradable);
//       console.log("feeReceiverBasic", feeReceiverBasic.address)
//       await feeReceiverBasic.connect(owner).registerReciever(feeReceiverBasic.address, 200)
//       await erc777.connect(owner).transfer(feeReceiverBasic.address, ethers.utils.parseEther("200"))
//       console.log(await erc777.connect(owner).balanceOf(feeReceiverBasic.address))
//     });

//   });
// });
