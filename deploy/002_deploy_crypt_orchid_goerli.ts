import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {chainlinkEnv} from '../utils/network';

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

  await deploy('CryptOrchidGoerli', {
    from: deployer,
    args: [],
    log: true,
  });
};
export default func;
func.tags = ['CryptOrchidGoerli'];
