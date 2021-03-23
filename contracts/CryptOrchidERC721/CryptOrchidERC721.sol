// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract WaterLevel {
    mapping (uint256 => uint256) public waterLevel;
}

contract CryptOrchidERC721 is ERC721PresetMinterPauserAutoId, WaterLevel, Ownable, VRFConsumerBase {
    using SafeMath for uint256;
    using Strings for string;
    using Counters for Counters.Counter;
   
    struct CryptOrchid {
        string species;
        uint256 plantedAt;
    }

    uint16[10] private limits = [3074, 6074, 8074, 9074, 9574, 9824, 9924, 9974, 9999, 10000];
    string[10] private genum = [
        "phalaenopsis micholitzii",
        "guarianthe aurantiaca",
        "vanda coerulea",
        "cypripedium calceolus",
        "paphiopedilum vietnamense",
        "miltonia kayasimae",
        "platanthera azorica",
        "dendrophylax lindenii",
        "paphiopedilum rothschildianum",
        "shenzhenica orchidaceae"
    ];
    
    CryptOrchid[] public cryptorchids;
    Counters.Counter private _tokenIds;
    uint256 private wateringPeriod = 18000; // 60 minutes
    uint256 private wateringWindow = 300; // 5 minutes
    address payable public creator;

    bytes32 internal keyHash;
    uint256 internal vrfFee;
    uint256 public randomResult;
    address public VRFCoordinator;
    address public LinkToken;

    event RequestedRandomness(bytes32 requestId);

    mapping(bytes32 => address) public requestToSender;
    mapping(bytes32 => uint256) public requestToPlantedAt;

    constructor(address _VRFCoordinator, address _LinkToken, bytes32 _keyhash)
        public
        payable
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721PresetMinterPauserAutoId(
            "CryptOrchids",
            "ORCHD",
            "https://cryptorchids.io/token/"
        )
    {
        creator = msg.sender;
        VRFCoordinator = _VRFCoordinator;
        LinkToken = _LinkToken;
        keyHash = _keyhash;
        vrfFee = 0.1 * 10**18; // 0.1 LINK
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        require(address(0) == to || alive(tokenId - 1, now), "Dead CryptOrchids cannot be transferred");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    receive() external payable {}
    function webMint(uint256 seed) public payable {
        if (msg.value >= 10000000000000000){
            requestNewRandomBulb(msg.sender, seed);
            creator.transfer(msg.value);
        }   
    }

    function requestNewRandomBulb(address _addr, uint256 userProvidedSeed) internal returns (bytes32 requestId) {
        require(totalSupply() < 10000, "None left");
        require(
            LINK.balanceOf(address(this)) >= vrfFee,
            "Not enough LINK - fill contract with faucet"
        );

        requestId = requestRandomness(keyHash, vrfFee, userProvidedSeed);

        requestToSender[requestId] = _addr;
        requestToPlantedAt[requestId] = block.timestamp;
        
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256 randomKey = (randomness % 10000) + 1;
        cryptorchids.push(
            CryptOrchid({
                species: pickSpecies(randomKey),
                plantedAt: requestToPlantedAt[requestId]
            })
        );

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        address sender = address(requestToSender[requestId]);
        console.log("Sender", sender);
        _safeMint(sender, newItemId);   
    }

    function alive(uint256 index, uint currentTime) public view returns (bool) {
        uint256 currentWaterLevel = waterLevel[index];
        uint256 elapsed = currentTime - cryptorchids[index].plantedAt;
        uint fullCycles = uint(elapsed) / wateringPeriod;
        uint256 modulo = elapsed % wateringPeriod;

        if (currentWaterLevel == fullCycles) {
            return true;
        }

        if (currentWaterLevel + 1 == fullCycles && modulo < wateringWindow) {
            return true;
        }

        return false;
    }

    function water(uint256 index, uint currentTime) public returns (string memory) {
        if (msg.sender != ownerOf(index)) {
            return "Only the Owner can water a CryptOrchid.";
        } 
        
        if (!alive(index, currentTime)) {
            return "This CryptOrchid wasn't watered in time and couldn't be saved";
        }

        uint256 wateringLevel = waterLevel[index];
        uint256 elapsed = currentTime - cryptorchids[index].plantedAt;
        uint fullCycles = uint(elapsed) / wateringPeriod;

        if (wateringLevel > fullCycles) {
            return "You watered your CryptOrchid too soon!";
        }

        uint256 newWaterLevel = wateringLevel + 1;
        waterLevel[index] = newWaterLevel;

        return "Watered Successfully!";
    }

    function getTokenMetadata(uint256 tokenId)
        public
        view
        returns (
            string memory,
            uint256
        )
    {
        return (
            cryptorchids[tokenId].species,
            cryptorchids[tokenId].plantedAt
        );
    }

    /**
     * @notice Pick species for random number index
     * @param randomIndex uint256
     * @return species string
     */
    function pickSpecies(uint256 randomIndex) private view returns (string memory)  {
        for (uint i=0; i<10; i++) {
            if(randomIndex <= limits[i]) {
                return genum[i];
            }
        }
    }
}
