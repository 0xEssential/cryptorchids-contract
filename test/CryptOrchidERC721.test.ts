import chai, {expect} from './chai-setup';
import sinon from "sinon";
import { chunk } from 'lodash';
import {
  ethers,
  deployments,
  getUnnamedAccounts,
} from 'hardhat';
import { setupUsers } from './utils';
import { add, compareAsc } from 'date-fns'
import { BigNumber } from 'ethers';

const keyhash = '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4'

const setup = deployments.createFixture(async () => {
  const [owner] = await ethers.getSigners();

  const MockLink = await ethers.getContractFactory("MockLink")
  const VRFCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorMock")
  const link = await MockLink.deploy()
  const vrfCoordinatorMock = await VRFCoordinatorMock.deploy(link.address)

  const CryptOrchidERC721 = await ethers.getContractFactory("CryptOrchidsMock");

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

  it("Uses 3 hours as the GROWTH_CYCLE", async function() {
    const { CryptOrchidERC721 } = await setup();
    const GROWTH_CYCLE = await CryptOrchidERC721.GROWTH_CYCLE();
    const now = new Date();
    const wateringStart = add(now, {seconds: GROWTH_CYCLE.toNumber()});
    const expectedWateringStart = add(now, {hours: 3})

    expect(compareAsc(wateringStart, expectedWateringStart)).to.equal(0);
  });

  it("Uses 1 hour as the WATERING_WINDOW", async function() {
    const { CryptOrchidERC721 } = await setup();
    const WATERING_WINDOW = await CryptOrchidERC721.WATERING_WINDOW();
    const now = new Date();
    const wateringEnd = add(now, {seconds: WATERING_WINDOW.toNumber()});
    const expectedWateringEnd = add(now, {hours: 1})

    expect(compareAsc(wateringEnd, expectedWateringEnd)).to.equal(0);
  });

  describe.only('webMint', function () {
    const maxUnits = 20;
    const minUnits = 1;
    let requestIds = [];
    let mockedCoordinator;
    let cryptorchidsContract;
    let account;

    const webMint = async (units: number) => {
      const { CryptOrchidERC721, VRFCoordinatorMock, users } = await setup();

      cryptorchidsContract = CryptOrchidERC721;
      account = users[0];
      mockedCoordinator = VRFCoordinatorMock      

      const transaction = await account.CryptOrchidERC721.webMint(
        units,
        Math.ceil(Math.random()),
        { 
          value: ethers.utils.parseUnits('0.02', 'ether').mul(units),
        }
      );
      
      const tx_receipt = await transaction.wait();
      requestIds = chunk(tx_receipt.events, 4).reduce((acc, chunk) => (
        [
          ...acc,
          chunk[3].data
        ]
      ), [])

      const pseudoRandom = Math.floor(Math.random() * (10_000 - 1));

      return Promise.all(requestIds.map(async (requestId) => (
        await mockedCoordinator.callBackWithRandomness(
          requestId, pseudoRandom, cryptorchidsContract.address
        )
      )));
    }
    
    it("Mints units number of tokens for sender", async () => {      
      const units = Math.floor(Math.random() * (maxUnits - minUnits + 1)) + minUnits;
      
      await webMint(units);

      const supply = await cryptorchidsContract.totalSupply();
      const ownedBySender = await cryptorchidsContract.balanceOf(account.address);
      expect(supply.toNumber()).to.equal(units);
      expect(ownedBySender).to.equal(units);
    })

    it("Mints a moth orchid for randomNumber <= 3074", async function() {
      // await mockedCoordinator.callBackWithRandomness(requestId, 10_777, cryptorchidsContract.address)

      // expect(await CryptOrchidERC721.buildSpeciesMetadata(randomNumber)).to.equal(0);
    });

    describe("Token functionality", () => {
      let tokenId;
      let clock;
      let GROWTH_CYCLE_MS;
      let WATERING_WINDOW_MS;

      before(async () => {
        const cycle = await cryptorchidsContract.GROWTH_CYCLE();
        const wateringWindow = await cryptorchidsContract.WATERING_WINDOW();
        
        GROWTH_CYCLE_MS = cycle.mul(1000)
        WATERING_WINDOW_MS = wateringWindow.mul(1000)
        
        
        await webMint(1);

        tokenId = await cryptorchidsContract.tokenOfOwnerByIndex(account.address, 0);
      })

      describe('alive()', () => {
        it('returns true when a plant is alive less time than GROWTH_CYCLE', async() => {
          const alive = await cryptorchidsContract.alive(tokenId - 1);
          expect(alive).to.eq(true)
        });

        it('returns true when a plant is in WATERING_WINDOW', async() => {
          await(cryptorchidsContract.timeTravel(GROWTH_CYCLE_MS.add((WATERING_WINDOW_MS).sub(60_000)).div(1000)));

          const alive = await cryptorchidsContract.alive(tokenId - 1);
          expect(alive).to.eq(true)
        });

        it('returns false when a plant is past WATERING_WINDOW', async() => {
          await(cryptorchidsContract.timeTravel(GROWTH_CYCLE_MS.add((WATERING_WINDOW_MS).add(60_000)).div(1000)));

          const alive = await cryptorchidsContract.alive(tokenId - 1);
          expect(alive).to.eq(false)
        });
      });
  
  
      xit("Allows an owner to water", async function() {
        const { users } = await setup();
    
        const transaction = await users[0].CryptOrchidERC721.webMint(
          Math.ceil(Math.random()),
          { 
            value: ethers.utils.parseUnits('0.01', 'ether'),
            from: users[0].address,
            gasLimit: BigNumber.from(9500000)
          }
        );
    
        await transaction.wait()
        const now = new Date().getTime() * 1000
        const watering  = await users[0].CryptOrchidERC721.water(1, now);
        console.log(watering)
      });
    })
  })
});
