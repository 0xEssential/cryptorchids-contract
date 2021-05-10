// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "../Coupon/Coupon.sol";

// DEBUG

import "hardhat/console.sol";

contract CouponMock is Coupon {
    event Redemption(address account, uint256 rebate);
    event RequestedRandomness(bytes32 requestId);

    uint256 internal secondsToAdd = 0;

    constructor(
        address cryptorchidsAddress,
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash
    ) public payable Coupon(cryptorchidsAddress, _VRFCoordinator, _LinkToken, _keyhash) {}

    /**
     * @dev calls checkEligibility and sets all eligibleTokens as redeemed.
     * Then transfers caller rebateAmount.
     */
    function redeem() public virtual override returns (uint256) {
        uint256 rebateAmount = super.redeem();
        emit Redemption(msg.sender, rebateAmount);
        return rebateAmount;
    }

    function selectWinner(uint256 userProvidedSeed) public override {
        super.selectWinner(userProvidedSeed);
        emit RequestedRandomness(randomWinnerRequestId);
    }

    function timeTravel(uint256 s) public {
        secondsToAdd = s;
    }

    function currentTime() internal view virtual override returns (uint256) {
        return block.timestamp + secondsToAdd;
    }
}
