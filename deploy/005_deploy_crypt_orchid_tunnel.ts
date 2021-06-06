import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {chainlinkEnv, deploymentForEnv} from '../utils/network';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, getChainId} = hre;
  const {deploy} = deployments;
  const networkName = await getChainId().then(
    (id) =>
      ({
        5: 'goerli',
        1: 'mainnet',
      }[id])
  );

  if (!networkName) return;

  const {deployer} = await getNamedAccounts();
  console.warn(deployer);
  let args;

  if (networkName == 'goerli') {
    const {
      address,
      // eslint-disable-next-line @typescript-eslint/no-var-requires
    } = require(`../deployments/${networkName}/CryptOrchidGoerli.json`);

    args = [
      '0x2890bA17EfE978480615e330ecB65333b880928e',
      '0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA',
      address,
    ];
  }

  if (networkName == 'mainnet') {
    const {
      address,
      // eslint-disable-next-line @typescript-eslint/no-var-requires
    } = require(`../deployments/${networkName}/CryptOrchidERC721.json`);

    args = [
      '0x86e4dc95c7fbdbf52e33d563bbdb00823894c287',
      '0x941ee2e831d278DB802A541d3855A8de749ef635',
      address,
    ];
  }

  await deploy('CryptOrchidRootTunnel', {
    from: deployer,
    args,
    log: true,
  });
};
export default func;
func.tags = ['CryptOrchidRootTunnel'];
