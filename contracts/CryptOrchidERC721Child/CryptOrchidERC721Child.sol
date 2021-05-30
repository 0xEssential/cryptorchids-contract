// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import {CryptOrchidGoerli} from "../CryptOrchidGoerli/CryptOrchidGoerli.sol";
import {AccessControlMixin} from "../Libraries/matic/common/AccessControlMixin.sol";
import {IChildToken} from "../Libraries/matic/child/ChildToken/IChildToken.sol";
import {NativeMetaTransaction} from "../Libraries/matic/common/NativeMetaTransaction.sol";
import {ContextMixin} from "../Libraries/matic/common/ContextMixin.sol";
import {FxBaseChildTunnel} from "../Libraries/tunnel/FxBaseChildTunnel.sol";

contract CryptOrchidERC721Child is
    CryptOrchidGoerli,
    IChildToken,
    AccessControlMixin,
    NativeMetaTransaction,
    ContextMixin,
    FxBaseChildTunnel
{
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    // limit batching of tokens due to gas limit restrictions
    uint256 public constant BATCH_LIMIT = 20;

    event WithdrawnBatch(address indexed user, uint256[] tokenIds);
    event TransferWithMetadata(address indexed from, address indexed to, uint256 indexed tokenId, bytes metaData);

    constructor(address childChainManager, address _fxChild) public CryptOrchidGoerli() FxBaseChildTunnel(_fxChild) {
        _setupContractId("CryptOrchidERC721Child");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, childChainManager);
        _initializeEIP712("CryptOrchids");
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address payable sender) {
        return ContextMixin.msgSender();
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required tokenId for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded tokenId
     */
    function deposit(address user, bytes calldata depositData) external override only(DEPOSITOR_ROLE) {
        // deposit single
        if (depositData.length == 32) {
            uint256 tokenId = abi.decode(depositData, (uint256));
            _mint(user, tokenId);

            // deposit batch
        } else {
            uint256[] memory tokenIds = abi.decode(depositData, (uint256[]));
            uint256 length = tokenIds.length;
            for (uint256 i; i < length; i++) {
                _mint(user, tokenIds[i]);
            }
        }
    }

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory data
    ) internal override validateSender(sender) {
        (string memory species, uint256 plantedAt, uint256 waterLevel, uint256 tokenId) = abi.decode(
            data,
            (string, uint256, uint256, uint256)
        );

        require(cryptorchids[tokenId].plantedAt == 0, "Metdata already transferred");

        cryptorchids[tokenId] = CryptOrchid({species: species, plantedAt: plantedAt, waterLevel: waterLevel});
    }

    function sendMessageToRoot(bytes memory message) public {
        _sendMessageToRoot(message);
    }
}
