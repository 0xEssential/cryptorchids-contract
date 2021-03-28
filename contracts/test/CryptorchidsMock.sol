pragma solidity >=0.6.6 <0.9.0;
import "hardhat/console.sol";

import "../CryptOrchidERC721/CryptOrchidERC721.sol";

contract CryptOrchidsMock is CryptOrchidERC721 {
    uint256 internal secondsToAdd = 0;

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash
    ) public CryptOrchidERC721(_VRFCoordinator, _LinkToken, _keyhash) {}

    function timeTravel(uint256 s) public {
        secondsToAdd = s;
    }

    function currentTime() internal view virtual override returns (uint256) {
        return block.timestamp + secondsToAdd;
    }
}
