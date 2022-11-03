// const { ethers } = require("hardhat");
// const {
//   loadFixture,
// } = require("@nomicfoundation/hardhat-network-helpers");

// describe("ReceiverPays", () => {
//   function constructPaymentMessage(recipient, amount, nonce, contractAddress) {
//     return ethers.utils.solidityKeccak256(
//       ["address", "uint256", "uint256", "address"],
//       [recipient, amount, nonce, contractAddress]
//     )
//   }
//   async function signMessage(signer, message) {
//     return signer.signMessage(ethers.utils.arrayify(message))

//   }
//     // contractAddress is used to prevent cross-contract replay attacks.
//     // amount, in wei, specifies how much Ether should be sent.
//   async function signPayment(recipient, amount, nonce, contractAddress, owner) {
//     var message = constructPaymentMessage(recipient, amount, nonce, contractAddress);
//     return signMessage(owner, message);
//   }
  
//   async function deployReceiverPaysFixture() {
//     const ReceiverPays = await ethers.getContractFactory("ReceiverPays");
//     const receiverPays = await ReceiverPays.deploy({ value: ethers.utils.parseUnits("1.0", "ether") });
//     return receiverPays
//   }
//   it("test", async () => {
//     const [owner, stranger] = await ethers.getSigners();
//     console.log("owner", owner.address)
//     const receiverPays = await loadFixture(deployReceiverPaysFixture);

//     const amount = ethers.utils.parseUnits("1.0", "ether")
//     const signature = await signPayment(stranger.address, amount, 1, receiverPays.address, owner)

//     console.log(await ethers.provider.getBalance(receiverPays.address))

//     console.log(await ethers.provider.getBalance(stranger.address))

//     await receiverPays.connect(stranger).claimPayment(amount, 1, signature)

//     console.log(await ethers.provider.getBalance(receiverPays.address))

//     console.log(await ethers.provider.getBalance(stranger.address))

//   })
// })