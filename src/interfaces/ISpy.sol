// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC721 } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

interface ISpy is IERC721 {
  struct UserData {
    uint128 lastBalance;
    uint64 lastTimestamp;
  }

  enum GooBalanceUpdateType {
    INCREASE,
    DECREASE
  }

  function gooBalance(address user) external view returns (uint256);
  function EMISSION_MULTIPLE() external view returns (uint256);
  function getUserData(address) external view returns (uint128, uint64);
}