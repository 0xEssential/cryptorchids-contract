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
      }[id])
  );

  if (!networkName) return; // ONLY goerli

  const {deployer} = await getNamedAccounts();
  console.warn(deployer);

  const {
    address,
    // eslint-disable-next-line @typescript-eslint/no-var-requires
  } = require(`../deployments/${networkName}/CryptOrchidGoerli.json`);

  await deploy('CryptOrchidRootTunnel', {
    from: deployer,
    args: [
      '0x2890bA17EfE978480615e330ecB65333b880928e',
      '0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA',
      address,
    ],
    log: true,
  });
};
export default func;
func.tags = ['CryptOrchidRootTunnel'];
