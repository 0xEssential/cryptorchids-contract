import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {deploymentForEnv} from '../utils/network';

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

  const {address} = deploymentForEnv(networkName);

  console.warn(address);

  const {deployer} = await getNamedAccounts();

  await deploy('Coupon', {
    from: deployer,
    args: [address],
    log: true,
  });
};
export default func;
func.tags = ['CryptOrchidsCoupon'];
