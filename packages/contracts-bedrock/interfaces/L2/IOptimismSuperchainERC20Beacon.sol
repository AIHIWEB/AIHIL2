// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISemver } from "interfaces/universal/ISemver.sol";

/// @title IAIHISuperchainERC20Beacon
/// @notice Interface for the AIHISuperchainERC20Beacon contract
interface IAIHISuperchainERC20Beacon is ISemver {
    function implementation() external pure returns (address);

    function __constructor__() external;
}
