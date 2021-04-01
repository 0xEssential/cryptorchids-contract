// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;
import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Libraries/CurrentTime.sol";

contract CryptOrchidERC721 is ERC721PresetMinterPauserAutoId, Ownable, VRFConsumerBase, CurrentTime {
    using SafeMathChainlink for uint256;
    using Strings for string;
    using Counters for Counters.Counter;

    struct CryptOrchid {
        string species;
        uint256 plantedAt;
        uint256 waterLevel;
    }
    mapping(uint256 => CryptOrchid) public cryptorchids;

    enum Stage {Unsold, Seed, Flower, Dead}

    uint256 public constant MAX_CRYPTORCHIDS = 10000;
    uint256 public constant GROWTH_CYCLE = 10800; // 3 hours
    uint256 public constant WATERING_WINDOW = 3600; // 1 hour
    uint256 internal constant MAX_TIMESTAMP = 2**256 - 1;
    string internal constant GRANUM_ARWEAVE = "pHm6ysVq154aZ171iU0izH68t_sjGMglQvqxYNDA4h0";

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

    string[10] private speciesArweaveConstant = [
        "vxdAdCdwi2-Fn25UPRqzQPafS-g4H15wSe_7TbwW2s4",
        "KBTtR60gLZMvp5DTDiVv08vecD96bh_V3W-8ko3QVQg",
        "Yj42tKSh8M4MLirT1JmckDbDPzekMX7Vv6qp7Y93TAE",
        "0FhRkI4QhYcH_ROKdylSTGnrruOpwVlFZRZ5cBF6ikU",
        "62abDISfRV8yjSzk-xCm8TsYpjUZ91sCwQaBPvAxH8k",
        "NEc4qWJwKSkmLgglfi9PmLYxASlbpmDBa4e9SxJxWuU",
        "IILQaYkW3iYDw3OYSwLfbZFx_14jdIu3nUwMDYBBtuQ",
        "NO9h1G_V5M7jrhY4X18CpJi4stDJj4hQTv23qqHdSj8",
        "cwZB7FOgWK052sHrGe-vE9Z7t1dmKe3DSSyDPtBMY0c",
        "oeGa3OqppFm1OONslz7xuValA2d4KCU0vKqnOTIyXdw"
    ];

    string[10] private deadSpeciesArweaveConstant = [
        "f1_jQ1fVLmRJ-JKMgIe3XqtTzJl-7rX1igYcQjFhpVA",
        "OPIRLIcORdTTuI-bWcQfShctfDjYv2nCtitzUGioDxg",
        "5qBF2IB8sCzmp4MNn2GG24OTfreHWx4ooVI6OYUqvBk",
        "OQiKGwQSmZlZxcGccrtu1ov6f2FfPSmD1ZicBaUzNCc",
        "cam_7pRCFsDszqTjih_toj6B_Xl9oY3Ndy-Egc5IEhI",
        "pHiPaw4T7PPnkO4yu2xYW7i-itQkYqVLZUUSvz9lE0w",
        "WUFIJOnggBM8JeXlOM_iKVLqIipavfZhic1zcC5GkMw",
        "gYJcHxh2l67m1xfuibbF8zzZ2J43dpOmT0ftVWStvns",
        "LSp4B5T3B0HFXRU6P1qR1bMo6cTCOCGrGOZRj5IW6R0",
        "22JEnCLgN7qX1d-4VeXHRdXPl87P2zxENJxQFYC6J8k"
    ];

    Counters.Counter private _tokenIds;

    bytes32 internal keyHash;
    uint256 internal vrfFee;
    uint256 public randomResult;
    address public VRFCoordinator;
    address public LinkToken;

    event RequestedRandomness(bytes32 requestId);
    event Planted(uint256 tokenId);
    event Watered(uint256 tokenId, uint256 waterLevel);
    event Composted(uint256 tokenId);

    mapping(bytes32 => uint256) public requestToToken;
    mapping(bytes32 => string) private speciesArweave;
    mapping(bytes32 => string) private deadSpeciesArweave;

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash
    )
        public
        payable
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721PresetMinterPauserAutoId("CryptOrchids", "ORCHD", "https://arweave.net")
    {
        VRFCoordinator = _VRFCoordinator;
        LinkToken = _LinkToken;
        keyHash = _keyhash;
        vrfFee = 0.1 * 10**18; // 0.1 LINK

        for (uint256 index = 0; index < genum.length; index++) {
            speciesArweave[keccak256(abi.encode(genum[index]))] = speciesArweaveConstant[index];
            deadSpeciesArweave[keccak256(abi.encode(genum[index]))] = deadSpeciesArweaveConstant[index];
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        (string memory species, , ) = getTokenMetadata(tokenId);

        if (growthStage(tokenId) == Stage.Seed) {
            return string(abi.encodePacked(baseURI(), GRANUM_ARWEAVE));
        }

        if (growthStage(tokenId) == Stage.Flower) {
            return string(abi.encodePacked(baseURI(), speciesArweave[keccak256(abi.encode(species))]));
        }

        return string(abi.encodePacked(baseURI(), deadSpeciesArweave[keccak256(abi.encode(species))]));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(address(0) == to || alive(tokenId), "Dead CryptOrchids cannot be transferred");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function currentPrice() public view returns (uint256 price) {
        uint256 currentSupply = totalSupply();
        if (currentSupply >= 9900) {
            return 1000000000000000000; // 9900+: 1.00 ETH
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

    /**
     * @dev Withdraw ether from this contract (Callable by owner only)
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    receive() external payable {}

    function webMint(uint256 units) public payable {
        require(units < MAX_CRYPTORCHIDS - totalSupply(), "Not enough bulbs left");
        require(totalSupply() < MAX_CRYPTORCHIDS, "Sale has already ended");
        require(units > 0 && units <= 20, "You can plant minimum 1, maximum 20 CryptOrchids");
        require(SafeMathChainlink.add(totalSupply(), units) <= MAX_CRYPTORCHIDS, "Exceeds MAX_CRYPTORCHIDS");
        require(msg.value >= SafeMathChainlink.mul(currentPrice(), units), "Ether value sent is below the price");

        for (uint256 i = 0; i < units; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            cryptorchids[newItemId] = CryptOrchid({species: "granum", plantedAt: MAX_TIMESTAMP, waterLevel: 0});
            _safeMint(msg.sender, newItemId);
        }
    }

    function germinate(uint256 tokenId, uint256 userProvidedSeed) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Only the Owner can germinate a CryptOrchid.");
        _requestRandom(tokenId, userProvidedSeed);
    }

    function _requestRandom(uint256 tokenId, uint256 userProvidedSeed) internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK - fill contract with faucet");
        requestId = requestRandomness(keyHash, vrfFee, userProvidedSeed);
        requestToToken[requestId] = tokenId;
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = requestToToken[requestId];
        CryptOrchid storage orchid = cryptorchids[tokenId];
        orchid.species = pickSpecies(SafeMathChainlink.mod(randomness, 10000));
        orchid.plantedAt = currentTime();
        emit Planted(tokenId);
    }

    function alive(uint256 tokenId) public view returns (bool) {
        return growthStage(tokenId) != Stage.Dead;
    }

    function flowering(uint256 tokenId) public view returns (bool) {
        return growthStage(tokenId) == Stage.Flower;
    }

    function growthStage(uint256 tokenId) public view returns (Stage) {
        CryptOrchid memory orchid = cryptorchids[tokenId];
        if (orchid.plantedAt == 0) return Stage.Unsold;
        if (orchid.plantedAt == MAX_TIMESTAMP) return Stage.Seed;
        uint256 currentWaterLevel = orchid.waterLevel;
        uint256 elapsed = currentTime() - orchid.plantedAt;
        uint256 fullCycles = SafeMathChainlink.div(uint256(elapsed), GROWTH_CYCLE);
        uint256 modulo = SafeMathChainlink.mod(elapsed, GROWTH_CYCLE);

        if (currentWaterLevel == fullCycles) {
            return Stage.Flower;
        }

        if (SafeMathChainlink.add(currentWaterLevel, 1) == fullCycles && modulo < WATERING_WINDOW) {
            return Stage.Flower;
        }

        return Stage.Dead;
    }

    function water(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Only the Owner can water a CryptOrchid.");

        if (!alive(tokenId)) {
            burn(tokenId);
            return;
        }

        CryptOrchid storage orchid = cryptorchids[tokenId];

        uint256 wateringLevel = orchid.waterLevel;
        uint256 elapsed = currentTime() - orchid.plantedAt;
        uint256 fullCycles = SafeMathChainlink.div(uint256(elapsed), GROWTH_CYCLE);

        if (wateringLevel > fullCycles) {
            burn(tokenId);
            return;
        }

        uint256 newWaterLevel = SafeMathChainlink.add(wateringLevel, 1);
        orchid.waterLevel = newWaterLevel;

        emit Watered(tokenId, newWaterLevel);
    }

    function compost(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Only the Owner can compost a CryptOrchid.");

        burn(tokenId);
        emit Composted(tokenId);
    }

    function getTokenMetadata(uint256 tokenId)
        public
        view
        returns (
            string memory,
            uint256,
            uint256
        )
    {
        return (cryptorchids[tokenId].species, cryptorchids[tokenId].plantedAt, cryptorchids[tokenId].waterLevel);
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
