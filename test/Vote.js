// const {
//   loadFixture,
// } = require("@nomicfoundation/hardhat-network-helpers");
// const hre = require("hardhat")
// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// describe("Vote", async function () {
//   async function deployBallot() {
//     const [owner, voter1, voter2] = await ethers.getSigners();

//     const Ballot = await ethers.getContractFactory("Ballot");
//     const proposalNames = [
//       ethers.utils.formatBytes32String("john"),
//       ethers.utils.formatBytes32String("anna")
//     ];
//     const ballot = await Ballot.deploy(proposalNames)
//     await ballot.deployed()

//     return { ballot, owner, voter1, voter2 }
//   }

//   describe("giveRightToVote", async function () {
//     it("should work correctly", async function () {
//       const { ballot, owner, voter1, voter2 } = await loadFixture(deployBallot);
//       await ballot.connect(owner).giveRightToVote(voter1.address)
//       console.log(await ballot.getVoterInfo(voter2.address))
//     })
//   })
// })