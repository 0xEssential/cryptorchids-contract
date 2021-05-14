import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {chainlinkEnv} from '../utils/network';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // const {deployments, getNamedAccounts, getChainId} = hre;
  // const {deploy} = deployments;
  // const networkName = await getChainId().then(
  //   (id) =>
  //     ({
  //       42: 'kovan',
  //       4: 'rinkeby',
  //       1: 'mainnet',
  //     }[id])
  // );
  // const chainLink = chainlinkEnv(networkName);
  // const {deployer} = await getNamedAccounts();
  // console.warn(deployer);
  // await deploy('CryptOrchidERC721', {
  //   from: deployer,
  //   args: [chainLink.VRF_COORDINATOR, chainLink.LINKTOKEN, chainLink.KEYHASH],
  //   log: true,
  // });
};
export default func;
func.tags = ['CryptOrchidERC721'];
