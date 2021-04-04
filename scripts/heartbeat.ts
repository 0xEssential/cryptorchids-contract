import 'dotenv/config';
import {ethers} from 'hardhat';
import '@nomiclabs/hardhat-ethers';
import {address, abi} from '../deployments/rinkeby/CryptOrchidERC721.json';

import {request, gql} from 'graphql-request';
import {Contract} from 'hardhat/internal/hardhat-network/stack-traces/model';
import {CryptOrchidERC721} from '../typechain';

const query = gql`
  {
    cryptOrchids(
      first: 100
      orderBy: plantedAt
      orderDirection: asc
      where: {growthStage: FLOWERING}
    ) {
      id
      tokenId
      owner
      latinSpeciesName
      plantedAt
      growthStage
    }
  }
`;

async function checkHeartbeat(
  tokenId: string,
  contract: CryptOrchidERC721,
  nonce
) {
  console.warn(tokenId);
  return contract.heartbeat(tokenId, {
    nonce,
  });
}

async function main() {
  const accounts = await ethers.getSigners();
  const CryptOrchidsContract = await ethers.getContractAt(
    abi,
    address,
    accounts[0]
  );

  const baseNonce = ethers.provider.getTransactionCount(accounts[0].address);
  let nonceOffset = 0;
  const getNonce = () => baseNonce.then((nonce) => nonce + nonceOffset++);

  return request(
    'https://api.thegraph.com/subgraphs/name/sbauch/crypt-orchids',
    query
  ).then((data) => {
    return Promise.all(
      data?.cryptOrchids?.map(({tokenId}) =>
        checkHeartbeat(
          tokenId,
          CryptOrchidsContract as CryptOrchidERC721,
          getNonce()
        )
      )
    );
  });
}

main()
  .then((result) => {
    console.log(result);
    return process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
