pragma solidity 0.6.6;

contract Initializable {
    bool inited = false;

    modifier initializer() {
        require(!inited, "already inited");
        _;
        inited = true;
    }
}
// SPDX-License-Identifier: MIT



contract CurrentTime {
    function currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}


abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }
}


interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}






// NB: this is only meant to deploy to goerli, where chainlink VRF is unavailable.
// goerli connects to polygon mumbai, which is what we need to test PoS bridging.
// Deploy scripts prevent other contracts from goerli deploy, and this contract from
// anything other than goerlui








contract CryptOrchidGoerli is ERC721PresetMinterPauserAutoId, Ownable, CurrentTime {
    using SafeMath for uint256;
    using Strings for string;
    using Counters for Counters.Counter;

    struct CryptOrchid {
        string species;
        uint256 plantedAt;
        uint256 waterLevel;
    }
    mapping(uint256 => CryptOrchid) public cryptorchids;

    enum Stage {Unsold, Seed, Flower, Dead}

    bool internal saleStarted = false;
    bool internal growingStarted = false;

    uint256 public constant MAX_CRYPTORCHIDS = 10000;
    uint256 public constant GROWTH_CYCLE = 604800; // 7 days
    uint256 public constant WATERING_WINDOW = 10800; // 3 hours
    uint256 internal constant MAX_TIMESTAMP = 2**256 - 1;
    string internal constant GRANUM_IPFS = "QmWd1mn7DuGyx9ByfNeqCsgdSUsJZ1cragitgaygsqDvEm";

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
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/shenzhenica-orchidaceae.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/phalaenopsis-micholitzii.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/guarianthe-aurantiaca.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/vanda-coerulea.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/cypripedium-calceolus.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/paphiopedilum-vietnamense.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/miltonia-kayasimae.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/platanthera-azorica.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/dendrophylax-lindenii.json",
        "QmV7nsQgHNvwyRxbbhP59iH3grqSfq3g7joSPaS1JGRmJa/paphiopedilum-rothschildianum.json"
    ];

    string[10] private deadSpeciesIPFSConstant = [
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/shenzhenica-orchidaceae.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/phalaenopsis-micholitzii.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/guarianthe-aurantiaca.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/vanda-coerulea.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/cypripedium-calceolus.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/paphiopedilum-vietnamense.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/miltonia-kayasimae.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/platanthera-azorica.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/dendrophylax-lindenii.json",
        "QmU8MNznT6FD1v5XdnSeA6cEYqxpj7MgkECpot3aCERerX/paphiopedilum-rothschildianum.json"
    ];

    Counters.Counter private _tokenIds;

    mapping(bytes32 => uint256) public requestToToken;
    mapping(bytes32 => string) private speciesIPFS;
    mapping(bytes32 => string) private deadSpeciesIPFS;

    constructor() public payable ERC721PresetMinterPauserAutoId("CryptOrchids", "ORCHD", "ipfs://") {
        for (uint256 index = 0; index < genum.length; index++) {
            speciesIPFS[keccak256(abi.encode(genum[index]))] = speciesIPFSConstant[index];
            deadSpeciesIPFS[keccak256(abi.encode(genum[index]))] = deadSpeciesIPFSConstant[index];
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        (string memory species, , , ) = getTokenMetadata(tokenId);

        if (growthStage(tokenId) == Stage.Seed) {
            return string(abi.encodePacked(baseURI(), GRANUM_IPFS));
        }

        if (growthStage(tokenId) == Stage.Flower) {
            return string(abi.encodePacked(baseURI(), speciesIPFS[keccak256(abi.encode(species))]));
        }

        return string(abi.encodePacked(baseURI(), deadSpeciesIPFS[keccak256(abi.encode(species))]));
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
            return 60000000000000000; // 500-1500:   0.06 ETH
        } else {
            return 40000000000000000; // 0 - 500     0.04 ETH
        }
    }

    function startSale() public onlyOwner {
        saleStarted = true;
    }

    function startGrowing() public onlyOwner {
        growingStarted = true;
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
        require(saleStarted, "The Nursery is closed");
        require(units <= MAX_CRYPTORCHIDS - totalSupply(), "Not enough bulbs left");
        require(totalSupply() < MAX_CRYPTORCHIDS, "Sale has already ended");
        require(units > 0 && units <= 20, "You can plant minimum 1, maximum 20 CryptOrchids");
        require(SafeMath.add(totalSupply(), units) <= MAX_CRYPTORCHIDS, "Exceeds MAX_CRYPTORCHIDS");
        require(msg.value >= SafeMath.mul(currentPrice(), units), "Ether value sent is below the price");

        for (uint256 i = 0; i < units; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            cryptorchids[newItemId] = CryptOrchid({species: "granum", plantedAt: MAX_TIMESTAMP, waterLevel: 0});
            _safeMint(msg.sender, newItemId);
        }
    }

    function germinate(uint256 tokenId, uint256 userProvidedSeed) public {
        require(growingStarted, "Germination starts 2021-04-12T16:00:00Z");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Only the Owner can germinate a CryptOrchid.");
        _requestRandom(tokenId, userProvidedSeed);
    }

    function _requestRandom(uint256 tokenId, uint256 userProvidedSeed) internal returns (bytes32 requestId) {
        uint256 pseudoRand = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, userProvidedSeed)));
        fulfillRandomness(tokenId, pseudoRand);
    }

    function fulfillRandomness(uint256 tokenId, uint256 randomness) internal {
        CryptOrchid storage orchid = cryptorchids[tokenId];
        string memory species = pickSpecies(SafeMath.mod(randomness, 10000));
        orchid.species = species;
        orchid.plantedAt = currentTime();
        address tokenOwner = ownerOf(tokenId);
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
        uint256 fullCycles = SafeMath.div(uint256(elapsed), GROWTH_CYCLE);
        uint256 modulo = SafeMath.mod(elapsed, GROWTH_CYCLE);

        if (currentWaterLevel == fullCycles) {
            return Stage.Flower;
        }

        if (SafeMath.add(currentWaterLevel, 1) == fullCycles && modulo < WATERING_WINDOW) {
            return Stage.Flower;
        }

        return Stage.Dead;
    }

    function water(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Only the Owner can water a CryptOrchid.");

        if (!alive(tokenId)) {
            return;
        }

        CryptOrchid storage orchid = cryptorchids[tokenId];

        uint256 wateringLevel = orchid.waterLevel;
        uint256 elapsed = currentTime() - orchid.plantedAt;
        uint256 fullCycles = SafeMath.div(uint256(elapsed), GROWTH_CYCLE);

        if (wateringLevel > fullCycles) {
            return;
        }

        uint256 newWaterLevel = SafeMath.add(wateringLevel, 1);
        orchid.waterLevel = newWaterLevel;
    }

    function getTokenMetadata(uint256 tokenId)
        public
        view
        returns (
            string memory,
            uint256,
            uint256,
            Stage
        )
    {
        return (
            cryptorchids[tokenId].species,
            cryptorchids[tokenId].plantedAt,
            cryptorchids[tokenId].waterLevel,
            growthStage(tokenId)
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





contract AccessControlMixin is AccessControl {
    string private _revertMsg;
    function _setupContractId(string memory contractId) internal {
        _revertMsg = string(abi.encodePacked(contractId, ": INSUFFICIENT_PERMISSIONS"));
    }

    modifier only(bytes32 role) {
        require(
            hasRole(role, _msgSender()),
            _revertMsg
        );
        _;
    }
}









contract EIP712Base is Initializable {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }

    string constant public ERC712_VERSION = "1";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        bytes(
            "EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)"
        )
    );
    bytes32 internal domainSeperator;

    // supposed to be called once while initializing.
    // one of the contractsa that inherits this contract follows proxy pattern
    // so it is not possible to do this in a constructor
    function _initializeEIP712(
        string memory name
    )
        internal
        initializer
    {
        _setDomainSeperator(name);
    }

    function _setDomainSeperator(string memory name) internal {
        domainSeperator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(ERC712_VERSION)),
                address(this),
                bytes32(getChainId())
            )
        );
    }

    function getDomainSeperator() public view returns (bytes32) {
        return domainSeperator;
    }

    function getChainId() public pure returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * Accept message hash and returns hash message in EIP712 compatible form
     * So that it can be used to recover signer from signature signed using EIP712 formatted data
     * https://eips.ethereum.org/EIPS/eip-712
     * "\\x19" makes the encoding deterministic
     * "\\x01" is the version byte to make it compatible to EIP-191
     */
    function toTypedMessageHash(bytes32 messageHash)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", getDomainSeperator(), messageHash)
            );
    }
}


contract NativeMetaTransaction is EIP712Base {
    using SafeMath for uint256;
    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256(
        bytes(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        )
    );
    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );
    mapping(address => uint256) nonces;

    /*
     * Meta transaction structure.
     * No point of including value field here as if user is doing value transfer then he has the funds to pay for gas
     * He should call the desired function directly in that case.
     */
    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });

        require(
            verify(userAddress, metaTx, sigR, sigS, sigV),
            "Signer and signature do not match"
        );

        // increase nonce for user (to avoid re-use)
        nonces[userAddress] = nonces[userAddress].add(1);

        emit MetaTransactionExecuted(
            userAddress,
            msg.sender,
            functionSignature
        );

        // Append userAddress and relayer address at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, userAddress)
        );
        require(success, "Function call not successful");

        return returnData;
    }

    function hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }

    function getNonce(address user) public view returns (uint256 nonce) {
        nonce = nonces[user];
    }

    function verify(
        address signer,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return
            signer ==
            ecrecover(
                toTypedMessageHash(hashMetaTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }
}



contract CryptOrchidERC721Child is
    CryptOrchidGoerli,
    IChildToken,
    AccessControlMixin,
    NativeMetaTransaction,
    ContextMixin
{
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    // limit batching of tokens due to gas limit restrictions
    uint256 public constant BATCH_LIMIT = 20;

    event WithdrawnBatch(address indexed user, uint256[] tokenIds);
    event TransferWithMetadata(address indexed from, address indexed to, uint256 indexed tokenId, bytes metaData);

    constructor(address childChainManager) public CryptOrchidGoerli() {
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

    /**
     * @notice called when user wants to withdraw token back to root chain
     * @dev Should burn user's token. This transaction will be verified when exiting on root chain
     * @param tokenId tokenId to withdraw
     */
    function withdraw(uint256 tokenId) external {
        require(_msgSender() == ownerOf(tokenId), "ChildERC721: INVALID_TOKEN_OWNER");
        _burn(tokenId);
    }

    /**
     * @notice called when user wants to withdraw multiple tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param tokenIds tokenId list to withdraw
     */
    function withdrawBatch(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        require(length <= BATCH_LIMIT, "ChildERC721: EXCEEDS_BATCH_LIMIT");
        for (uint256 i; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            require(
                _msgSender() == ownerOf(tokenId),
                string(abi.encodePacked("ChildERC721: INVALID_TOKEN_OWNER ", tokenId))
            );
            _burn(tokenId);
        }
        emit WithdrawnBatch(_msgSender(), tokenIds);
    }

    /**
     * @notice called when user wants to withdraw token back to root chain with arbitrary metadata
     * @dev Should handle withraw by burning user's token.
     *
     * This transaction will be verified when exiting on root chain
     *
     * @param tokenId tokenId to withdraw
     */
    function withdrawWithMetadata(uint256 tokenId) external {
        require(_msgSender() == ownerOf(tokenId), "ChildERC721: INVALID_TOKEN_OWNER");

        // Encoding metadata associated with tokenId & emitting event
        emit TransferWithMetadata(_msgSender(), address(0), tokenId, this.encodeTokenMetadata(tokenId));

        _burn(tokenId);
    }

    /**
     * @notice This method is supposed to be called by client when withdrawing token with metadata
     * and pass return value of this function as second paramter of `withdrawWithMetadata` method
     *
     * It can be overridden by clients to encode data in a different form, which needs to
     * be decoded back by them correctly during exiting
     *
     * @param tokenId Token for which URI to be fetched
     */
    function encodeTokenMetadata(uint256 tokenId) external view virtual returns (bytes memory) {
        // You're always free to change this default implementation
        // and pack more data in byte array which can be decoded back
        // in L1
        return abi.encode(tokenURI(tokenId));
    }
}



