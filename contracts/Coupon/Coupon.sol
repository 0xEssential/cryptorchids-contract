// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/ERC721.sol";

contract Coupon is Ownable {
    using SafeMath for uint256;
    mapping(uint256 => bool) internal redemptions;

    uint256 public constant PROMOTION_END = 1622520000;
    uint256 internal constant REBATE_AMOUNT = 20000000000000000;

    uint256 public promotionStart;
    address public cryptorchidsERC721;

    constructor(address cryptorchidsAddress) public payable {
        cryptorchidsERC721 = cryptorchidsAddress;
        promotionStart = block.timestamp;
    }

    /** Check rebate value and eligible tokens. Tokens are valid if they are planted
     * after this contract is deployed, alive, and not yet redeemed.
     * @dev calls public functions on the CryptOrchids contract to build
     * an array of eligible token IDs and a rebate amount.
     * @return eligibleTokens uint256[] Uncompacted array of 0s and eligible token IDs
     * @return rebateAmount uint256 Eligible tokens * REBATE_AMOUNT
     */
    function checkEligibility() public view returns (uint256[] memory eligibleTokens, uint256 rebateAmount) {
        require(block.timestamp < PROMOTION_END, "Promotion over");

        uint256 _rebateAmount = 0;
        uint256 tokenCount = ERC721(cryptorchidsERC721).balanceOf(msg.sender);
        uint256[] memory _eligibleTokens = new uint256[](tokenCount);

        for (uint256 index = 0; index < tokenCount - 1; index++) {
            uint256 tokenId = ERC721(cryptorchidsERC721).tokenOfOwnerByIndex(msg.sender, index);
            bool flowering = ERC721(cryptorchidsERC721).flowering(tokenId);
            (, uint256 plantedAt, , ) = ERC721(cryptorchidsERC721).getTokenMetadata(tokenId);

            if (redemptions[tokenId] != true && flowering && plantedAt > promotionStart) {
                _eligibleTokens[index] = tokenId;
                _rebateAmount = SafeMath.add(_rebateAmount, REBATE_AMOUNT);
            }
        }

        return (_eligibleTokens, _rebateAmount);
    }

    /** Claim ETH for valid tokens. Check for valid tokens before claming.
     * @dev calls checkEligibility and sets all eligibleTokens as redeemed.
     * Then transfers caller rebateAmount.
     */
    function redeem() public virtual returns (uint256) {
        require(block.timestamp < PROMOTION_END, "Promotion over");
        require(address(this).balance > 0, "Contract no eth");

        (uint256[] memory redeeming, uint256 rebateAmount) = checkEligibility();

        for (uint256 index = 0; index < redeeming.length - 1; index++) {
            uint256 tokenId = redeeming[index];
            redemptions[tokenId] = true;
        }

        payable(msg.sender).transfer(rebateAmount);

        return rebateAmount;
    }

    /** Withdraw ether from this contract once the promotion is over.
     * @dev Transfer remaining balance to owner if after PROMOTION_END.
     *
     */
    function withdrawUnclaimed() public onlyOwner {
        require(block.timestamp > PROMOTION_END, "X");
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    receive() external payable {}
}
