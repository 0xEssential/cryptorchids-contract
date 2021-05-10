// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "../Interfaces/ERC721.sol";
import "../Libraries/CurrentTime.sol";

contract Coupon is Ownable, VRFConsumerBase, CurrentTime {
    using SafeMath for uint256;
    mapping(uint256 => bool) internal redemptions;
    mapping(address => uint256) public addressEntriesCount;

    uint256 public constant PROMOTION_END = 1622520000;
    uint256 internal constant REBATE_AMOUNT = 20000000000000000;
    uint256 internal constant MINT_FLOOR = 40000000000000000;

    uint256 public promotionStart;
    address public cryptorchidsERC721;

    uint256 public drawingEntriesCount;
    uint256 public pot;
    address[] internal drawingEntries;
    bytes32 internal randomWinnerRequestId;
    bool public winnerRequested;
    address public winner;

    bytes32 internal keyHash;
    uint256 internal vrfFee;
    address public VRFCoordinator;
    address public LinkToken;

    constructor(
        address cryptorchidsAddress,
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash
    ) public payable VRFConsumerBase(_VRFCoordinator, _LinkToken) {
        VRFCoordinator = _VRFCoordinator;
        LinkToken = _LinkToken;
        keyHash = _keyhash;
        vrfFee = 2000000000000000000; // 2 LINK
        cryptorchidsERC721 = cryptorchidsAddress;
        promotionStart = block.timestamp;
    }

    /** Public function for whether the promotion is open. The promotion is only
     * open if the contract balance is greater than the currentRebate. Displayed
     * on CryptOrchids nursery for transparency.
     * @dev
     * @return bool Whether promotion is open for entries.
     */
    function promotionOpen() public view returns (bool) {
        if (currentTime() > PROMOTION_END) return false;
        if (pot > address(this).balance + currentRebate()) return false;
        if (currentRebate() > address(this).balance) return false;

        return true;
    }

    /** Check rebate value and eligible tokens. Tokens are valid if they are planted
     * after this contract is deployed, alive, and not yet redeemed.
     * @dev calls public functions on the CryptOrchids contract to build
     * an array of eligible token IDs and a rebate amount.
     * @return eligibleTokens uint256[] Uncompacted array of 0s and eligible token IDs
     * @return rebateAmount uint256 Eligible tokens * currentRebate
     */
    function checkEligibility()
        public
        view
        returns (
            uint256[] memory eligibleTokens,
            uint256 rebateAmount,
            uint256 count
        )
    {
        require(promotionOpen(), "Promotion over");

        uint256 _rebateAmount = 0;
        uint256 tokenCount = ERC721(cryptorchidsERC721).balanceOf(msg.sender);
        uint256[] memory _eligibleTokens = new uint256[](tokenCount);

        for (uint256 index = 0; index < tokenCount; index++) {
            uint256 tokenId = ERC721(cryptorchidsERC721).tokenOfOwnerByIndex(msg.sender, index);
            bool flowering = ERC721(cryptorchidsERC721).flowering(tokenId);
            (, uint256 plantedAt, , ) = ERC721(cryptorchidsERC721).getTokenMetadata(tokenId);

            if (redemptions[tokenId] != true && flowering && plantedAt > promotionStart) {
                _eligibleTokens[index] = tokenId;
                _rebateAmount += currentRebate();
                count += 1;
            }
        }

        if (_rebateAmount > safeBalance()) {
            uint256[] memory empty = new uint256[](0);
            return (empty, _rebateAmount, uint256(0));
        }
        return (_eligibleTokens, _rebateAmount, count);
    }

    /** Claim ETH for valid tokens. Check for valid tokens before claming.
     * @dev calls checkEligibility and sets all eligibleTokens as redeemed.
     * Then transfers caller rebateAmount.
     */
    function redeem() public virtual returns (uint256) {
        require(currentTime() < PROMOTION_END, "Promotion over");
        (uint256[] memory redeeming, uint256 rebateAmount, ) = checkEligibility();
        require(safeBalance() >= rebateAmount, "COC:rdm:paused");

        for (uint256 index = 0; index < redeeming.length - 1; index++) {
            uint256 tokenId = redeeming[index];
            if (tokenId > 0) redemptions[tokenId] = true;
        }

        payable(msg.sender).transfer(rebateAmount);

        return rebateAmount;
    }

    /** Redeem tokens for entries in drawing.
     * @dev Adds address to drawingEntries, increments entriesCount, and
     * increases pot for each eligible token, while marking each token redeemed.
     */
    function enter() public virtual {
        require(currentTime() < PROMOTION_END, "Promotion over");
        (uint256[] memory redeeming, uint256 rebateAmount, uint256 count) = checkEligibility();

        require(safeBalance() >= rebateAmount, "COC:enr:paused");

        for (uint256 index = 0; index < redeeming.length; index++) {
            uint256 tokenId = redeeming[index];
            if (tokenId > 0) {
                redemptions[tokenId] = true;
                drawingEntriesCount += 1;
                addressEntriesCount[msg.sender] += 1;
                drawingEntries.push(address(msg.sender));
                pot += currentRebate();
            }
        }
    }

    /** Current rebate amount for eligible token. Based on CryptOrchids current price,
     * the ramping rebate is intended to address the regrettable FOMO ramp pricing.
     * Starts at 0.02ETH, and increases with inverse correlation to price ramp to
     * offer effectively straight 0.04 ETH for seeds.
     * @dev calls CryptOrchids.currentPrice and finds difference to .
     * Then transfers caller rebateAmount.
     */
    function currentRebate() public view returns (uint256) {
        if (drawingEntriesCount <= 100) return REBATE_AMOUNT;
        uint256 currentPrice = ERC721(cryptorchidsERC721).currentPrice();

        if (currentPrice == MINT_FLOOR) return REBATE_AMOUNT;

        return currentPrice - MINT_FLOOR;
    }

    /** Current count of rebates available as determined by safeBalance and currentRebate
     */
    function rebatesAvailable() public view returns (uint256) {
        return SafeMath.div(safeBalance(), currentRebate());
    }

    /** Current rebate amount for eligible token. Based on CryptOrchids current price,
     * the ramping rebate is intended to address the regrettable FOMO ramp pricing.
     * Starts at 0.02ETH,
     * @dev calls CryptOrchids.currentPrice and finds difference to .
     * Then transfers caller rebateAmount.
     */
    function safeBalance() internal view returns (uint256) {
        return address(this).balance - pot;
    }

    function selectWinner(uint256 userProvidedSeed) public virtual {
        require(currentTime() > PROMOTION_END, "COC:wW:promotion running");
        require(randomWinnerRequestId[0] == 0, "COC:wW:winner requested");
        require(LINK.balanceOf(address(this)) >= vrfFee, "COC:sW:no LINK");

        randomWinnerRequestId = requestRandomness(keyHash, vrfFee, userProvidedSeed);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(requestId == randomWinnerRequestId, "COC:fR:invalid request ID");
        uint256 winnerIndex = SafeMath.mod(randomness, drawingEntriesCount);
        winner = drawingEntries[winnerIndex];
    }

    /** Winner may withdraw ether from the contract once the promotion is over.
     *
     */
    function withdrawWinner() public {
        require(currentTime() > PROMOTION_END, "COC:wW:promotion running");
        require(msg.sender == winner, "COC:wW:not winner");
        uint256 txAmount = pot;
        pot = 0;
        payable(msg.sender).transfer(txAmount);
    }

    /** Withdraw ether from this contract once the promotion is over.
     * @dev Transfer remaining balance to owner if after PROMOTION_END.
     *
     */
    function withdrawUnclaimed() public onlyOwner {
        require(currentTime() > PROMOTION_END, "COC:wU:promotion running");
        require(pot == 0, "COC:wU:winnings unclaimed");

        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    receive() external payable {}
}
