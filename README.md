# CryptOrchids Contract

This repo contains the Solidity smart contract code for [CryptOrchids](https://cryptorchids.io), the NFT based game where CryptOrchid growers must water their flower every 7 days, or else it dies and cannot be sold, destroying it's secondary market value.

The best place to verify the code is via Etherscan. The [CryptOrchids website](https://cryptorchids.io) has a footer link to the contract on Etherscan where the source code has been uploaded and validated. Follow that link to ensure you are viewing the right repository - the same contract address used in the footer is the contract you interact with on the CryptOrchids website.

This repository exists primarily to maintain an open ethos, but we also felt it was important to show the test suite for the contract such that players can be assured that the game functions as we describe.

See the test suite at [test/CryptOrchidERC721.test.ts](/test/CryptOrchidERC721.test.ts). You can also verify that they run and pass under the Actions tab.

## Chainlink Hackathon

This project was initially developed for the Chainlink Spring 2021 hackathon. A project description and demo video are included as submission materials.

The project is submitted for Chainlink prizes (using VRF) as well as The Graph prizes under NFTs. This is also my first smart contract or blockchain related project, and my dApp code is terrible so I would very much appreciate being given a dApp University course! I also bought 500 LINK so yeah a free one would be great.

### Project description

CryptOrchids is a lightweight game where you grow flowers on the Ethereum blockchain. CryptOrchids are extremely sensitive and must be watered every 7 days. CryptOrchids are limited to 10k tokens, cannot be sold if they die, and come in 10 different species, with species assignment being randomized through Chainlink VRF.

New gardeners can mint Seed Tokens - we opened our Seed Round on April 7 with prices starting at 0.04ETH and increasing according to a bonding curve. Germinating a seed determines the species and starts the game, requiring you to water your CryptOrchid every 7 days within a 3 hour window. All of the game data is stored on-chain, so germinating and watering a CryptOrchid does cost some gas.

CryptOrchid watering can be automated via an open source Hardhat script or by calling the CryptOrchids contract directly.

If you fail to water your CryptOrchid in time, it enters a Dead state. Dead CryptOrchids cannot be transferred.

Dead CryptOrchids can be composted - this burns the token, decreasing the overall supply, and allowing a new seed to be minted.

The CryptOrchids dApp makes use of a TheGraph subgraph which indexes Flower entities. This allows us to much more easily construct a leaderboard feature of the longest living CryptOrchids.

### Demo video

Please note that the demo video uses Rinkeby. I've launched on Ethereum mainnet, but I won't allow seed germination until after the submission deadline, so in order to demo the whole experience we'll use Rinkeby. But! If you're reading this as a judge, you can buy seeds and germination opened April 12 at 12EDT.

### Links

- dApp website <https://cryptorchids.io>
- [verified contract on Etherscan](https://etherscan.io/address/0x941ee2e831d278DB802A541d3855A8de749ef635#code)
- [subgraph repo](https://github.com/sbauch/cryptorchids-subgraph)
- [subgraph playground](https://thegraph.com/explorer/subgraph/sbauch/crypt-orchids)
- [OpenSea](https://opensea.io/collection/cryptorchids)
- [Discord Community](https://discord.gg/ADFS4JAdTa)
- ["watering can" repo](https://github.com/sbauch/cryptorchids-watering-can)
- [OpenSea discord bot repo](https://github.com/sbauch/opensea-discord-bot)
