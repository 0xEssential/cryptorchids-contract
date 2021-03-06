import chai, {expect} from './chai-setup';
import {chunk} from 'lodash';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {setupUsers} from './utils';
import {BigNumber, Contract} from 'ethers';
import {SignerWithAddress} from 'hardhat-deploy-ethers/dist/src/signer-with-address';

const keyhash =
  '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4';

const numberBetween = (min: number, max: number) =>
  Math.floor(Math.random() * (max - min + 1)) + min;

describe.only('CryptOrchidERC721', function () {
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

      const CouponContract = await ethers.getContractFactory('CouponMock');

      await link.transfer(CryptOrchids.address, '80000000000000000000');

      const Coupon = await CouponContract.deploy(
        CryptOrchids.address,
        vrfCoordinatorMock.address,
        link.address,
        keyhash
      );

      const contracts = {
        CryptOrchidERC721: CryptOrchids,
        VRFCoordinatorMock: vrfCoordinatorMock,
        Coupon,
      };

      const users = await setupUsers(await getUnnamedAccounts(), contracts);

      await CryptOrchids.startSale();
      await CryptOrchids.startGrowing();

      const account = users[0];
      const units = 4; //numberBetween(3, 8);
      const tokenIds = await webMint(account, units);
      const germinateCount = 2; //numberBetween(1, 3);

      for (let index = 0; index < germinateCount; index++) {
        await germinate(account, tokenIds[index]);
      }

      // second user has 2 tokens to assert balance overflow
      const secondTokenIds = await webMint(users[1], 2);
      for (let index = 0; index < 2; index++) {
        await germinate(users[1], secondTokenIds[index]);
      }
      // third user has 1 tokens to assert balance exhaustion
      const thirdTokenIds = await webMint(users[2], 1);
      await germinate(users[2], thirdTokenIds[0]);

      return {
        ...contracts,
        users,
        owner,
        germinateCount,
        link,
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
      link: Contract;
      CryptOrchidERC721: Contract;
      VRFCoordinatorMock: Contract;
    };

    describe('redemption flow', function () {
      before(async () => {
        fixtures = await setup();

        const tx = await fixtures.owner.sendTransaction({
          to: fixtures.Coupon.address,
          value: ethers.utils.parseEther('2.0'),
        });

        await tx.wait();
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

        expect(account.Coupon.redeem()).to.be.reverted;
      });

      it('does not increment the pot for redeemed tokens', async () => {
        const {
          users: [account],
        } = fixtures;

        await account.Coupon.enter();

        const pot = await account.Coupon.pot();

        expect(pot).to.equal(0);
      });

      it('adds no entry for redeemed tokens', async () => {
        const {
          users: [account],
        } = fixtures;

        const entries = await account.Coupon.addressEntriesCount();

        expect(entries).to.equal(0);
      });
    });

    describe('entry flow', function () {
      before(async () => {
        fixtures = await setup();
        const tx = await fixtures.owner.sendTransaction({
          to: fixtures.Coupon.address,
          value: ethers.utils.parseEther('2.0'),
        });

        await tx.wait();
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

      it('increments the pot for eligible tokens', async () => {
        const {
          germinateCount,
          users: [account],
        } = fixtures;

        await account.Coupon.enter();

        const pot = await account.Coupon.pot();

        expect(pot).to.equal(
          ethers.utils.parseEther('0.02').mul(germinateCount)
        );
      });

      it('adds entry per eligible tokens', async () => {
        const {
          germinateCount,
          users: [account],
        } = fixtures;

        const entries = await account.Coupon.addressEntriesCount();

        expect(entries).to.equal(germinateCount);
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

        expect(account.Coupon.redeem()).to.be.reverted;
      });

      it('does not increment the pot for redeemed tokens', async () => {
        const {
          germinateCount,
          users: [account],
        } = fixtures;

        await account.Coupon.enter();

        const pot = await account.Coupon.pot();

        expect(pot).to.equal(
          ethers.utils.parseEther('0.02').mul(germinateCount)
        );
      });

      it('adds no entry for redeemed tokens', async () => {
        const {
          germinateCount,
          users: [account],
        } = fixtures;

        const entries = await account.Coupon.addressEntriesCount();

        expect(entries).to.equal(germinateCount);
      });
    });

    describe('limits', function () {
      describe('for drawing entry', function () {
        before(async () => {
          fixtures = await setup();

          const tx = await fixtures.owner.sendTransaction({
            to: fixtures.Coupon.address,
            value: ethers.utils
              .parseEther('0.02')
              .mul(fixtures.germinateCount + 1),
          });

          await tx.wait();

          // 1 entry remaining, second account has 2
          await fixtures.users[0].Coupon.enter();
        });
        it('does not increment the pot beyond safeBalance', async () => {
          const {
            germinateCount,
            users: [_redeemed, account],
          } = fixtures;
          await account.Coupon.enter();
          const pot = await account.Coupon.pot();

          expect(pot).to.equal(
            ethers.utils.parseEther('0.02').mul(germinateCount + 1)
          );
        });

        it('does not add entries if the pot would exceed safeBalance', async () => {
          const {
            germinateCount,
            users: [_redeemed, account],
          } = fixtures;

          const entries = await account.Coupon.addressEntriesCount();
          const pot = await account.Coupon.pot();

          expect(entries).to.equal(1);
          expect(pot).to.equal(
            ethers.utils.parseEther('0.02').mul(germinateCount + 1)
          );
        });

        it('prevents redemptions if total redemption would exceed safeBalance', async () => {
          const {
            users: [_redeemed, account],
          } = fixtures;

          expect(account.Coupon.redeem()).to.be.reverted;
        });

        it('does not increment the pot if addition would exhaust safeBalance', async () => {
          const {
            germinateCount,
            users: [redeemed, exceeded, account],
          } = fixtures;

          await account.Coupon.enter();

          const pot = await account.Coupon.pot();

          expect(pot).to.equal(
            ethers.utils.parseEther('0.02').mul(germinateCount + 1)
          );
        });

        it('does not add entry that exhausts safeBalance', async () => {
          const {
            users: [redeemed, exceeded, account],
          } = fixtures;

          const entries = await account.Coupon.addressEntriesCount();

          expect(entries).to.equal(0);
        });
      });

      describe('for redemption', function () {
        before(async () => {
          fixtures = await setup();
          const tx = await fixtures.owner.sendTransaction({
            to: fixtures.Coupon.address,
            value: ethers.utils
              .parseEther('0.02')
              .mul(fixtures.germinateCount + 1),
          });

          await tx.wait();

          // 1 entry remaining, second account has 2
          await fixtures.users[0].Coupon.enter();
        });
        it('reports the right eligibility for exhausting contract', async () => {
          const {
            users: [_redeemed, account],
          } = fixtures;

          const {
            rebateAmount,
            eligibleTokens,
          } = await account.Coupon.checkEligibility();

          const eligibleIds = eligibleTokens.reduce(
            (acc, n) => (n.toNumber() ? [...acc, n.toNumber()] : acc),
            []
          );

          expect(eligibleIds.length).to.equal(1);
          expect(rebateAmount).to.equal(ethers.utils.parseEther('0.02'));
        });

        it('redeems the right eth for exhausting contract', async () => {
          const {
            users: [_redeemed, account],
          } = fixtures;

          const tx = await account.Coupon.redeem();
          const receipt = await tx.wait();

          expect(receipt.events[0].args.rebate).to.equal(
            ethers.utils.parseEther('0.02')
          );
        });

        it('redeems no eth beyond safeBalance', async () => {
          const {
            users: [_redeemed, _redeemedAlso, account],
          } = fixtures;

          expect(account.Coupon.redeem()).to.be.reverted;
        });
      });
    });

    describe('winner selection', function () {
      let requestId;
      before(async () => {
        fixtures = await setup();
        const tx = await fixtures.owner.sendTransaction({
          to: fixtures.Coupon.address,
          value: ethers.utils.parseEther('0.02').mul(fixtures.germinateCount),
        });

        await tx.wait();

        await fixtures.users[0].Coupon.enter();
      });

      it('prevents winner selection before promotionEnd', async () => {
        const {
          users: [account],
        } = fixtures;

        expect(account.Coupon.selectWinner(42)).to.be.reverted;
      });

      it('prevents winner selection without LINK', async () => {
        const {
          users: [account],
          Coupon,
        } = fixtures;

        await Coupon.timeTravel(new Date(2021, 5, 1).getTime() - Date.now());

        expect(account.Coupon.selectWinner(42)).to.be.reverted;
      });

      it('allows winner selection after promotionEnd with LINK', async () => {
        const {
          users: [account],
          Coupon,
          link,
        } = fixtures;

        await link.transfer(Coupon.address, '2000000000000000000');

        const tx = await account.Coupon.selectWinner(42);

        const receipt = await tx.wait();
        requestId = receipt.events[3].args.requestId;
        expect(requestId).to.not.be.null;
      });

      it('does not allow a second winner selection', async () => {
        const {
          users: [account],
          Coupon,
          link,
        } = fixtures;

        await link.transfer(Coupon.address, '2000000000000000000');
        expect(account.Coupon.selectWinner(42)).to.be.reverted;
      });

      it('sets a winner', async () => {
        const {
          users: [account],
          Coupon,
          VRFCoordinatorMock,
        } = fixtures;

        const callback = await VRFCoordinatorMock.callBackWithRandomness(
          requestId,
          numberBetween(0, 10_000),
          Coupon.address
        );

        await callback.wait();

        const winner = await account.Coupon.winner();

        expect(winner).to.equal(account.address);
      });

      it('does not allow non winner to withdraw', async () => {
        const {
          users: [winner, nonWinner],
        } = fixtures;

        expect(nonWinner.Coupon.withdrawWinner()).to.be.reverted;
      });

      it('prevents owner from withdrawing before winner', async () => {
        const {Coupon, owner} = fixtures;

        const contractOwner = Coupon.connect(owner);

        expect(contractOwner.withdrawWinner()).to.be.reverted;
      });

      it('allows winner to withdraw', async () => {
        const {
          users: [winner],
        } = fixtures;

        const tx = await winner.Coupon.withdrawWinner();
        await tx.wait();

        const pot = await winner.Coupon.pot();

        expect(pot).to.equal(0);
      });

      it('allows owner to withdraw extra funds', async () => {
        const {Coupon, owner} = fixtures;

        const contractOwner = Coupon.connect(owner);
        const tx = await contractOwner.withdrawUnclaimed();
        await tx.wait();

        const balance = await owner.provider.getBalance(Coupon.address);

        expect(balance).to.equal(BigNumber.from(0));
      });

      it('allows owner to reset', async () => {
        const {Coupon, owner} = fixtures;

        const newPromotionEnd = new Date(2021, 6, 1).getTime();
        const contractOwner = Coupon.connect(owner);
        await contractOwner.reset(newPromotionEnd);

        await owner.sendTransaction({
          to: Coupon.address,
          value: ethers.utils.parseEther('2.0'),
        });

        const open = await contractOwner.promotionOpen();
        const pot = await contractOwner.pot();

        expect(open).to.equal(true);
        expect(pot).to.equal(0);
      });

      // tokens don't reset - the internal `redemptions` mapping remains intact
      it('redeems no eth for redeemed tokens', async () => {
        const {
          users: [account],
        } = fixtures;

        expect(account.Coupon.redeem()).to.be.reverted;
      });

      it('redeems eth for unredeemed tokens', async () => {
        const {
          users: [_re, _deemed, account],
        } = fixtures;

        const tx = await account.Coupon.redeem();
        const receipt = await tx.wait();

        expect(receipt.events[0].args.rebate).to.equal(
          ethers.utils.parseEther('0.02')
        );
      });

      it('allows a second winner selection after promotionEnd with LINK', async () => {
        const {
          users: [account],
          Coupon,
          link,
        } = fixtures;
        await Coupon.timeTravel(
          new Date(2021, 7, 2).getTime() * 1000 - new Date().getTime() * 1000
        );
        await link.transfer(Coupon.address, '2000000000000000000');

        const tx = await account.Coupon.selectWinner(42);

        const receipt = await tx.wait();
        requestId = receipt.events[3].args.requestId;
        expect(requestId).to.not.be.null;
      });
    });
  });
});
