// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Libraries/CurrentTime.sol";

contract WaterLevel {
    mapping(uint256 => uint256) public waterLevel;
}

contract CryptOrchidERC721 is ERC721PresetMinterPauserAutoId, WaterLevel, Ownable, VRFConsumerBase, CurrentTime {
    using SafeMathChainlink for uint256;
    using Strings for string;
    using Counters for Counters.Counter;

    struct CryptOrchid {
        string species;
        uint256 plantedAt;
    }
    uint256 public constant MAX_CRYPTORCHIDS = 10000;
    uint256 public constant GROWTH_CYCLE = 10800; // 3 hours
    uint256 public constant WATERING_WINDOW = 3600; // 1 hour

    uint16[10] private limits = [0, 3074, 6074, 8074, 9074, 9574, 9824, 9924, 9974, 9999];
    string[10] private genum = [
        "shenzhenica orchidaceae",
        "phalaenopsis micholitzii",
        "guarianthe aurantiaca",
        "vanda coerulea",
        "cypripedium calceolus",
        "paphiopedilum vietnamense",
        "miltonia kayasimae",
        "platanthera azorica",
        "dendrophylax lindenii",
        "paphiopedilum rothschildianum"
    ];

    string[10] private speciesIPFSConstant = [
        "QmcGsJ98KCUu32YztmTzFKVVN6daMf8s3YvMCH6MCZvbxK",
        "QmcRXP47ov9KkAEWJWWVAjBGPPFJUB7tbTgqRhvsn6tdsf",
        "QmUx1Ts6V3Dga4fhfeo6j2bRsaGDmD8V9KN5GTn4vmbW7E",
        "QmetUGURmPTFM1RqwePRuDvTa9RropVu7KeMR1uPmqF3JH",
        "QmVfVo15eCAcgFaBHFxZ2mn8bzyqJ4FRsCKJuKTnBGcYv8",
        "QmQWt1Hw6dwqT3h3LhE9Zi2ZgbcyLCWZy1nHEeb7srDKrP",
        "Qmc8nBpedwJ4yCoy129apqR7dNu926qmyWcM4xRtrdterJ",
        "QmPNhwCs6s5GQjnpdf1N4LrYx2V724APNbZPHYUJ7beaSG",
        "QmU7X4DpyJdftUgoL5SMqyBjYbz7q1JS3auBaTEQUj97jB",
        "QmQmh9ZSrnUSLghiMzJq4sKqD2diRHoMP6h6vt6mrCQgvx"
    ];

    CryptOrchid[] public cryptorchids;
    Counters.Counter private _tokenIds;

    address payable public creator;

    bytes32 internal keyHash;
    uint256 internal vrfFee;
    uint256 public randomResult;
    address public VRFCoordinator;
    address public LinkToken;

    event RequestedRandomness(bytes32 requestId);
    event OverWatered(uint256 tokenId);
    event Watered(uint256 tokenId, uint256 waterLevel);
    event Composted(uint256 tokenId);

    mapping(bytes32 => address) public requestToSender;
    mapping(bytes32 => uint256) public requestToPlantedAt;
    mapping(bytes32 => string) private speciesIPFS;

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash
    )
        public
        payable
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721PresetMinterPauserAutoId("CryptOrchids", "ORCHD", "ipfs://")
    {
        creator = msg.sender;
        VRFCoordinator = _VRFCoordinator;
        LinkToken = _LinkToken;
        keyHash = _keyhash;
        vrfFee = 0.1 * 10**18; // 0.1 LINK

        for (uint256 index = 0; index < genum.length; index++) {
            speciesIPFS[keccak256(abi.encode(genum[index]))] = speciesIPFSConstant[index];
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        (string memory species, ) = getTokenMetadata(tokenId);
        return string(abi.encodePacked(baseURI(), speciesIPFS[keccak256(abi.encode(species))]));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(address(0) == to || alive(tokenId - 1), "Dead CryptOrchids cannot be transferred");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function currentPrice() public view returns (uint256 price) {
        uint256 currentSupply = totalSupply();
        if (currentSupply >= 9900) {
            return 1000000000000000000; // 9900-10000: 1.00 ETH
        } else if (currentSupply >= 9500) {
            return 640000000000000000; // 9500-9500:  0.64 ETH
        } else if (currentSupply >= 7500) {
            return 320000000000000000; // 7500-9500:  0.32 ETH
        } else if (currentSupply >= 3500) {
            return 160000000000000000; // 3500-7500:  0.16 ETH
        } else if (currentSupply >= 1500) {
            return 80000000000000000; // 1500-3500:  0.08 ETH
        } else if (currentSupply >= 500) {
            return 40000000000000000; // 500-1500:   0.04 ETH
        } else {
            return 20000000000000000; // 0 - 500     0.02 ETH
        }
    }

    receive() external payable {}

    function webMint(uint256 units, uint256 seed) public payable {
        require(units < MAX_CRYPTORCHIDS - totalSupply(), "Not enough bulbs left");
        require(totalSupply() < MAX_CRYPTORCHIDS, "Sale has already ended");
        require(units > 0 && units <= 20, "You can plant minimum 1, maximum 20 CryptOrchids");
        require(SafeMathChainlink.add(totalSupply(), units) <= MAX_CRYPTORCHIDS, "Exceeds MAX_CRYPTORCHIDS");
        require(msg.value >= SafeMathChainlink.mul(currentPrice(), units), "Ether value sent is below the price");

        for (uint256 i = 0; i < units; i++) {
            requestNewRandomBulb(address(msg.sender), seed);
        }
        creator.transfer(msg.value);
    }

    function requestNewRandomBulb(address _addr, uint256 userProvidedSeed) internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK - fill contract with faucet");

        requestId = requestRandomness(keyHash, vrfFee, userProvidedSeed);

        requestToSender[requestId] = _addr;
        requestToPlantedAt[requestId] = currentTime();

        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        cryptorchids.push(
            CryptOrchid({
                species: pickSpecies(SafeMathChainlink.mod(randomness, 10000)),
                plantedAt: requestToPlantedAt[requestId]
            })
        );

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        address sender = requestToSender[requestId];
        _safeMint(sender, newItemId);
    }

    function alive(uint256 index) public view returns (bool) {
        uint256 currentWaterLevel = waterLevel[index];
        uint256 elapsed = currentTime() - cryptorchids[index].plantedAt;
        uint256 fullCycles = SafeMathChainlink.div(uint256(elapsed), GROWTH_CYCLE);
        uint256 modulo = SafeMathChainlink.mod(elapsed, GROWTH_CYCLE);

        if (currentWaterLevel == fullCycles) {
            return true;
        }

        if (SafeMathChainlink.add(currentWaterLevel, 1) == fullCycles && modulo < WATERING_WINDOW) {
            return true;
        }

        return false;
    }

    function water(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId), "Only the Owner can water a CryptOrchid.");
        uint256 index = SafeMathChainlink.sub(tokenId, 1);

        if (!alive(index)) {
            console.log("DEAD");
            burn(tokenId);
            emit Composted(tokenId);
            return;
        }

        uint256 wateringLevel = waterLevel[index];
        uint256 elapsed = currentTime() - cryptorchids[index].plantedAt;
        uint256 fullCycles = SafeMathChainlink.div(uint256(elapsed), GROWTH_CYCLE);

        if (wateringLevel > fullCycles) {
            console.log("OVERWATERED");
            burn(tokenId);
            emit OverWatered(SafeMathChainlink.add(index, 1));
            return;
        }

        uint256 newWaterLevel = SafeMathChainlink.add(wateringLevel, 1);
        waterLevel[index] = newWaterLevel;

        emit Watered(tokenId, newWaterLevel);
    }

    function compost(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId), "Only the Owner can compost a CryptOrchid.");

        burn(tokenId);
        emit Composted(tokenId);
    }

    function getTokenMetadata(uint256 tokenId) public view returns (string memory, uint256) {
        return (
            cryptorchids[SafeMathChainlink.sub(tokenId, 1)].species,
            cryptorchids[SafeMathChainlink.sub(tokenId, 1)].plantedAt
        );
    }

    /**
     * @notice Pick species for random number index
     * @param randomIndex uint256
     * @return species string
     */
    function pickSpecies(uint256 randomIndex) private view returns (string memory) {
        for (uint256 i = 0; i < 10; i++) {
            if (randomIndex <= limits[i]) {
                return genum[i];
            }
        }
    }
}
