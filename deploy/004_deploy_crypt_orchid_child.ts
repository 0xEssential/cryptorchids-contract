import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {chainlinkEnv} from '../utils/network';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, getChainId} = hre;
  const {deploy} = deployments;
  const networkName = await getChainId().then(
    (id) =>
      ({
        137: 'matic',
        80001: 'mumbai',
      }[id])
  );

  console.warn(networkName);

  if (!networkName) return; // ONLY goerli

  const {deployer} = await getNamedAccounts();
  console.warn(deployer);

  await deploy('CryptOrchidERC721Child', {
    from: deployer,
    args: ['0xb5505a6d998549090530911180f38aC5130101c6'],
    log: true,
  });
};
export default func;
func.tags = ['CryptOrchidERC721Child'];
