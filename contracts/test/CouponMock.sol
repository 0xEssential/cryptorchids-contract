// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "../Coupon/Coupon.sol";

// DEBUG

import "hardhat/console.sol";

contract CouponMock is Coupon {
    event Redemption(address account, uint256 rebate);

    constructor(address cryptorchidsAddress) public Coupon(cryptorchidsAddress) {}

    /**
     * @dev calls checkEligibility and sets all eligibleTokens as redeemed.
     * Then transfers caller rebateAmount.
     */
    function redeem() public virtual override returns (uint256) {
        uint256 rebateAmount = super.redeem();
        emit Redemption(msg.sender, rebateAmount);
        return rebateAmount;
    }
}
