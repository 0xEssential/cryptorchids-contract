import 'dotenv/config';
import {ethers} from 'hardhat';
import '@nomiclabs/hardhat-ethers';
import {address, abi} from '../deployments/mainnet/CryptOrchidERC721.json';

async function main() {
  const accounts = await ethers.getSigners();
  const CryptOrchidsContract = await ethers.getContractAt(
    abi,
    address,
    accounts[0]
  );

  const result = await CryptOrchidsContract.withdraw();

  console.log(result);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
