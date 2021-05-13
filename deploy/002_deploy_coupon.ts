import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {chainlinkEnv, deploymentForEnv} from '../utils/network';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, getChainId} = hre;
  const {deploy} = deployments;
  const networkName = await getChainId().then(
    (id) =>
      ({
        42: 'kovan',
        4: 'rinkeby',
        1: 'mainnet',
      }[id])
  );

  if (!networkName) return; // no goerli

  const {address} = deploymentForEnv(networkName);
  const chainLink = chainlinkEnv(networkName);

  const {deployer} = await getNamedAccounts();

  await deploy('Coupon', {
    from: deployer,
    args: [
      address,
      chainLink.VRF_COORDINATOR,
      chainLink.LINKTOKEN,
      chainLink.KEYHASH,
    ],

    log: true,
  });
};
export default func;
func.tags = ['CryptOrchidsCoupon'];
