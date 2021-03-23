// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

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
        string latinSpecies;
        uint256 plantedAt;
    }

    struct SpeciesGeneratedMetdata {
        string name;
        string latinName;
    }

    struct SpeciesRarity {
        SpeciesGeneratedMetdata metadata;
        uint256 maxIndex;
    }
    
    CryptOrchid[] public cryptorchids;
    Counters.Counter private _tokenIds;
    uint256 private wateringPeriod = 300; // 5 minutes
    uint256 private wateringWindow = 60; // 1 minute
    address payable public creator;

    bytes32 internal keyHash;
    uint256 internal vrfFee;
    uint256 public randomResult;
    address public VRFCoordinator;
    address public LinkToken;

    mapping(bytes32 => address) internal requestToSender;
    mapping(bytes32 => uint256) internal requestToPlantedAt;

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
        require(address(0) == to || alive(tokenId, now), "Dead CryptOrchids cannot be transferred");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    receive() external payable {}
    function webMint(uint256 seed) public payable {
        if (msg.value >= 10000000000000000){
            creator.transfer(msg.value);
            requestNewRandomBulb(seed);
        }   
    }

    function requestNewRandomBulb(uint256 userProvidedSeed) internal returns (bytes32) {
        require(totalSupply() < 10000, "None left");
        require(
            LINK.balanceOf(address(this)) >= vrfFee,
            "Not enough LINK - fill contract with faucet"
        );

        bytes32 requestId = requestRandomness(keyHash, vrfFee, userProvidedSeed);
        requestToSender[requestId] = msg.sender;
        requestToPlantedAt[requestId] = block.timestamp;

        return requestId;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        uint256 randomKey = (randomNumber % 10000) + 1;
        SpeciesGeneratedMetdata memory metadata = buildSpeciesMetadata(randomKey);

        cryptorchids.push(
            CryptOrchid({
                species: metadata.name,
                latinSpecies: metadata.latinName,
                plantedAt: requestToPlantedAt[requestId]
            })
        );
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(requestToSender[requestId], newItemId);   
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
            waterLevel[index] = 0;
            return "This CryptOrchid wasn't watered in time and couldn't be saved";
        }

        uint256 wateringLevel = waterLevel[index];
        uint256 elapsed = currentTime - cryptorchids[index].plantedAt;
        uint fullCycles = uint(elapsed) / wateringPeriod;

        if (wateringLevel > fullCycles) {
            waterLevel[index] = 0;
            return "You watered your CryptOrchid too soon!";
        }

        uint256 newWaterLevel = wateringLevel + 1;
        waterLevel[index] = newWaterLevel;

        return "Watered Successfully!";
    }

    // function metadataWater(uint256 index, uint currentTime) public returns (string memory) {
    //     if (msg.sender != ownerOf(index)) {
    //         return "Only the Owner can water a CryptOrchid.";
    //     } 
        
    //     if (!alive(index, currentTime)) {
    //         waterLevel[index] = 0;
    //         return "This CryptOrchid wasn't watered in time and couldn't be saved";
    //     }

    //     uint256 wateringLevel = waterLevel[index];
    //     uint256 elapsed = currentTime - cryptorchids[index].plantedAt;
    //     uint fullCycles = uint(elapsed) / wateringPeriod;

    //     if (wateringLevel > fullCycles) {
    //         waterLevel[index] = 0;
    //         return "You watered your CryptOrchid too soon!";
    //     }

    //     uint256 newWaterLevel = wateringLevel + 1;
    //     waterLevel[index] = newWaterLevel;

    //     return "Watered Successfully!";
    // }

    function getTokenMetadata(uint256 tokenId)
        public
        view
        returns (
            string memory,
            string memory,
            uint256
        )
    {
        return (
            cryptorchids[tokenId].species,
            cryptorchids[tokenId].latinSpecies,
            cryptorchids[tokenId].plantedAt
        );
    }

     /**
     * @notice Pick metadata for random number index
     * @param randomIndex uint256
     * @return randomMetadata SpeciesGeneratedMetdata
     */
    // function buildSpeciesMetadata(uint256 randomIndex) internal pure returns (SpeciesGeneratedMetdata memory)  {
    //     SpeciesRarity[10] memory speciesMap = [
    //         SpeciesRarity({ 
    //             maxIndex: 3074,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "White Moth",
    //                 latinName: "phalaenopsis micholitzii"
    //             })
    //         }),
    //         SpeciesRarity({ 
    //             maxIndex: 6074,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Orange Cattelya",
    //                 latinName: "guarianthe aurantiaca"
    //             } )
    //         }),
    //         SpeciesRarity({ 
    //             maxIndex: 8074,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Blue Vanda",
    //                 latinName: "vanda coerulea"
    //             })
    //         }),

    //         SpeciesRarity({ 
    //             maxIndex: 9074,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Yellow Lady's Slipper",
    //                 latinName: "cypripedium calceolus"
    //             })
    //         }),

    //         SpeciesRarity({ 
    //             maxIndex: 9574,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Vietnamese Paphiopedilum",
    //                 latinName: "paphiopedilum vietnamense"
    //             })
    //         }),

    //         SpeciesRarity({ 
    //             maxIndex: 9824,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Kayasima Miltonia",
    //                 latinName: "miltonia kayasimae"
    //             })
    //         }),
      
    //         SpeciesRarity({ 
    //             maxIndex: 9924,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Hochstetter's Butterfly Orchid",
    //                 latinName: "platanthera azorica"
    //             })
    //         }),

    //         SpeciesRarity({ 
    //             maxIndex: 9974,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Ghost Orchid",
    //                 latinName: "dendrophylax lindenii"
    //             })
    //         }),

    //         SpeciesRarity({ 
    //             maxIndex: 9999,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Gold of Kinabalu",
    //                 latinName: "paphiopedilum rothschildianum"
    //             })
    //         }),

    //         SpeciesRarity({ 
    //             maxIndex: 10000,
    //             metadata: SpeciesGeneratedMetdata({
    //                 name: "Shenzhen Nongke Orchid ",
    //                 latinName: "shenzhenica orchidaceae"
    //             })
    //         })
    //     ];

    //     SpeciesGeneratedMetdata memory randomMetadata = speciesMap[0].metadata;
    //     uint speciesMaxIndex = 3074;
        
    //     uint index = 0;
    //     while(randomIndex <= speciesMaxIndex){
    //         index++;
    //         randomMetadata = speciesMap[index].metadata;
    //         speciesMaxIndex = speciesMap[index].maxIndex;
    //     }

    //     return randomMetadata;
    // }

    function buildSpeciesMetadata(uint256 randomIndex) internal pure returns (SpeciesGeneratedMetdata memory)  {
    //    if (randomIndex <= 3074) {
           return SpeciesGeneratedMetdata({
                name: "White Moth",
                latinName: "phalaenopsis micholitzii"
            });
    //    }
            
        // if (randomIndex <= 6074) {
        //    return SpeciesGeneratedMetdata({
        //             name: "Orange Cattelya",
        //             latinName: "guarianthe aurantiaca"
        //         } );
        // }

        //  if (randomIndex <= 8074) {
        //    return SpeciesGeneratedMetdata({
        //             name: "Blue Vanda",
        //             latinName: "vanda coerulea"
        //         });
        // }
        
        //  if (randomIndex <= 9074) {
        //    return SpeciesGeneratedMetdata({
        //             name: "Yellow Lady's Slipper",
        //             latinName: "cypripedium calceolus"
        //         });
        // }

        //  if (randomIndex <= 9574) {
        //    return SpeciesGeneratedMetdata({
        //         name: "Vietnamese Paphiopedilum",
        //         latinName: "paphiopedilum vietnamense"
        //     });
        // }

        // if (randomIndex <= 9824) {
        //    return SpeciesGeneratedMetdata({
        //         name: "Kayasima Miltonia",
        //         latinName: "miltonia kayasimae"
        //     });
        // }

        // if (randomIndex <= 9924) {
        //     return SpeciesGeneratedMetdata({
        //         name: "Hochstetter's Butterfly Orchid",
        //         latinName: "platanthera azorica"
        //     });
        // }

        // if (randomIndex <= 9974) {
        //    return SpeciesGeneratedMetdata({
        //         name: "Ghost Orchid",
        //         latinName: "dendrophylax lindenii"
        //     });
        // }

        // if (randomIndex <= 9999) {
        //     return SpeciesGeneratedMetdata({
        //         name: "Gold of Kinabalu",
        //         latinName: "paphiopedilum rothschildianum"
        //     });
        // }

        // if (randomIndex <= 10000) {
        //    return SpeciesGeneratedMetdata({
        //         name: "Shenzhen Nongke Orchid ",
        //         latinName: "shenzhenica orchidaceae"
        //     });
        // }
    }
}
