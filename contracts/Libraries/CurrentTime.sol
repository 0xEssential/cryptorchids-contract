// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

contract CurrentTime {
  function currentTime() internal virtual view returns(uint256) {
    return block.timestamp;
  }
}
