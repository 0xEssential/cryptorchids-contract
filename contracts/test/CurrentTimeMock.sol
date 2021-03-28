// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "../Libraries/CurrentTime.sol";

contract CurrentTimeMock is CurrentTime {
    uint256 internal secondsToAdd = 0;
}
