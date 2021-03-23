import chai, {expect} from './chai-setup';
import {
  ethers,
  deployments,
  getUnnamedAccounts,
  getNamedAccounts,
} from 'hardhat';
import {CryptOrchidERC721} from '../typechain';
import {setupUser, setupUsers} from './utils';

const keyhash = '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4'

const setup = deployments.createFixture(async () => {
  const [owner] = await ethers.getSigners();

  const MockLink = await ethers.getContractFactory("MockLink")
  const VRFCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorMock")
  const link = await MockLink.deploy()
  const vrfCoordinatorMock = await VRFCoordinatorMock.deploy(link.address)
  const CryptOrchidERC721 = await ethers.getContractFactory("CryptOrchidERC721");

  const CryptOrchids = await CryptOrchidERC721.deploy(
    vrfCoordinatorMock.address, link.address, keyhash  
  );

  await link.transfer(CryptOrchids.address, '2000000000000000000')


  const contracts = {
    CryptOrchidERC721: CryptOrchids,
    VRFCoordinatorMock: vrfCoordinatorMock,
  };

  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    users,
    owner,
  };
});


describe('CryptOrchidERC721', function () {  
  it("Does not create any tokens on deployment", async function() {
    const { CryptOrchidERC721 } = await setup();

    expect(await CryptOrchidERC721.totalSupply()).to.equal(0);
  });

  it("Random Number Should successfully make an external random number request", async () => {    
    const { CryptOrchidERC721, VRFCoordinatorMock, users } = await setup();
    const transaction = await users[0].CryptOrchidERC721.webMint(
      Math.ceil(Math.random()),
      { 
        value: ethers.utils.parseUnits('0.01', 'ether'),
        from: users[0].address,
        gasLimit: 9500000
      }
    );

    console.warn("testsender", users[0].address)
      
    const tx_receipt = await transaction.wait()

    const topics = tx_receipt.events.reduce((acc, event) => (
      [
        ...acc,
        ...event?.topics
      ]
    ), [])

    console.warn(topics)

    const requestId = tx_receipt.events[2].topics[0]

    // await Promise.all(
    //   topics.map(async (topic) => {
    //     const contractSender = await CryptOrchidERC721.requestToSender(requestId)
    //     console.log("sender found?", contractSender)
    //   })
    // )
    // console.warn("requestId", requestId)
    
    const tx = await VRFCoordinatorMock.callBackWithRandomness(requestId, 777, CryptOrchidERC721.address)
    
    const ownedCount = await users[0].CryptOrchidERC721.balanceOf(users[0].address)
    // const total = await users[0].CryptOrchidERC721.cryptorchids()
      // console.warn(total)
    expect(ownedCount).to.equal(1);
  })

  // xit("Allows any user to mint via webMint", async function() {
  //   const { users, CryptOrchidERC721 } = await setup();

  //   const spy = chai.spy(CryptOrchidERC721.requestRandomness);
  //   CryptOrchidERC721.requestRandomness = spy;

    // const mintResult = await CryptOrchidERC721.webMint(
    //   Math.ceil(Math.random()),
    //   { 
    //     value: ethers.utils.parseUnits('0.01', 'ether')
    //   }
    // );

  //   console.warn(mintResult.value.toNumber())
  //   expect(spy.to.have.beenCalled());
  // });

  describe('buildSpeciesMetadata', function () {
    it("Returns moth orchid for randomNumber <= 3074", async function() {
      const { CryptOrchidERC721 } = await setup();
      
      const randomNumber = Math.floor(Math.random() * 3074) + 1  


      expect(await CryptOrchidERC721.buildSpeciesMetadata(randomNumber)).to.equal(0);
    });
  })



  // it('transfer fails', async function () {
  //   const {users} = await setup();
  //   await expect(
  //     users[0].CryptOrchidERC721.safeTransferFrom(users[1].address, 1)
  //   ).to.be.revertedWith('NOT_ENOUGH_TOKENS');
  // });

  // it('transfer succeed', async function () {
  //   const {users, simpleERC20Beneficiary} = await setup();
  //   await simpleERC20Beneficiary.CryptOrchidERC721.transfer(users[1].address, 1);
  // });
});
