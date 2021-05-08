import chai, {expect} from './chai-setup';
import {chunk} from 'lodash';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {setupUsers} from './utils';
import {add, compareAsc} from 'date-fns';
import {BigNumber, Contract} from 'ethers';
import {SignerWithAddress} from 'hardhat-deploy-ethers/dist/src/signer-with-address';

const keyhash =
  '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4';

const numberBetween = (min: number, max: number) =>
  Math.floor(Math.random() * (max - min + 1)) + min;

describe('CryptOrchidERC721', function () {
  describe('Coupon', function () {
    const setup = deployments.createFixture(async () => {
      const [owner] = await ethers.getSigners();

      const MockLink = await ethers.getContractFactory('MockLink');
      const VRFCoordinatorMock = await ethers.getContractFactory(
        'VRFCoordinatorMock'
      );
      const link = await MockLink.deploy();
      const vrfCoordinatorMock = await VRFCoordinatorMock.deploy(link.address);

      const CryptOrchidERC721 = await ethers.getContractFactory(
        'CryptOrchidsMock'
      );

      const CryptOrchids = await CryptOrchidERC721.deploy(
        vrfCoordinatorMock.address,
        link.address,
        keyhash
      );

      await link.transfer(CryptOrchids.address, '10000000000000000000');

      const CouponContract = await ethers.getContractFactory('CouponMock');

      const Coupon = await CouponContract.deploy(CryptOrchids.address);
      const address = await Coupon.resolvedAddress;

      const tx = await owner.sendTransaction({
        to: address,
        value: ethers.utils.parseEther('1.0'),
      });

      await tx.wait();

      const contracts = {
        CryptOrchidERC721: CryptOrchids,
        VRFCoordinatorMock: vrfCoordinatorMock,
        Coupon,
      };

      const users = await setupUsers(await getUnnamedAccounts(), contracts);

      await CryptOrchids.startSale();
      await CryptOrchids.startGrowing();

      const account = users[0];
      const units = numberBetween(3, 8);
      const tokenIds = await webMint(account, units);
      const germinateCount = numberBetween(1, 3);

      for (let index = 0; index < germinateCount; index++) {
        await germinate(account, tokenIds[index]);
      }

      return {
        ...contracts,
        users,
        owner,
        germinateCount,
      };
    });

    const webMint = async (account: ContractUser, units: number) => {
      const transaction = await account.CryptOrchidERC721.webMint(units, {
        value: ethers.utils.parseUnits('0.04', 'ether').mul(units),
      });

      await transaction.wait();
      const ids = [];
      for (let index = 0; index < units; index++) {
        ids.push(
          await account.CryptOrchidERC721.tokenOfOwnerByIndex(
            account.address,
            index
          )
        );
      }

      return ids;
    };

    const germinate = async (
      account: ContractUser,
      tokenId: number,
      pseudoRandom = numberBetween(0, 10_000)
    ) => {
      const transaction = await account.CryptOrchidERC721.germinate(
        tokenId,
        pseudoRandom
      );

      const tx_receipt = await transaction.wait();
      const requestIds = chunk(tx_receipt.events, 4).reduce(
        (acc, chunk) => [...acc, chunk[3].data],
        []
      );

      return await Promise.all(
        requestIds.map(
          async (requestId) =>
            await account.VRFCoordinatorMock.callBackWithRandomness(
              requestId,
              pseudoRandom,
              account.CryptOrchidERC721.address
            )
        )
      );
    };

    interface ContractUser {
      address: string;
      Coupon: Contract;
      CryptOrchidERC721: Contract;
      VRFCoordinatorMock: Contract;
    }
    let fixtures: {
      owner: SignerWithAddress;
      users: ContractUser[];
      Coupon: Contract;
      germinateCount: number;
    };
    describe('redemption flow', function () {
      before(async () => {
        fixtures = await setup();
      });

      it('reports the right eligibility for eligible tokens', async () => {
        const {
          users: [account],
          germinateCount,
        } = fixtures;

        const {
          rebateAmount,
          eligibleTokens,
        } = await account.Coupon.checkEligibility();

        const eligibleIds = eligibleTokens.reduce(
          (acc, n) => (n.toNumber() ? [...acc, n.toNumber()] : acc),
          []
        );

        expect(eligibleIds.length).to.equal(germinateCount);
        expect(rebateAmount).to.equal(
          ethers.utils.parseEther('0.02').mul(germinateCount)
        );
      });

      it('redeems the right eth for eligible tokens', async () => {
        const {
          germinateCount,
          users: [account],
        } = fixtures;

        const tx = await account.Coupon.redeem();
        const receipt = await tx.wait();

        expect(receipt.events[0].args.rebate).to.equal(
          ethers.utils.parseEther('0.02').mul(germinateCount)
        );
      });

      it('reports no eligibility for redeemed tokens', async () => {
        const {
          users: [account],
        } = fixtures;

        const {
          rebateAmount,
          eligibleTokens,
        } = await account.Coupon.checkEligibility();

        const eligibleIds = eligibleTokens.reduce(
          (acc, n) => (n.toNumber() ? [...acc, n.toNumber()] : acc),
          []
        );

        expect(eligibleIds.length).to.equal(0);
        expect(rebateAmount).to.equal(ethers.utils.parseEther('0'));
      });

      it('redeems no eth for redeemed tokens', async () => {
        const {
          users: [account],
        } = fixtures;

        const tx = await account.Coupon.redeem();
        const receipt = await tx.wait();

        expect(receipt.events[0].args.rebate).to.equal(
          ethers.utils.parseEther('0')
        );
      });
    });
  });
});
