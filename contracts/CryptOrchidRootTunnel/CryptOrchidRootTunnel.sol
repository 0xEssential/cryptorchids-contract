// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6 <0.9.0;

import {FxBaseRootTunnel} from "../Libraries/tunnel/FxBaseRootTunnel.sol";

interface CryptOrchidParent {
    enum Stage {Unsold, Seed, Flower, Dead}

    function getTokenMetadata(uint256 tokenId)
        external
        view
        returns (
            string memory,
            uint256,
            uint256,
            Stage
        );
}

/**
 * @title CryptOrchidRootTunnel
 */
contract CryptOrchidRootTunnel is FxBaseRootTunnel {
    bytes public latestData;
    address public CryptOrchidERC721;

    constructor(
        address _checkpointManager,
        address _fxRoot,
        address _CryptOrchidERC721
    ) public FxBaseRootTunnel(_checkpointManager, _fxRoot) {
        CryptOrchidERC721 = _CryptOrchidERC721;
    }

    function _processMessageFromChild(bytes memory data) internal override {
        latestData = data;
        uint256 tokenId = abi.decode(data, (uint256));
        sendMessageToChild(tokenId);
    }

    function sendMessageToChild(uint256 tokenId) public {
        // TODO:
        // 1. check owner?

        (string memory species, uint256 plantedAt, uint256 waterLevel, ) = CryptOrchidParent(CryptOrchidERC721)
            .getTokenMetadata(tokenId);

        bytes memory message = abi.encode(species, plantedAt, waterLevel, tokenId);

        _sendMessageToChild(message);
    }
}
