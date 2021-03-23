import chai, {expect} from './chai-setup';
import {
  ethers,
  deployments,
  getUnnamedAccounts,
  getNamedAccounts,
} from 'hardhat';
import {CryptOrchidERC721} from '../typechain';
import {setupUser, setupUsers} from './utils';

const RINKEBY_VRF_COORDINATOR = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B';
const RINKEBY_LINKTOKEN = '0x01be23585060835e02b77ef475b0cc51aa1e0709';
const RINKEBY_KEYHASH =
  '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311';


const setup = deployments.createFixture(async () => {
  const [owner] = await ethers.getSigners();

  const CryptOrchidERC721 = await ethers.getContractFactory("CryptOrchidERC721");

  const CryptOrchids = await CryptOrchidERC721.deploy(
    RINKEBY_VRF_COORDINATOR, RINKEBY_LINKTOKEN, RINKEBY_KEYHASH
  );

  const contracts = {
    CryptOrchidERC721: CryptOrchids,
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

  // xit("Allows any user to mint via webMint", async function() {
  //   const { users, CryptOrchidERC721 } = await setup();

  //   const spy = chai.spy(CryptOrchidERC721.requestRandomness);
  //   CryptOrchidERC721.requestRandomness = spy;

  //   const mintResult = await CryptOrchidERC721.webMint(
  //     Math.ceil(Math.random()),
  //     { 
  //       value: ethers.utils.parseUnits('0.01', 'ether')
  //     }
  //   );

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
