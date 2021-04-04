import 'dotenv/config';
import {ethers} from 'hardhat';
import '@nomiclabs/hardhat-ethers';
import {address, abi} from '../deployments/rinkeby/CryptOrchidERC721.json';

async function main() {
  const accounts = await ethers.getSigners();
  const CryptOrchidsContract = await ethers.getContractAt(
    abi,
    address,
    accounts[0]
  );

  const ownedCount = await CryptOrchidsContract.balanceOf(accounts[0].address);

  for (let index = 0; index < ownedCount.toNumber(); index++) {
    const token = await CryptOrchidsContract.tokenOfOwnerByIndex(
      accounts[0].address,
      index
    );
    const gas = await CryptOrchidsContract.estimateGas.water(token);

    await CryptOrchidsContract.water(token, {
      gasLimit: Math.max(
        gas.toNumber(),
        parseInt(process.env.GAS_LIMIT || '0') // set a GAS_LIMIT env var to limit gas used
      ),
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
