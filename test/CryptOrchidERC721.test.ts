import chai, {expect} from './chai-setup';
import {chunk} from 'lodash';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {setupUsers} from './utils';
import {add, compareAsc} from 'date-fns';

const keyhash =
  '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4';

const numberBetween = (min: number, max: number) =>
  Math.floor(Math.random() * (max - min + 1)) + min;

const setup = deployments.createFixture(async () => {
  const [owner] = await ethers.getSigners();

  const MockLink = await ethers.getContractFactory('MockLink');
  const VRFCoordinatorMock = await ethers.getContractFactory(
    'VRFCoordinatorMock'
  );
  const link = await MockLink.deploy();
  const vrfCoordinatorMock = await VRFCoordinatorMock.deploy(link.address);

  const CryptOrchidERC721 = await ethers.getContractFactory('CryptOrchidsMock');

  const CryptOrchids = await CryptOrchidERC721.deploy(
    vrfCoordinatorMock.address,
    link.address,
    keyhash
  );

  await link.transfer(CryptOrchids.address, '2000000000000000000');

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
  it('Does not create any tokens on deployment', async function () {
    const {CryptOrchidERC721} = await setup();

    expect(await CryptOrchidERC721.totalSupply()).to.equal(0);
  });

  it('Uses 3 hours as the GROWTH_CYCLE', async function () {
    const {CryptOrchidERC721} = await setup();
    const GROWTH_CYCLE = await CryptOrchidERC721.GROWTH_CYCLE();
    const now = new Date();
    const wateringStart = add(now, {seconds: GROWTH_CYCLE.toNumber()});
    const expectedWateringStart = add(now, {hours: 3});

    expect(compareAsc(wateringStart, expectedWateringStart)).to.equal(0);
  });

  it('Uses 1 hour as the WATERING_WINDOW', async function () {
    const {CryptOrchidERC721} = await setup();
    const WATERING_WINDOW = await CryptOrchidERC721.WATERING_WINDOW();
    const now = new Date();
    const wateringEnd = add(now, {seconds: WATERING_WINDOW.toNumber()});
    const expectedWateringEnd = add(now, {hours: 1});

    expect(compareAsc(wateringEnd, expectedWateringEnd)).to.equal(0);
  });

  describe.only('webMint', function () {
    const maxUnits = 20;
    const minUnits = 1;
    let requestIds = [];
    let mockedCoordinator;
    let cryptorchidsContract;
    let account;

    const webMint = async (
      units: number,
      pseudoRandom = numberBetween(0, 10_000)
    ) => {
      const {CryptOrchidERC721, VRFCoordinatorMock, users} = await setup();

      cryptorchidsContract = CryptOrchidERC721;
      account = users[0];
      mockedCoordinator = VRFCoordinatorMock;

      const transaction = await account.CryptOrchidERC721.webMint(
        units,
        Math.ceil(Math.random()),
        {
          value: ethers.utils.parseUnits('0.02', 'ether').mul(units),
        }
      );

      const tx_receipt = await transaction.wait();
      requestIds = chunk(tx_receipt.events, 4).reduce(
        (acc, chunk) => [...acc, chunk[3].data],
        []
      );

      return Promise.all(
        requestIds.map(
          async (requestId) =>
            await mockedCoordinator.callBackWithRandomness(
              requestId,
              pseudoRandom,
              cryptorchidsContract.address
            )
        )
      );
    };

    // For picking species, we receive a huge number from VRF which we grab the 10k modulus.
    // Rather than using those massive numbers in test, we're using 0 - 10k, which results
    // in the same modulus frequency.
    it('Mints units number of tokens for sender', async () => {
      const units = numberBetween(maxUnits, minUnits);

      await webMint(units);

      const supply = await cryptorchidsContract.totalSupply();
      const ownedBySender = await cryptorchidsContract.balanceOf(
        account.address
      );
      expect(supply.toNumber()).to.equal(units);
      expect(ownedBySender).to.equal(units);
    });

    it('Mints a moth orchid for randomNumber <= 3074', async function () {
      await webMint(1, numberBetween(0, 3074));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('phalaenopsis micholitzii');
    });

    it('Mints an orange cattelya for 3074 < randomNumber <= 6074', async function () {
      await webMint(1, numberBetween(3075, 6074));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('guarianthe aurantiaca');
    });

    it('Mints a blue vanda for 6074 < randomNumber <= 8074', async function () {
      await webMint(1, numberBetween(6075, 8074));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('vanda coerulea');
    });

    it("Mints a lady's slipper for 8074 < randomNumber <= 9074", async function () {
      await webMint(1, numberBetween(8075, 9074));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('cypripedium calceolus');
    });

    it('Mints a Vietnamese Paphiopedilum for 9_074 < randomNumber <= 9574', async function () {
      await webMint(1, numberBetween(9_075, 9_574));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('paphiopedilum vietnamense');
    });

    it('Mints a Kayasima Miltonia for 9574 < randomNumber <= 9824', async function () {
      await webMint(1, numberBetween(9575, 9824));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('miltonia kayasimae');
    });

    it("Mints a Hochstetter's butterfly orchid for 9824 < randomNumber <= 9924", async function () {
      await webMint(1, numberBetween(9_825, 9_924));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('platanthera azorica');
    });

    it('Mints a Ghost orchid for 9_924 < randomNumber <= 9_974', async function () {
      await webMint(1, numberBetween(9_925, 9_974));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('dendrophylax lindenii');
    });

    it('Mints a Gold of Kinabalu for 9_974 < randomNumber <= 9_999', async function () {
      await webMint(1, numberBetween(9_975, 9_999));

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('paphiopedilum rothschildianum');
    });

    it('Mints THE Shenzen Nongke for randomNumber = 10_000', async function () {
      await webMint(1, 10_000);

      const {0: species} = await cryptorchidsContract.getTokenMetadata(1);
      expect(species).to.equal('shenzhenica orchidaceae');
    });

    describe('Token functionality', () => {
      let tokenId;
      let GROWTH_CYCLE_MS;
      let WATERING_WINDOW_MS;

      beforeEach(async () => {
        const cycle = await cryptorchidsContract.GROWTH_CYCLE();
        const wateringWindow = await cryptorchidsContract.WATERING_WINDOW();

        GROWTH_CYCLE_MS = cycle.mul(1000);
        WATERING_WINDOW_MS = wateringWindow.mul(1000);

        await webMint(1);

        tokenId = await cryptorchidsContract.tokenOfOwnerByIndex(
          account.address,
          0
        );
      });

      describe('alive()', () => {
        it('returns true when a plant is alive less time than GROWTH_CYCLE', async () => {
          const alive = await cryptorchidsContract.alive(tokenId - 1);
          expect(alive).to.eq(true);
        });

        it('returns true when a plant is in WATERING_WINDOW', async () => {
          await cryptorchidsContract.timeTravel(
            GROWTH_CYCLE_MS.add(WATERING_WINDOW_MS.sub(60_000)).div(1000)
          );

          const alive = await cryptorchidsContract.alive(tokenId - 1);
          expect(alive).to.eq(true);
        });

        it('returns false when a plant is past WATERING_WINDOW', async () => {
          await cryptorchidsContract.timeTravel(
            GROWTH_CYCLE_MS.add(WATERING_WINDOW_MS.add(60_000)).div(1000)
          );

          const alive = await cryptorchidsContract.alive(tokenId - 1);
          expect(alive).to.eq(false);
        });
      });

      it('Allows an owner to water', async function () {
        const transaction = await account.CryptOrchidERC721.water(tokenId);
        transaction.wait();
        const waterLevel = await cryptorchidsContract.waterLevel(0);
        expect(waterLevel).to.eq(1);
      });
    });
  });
});
