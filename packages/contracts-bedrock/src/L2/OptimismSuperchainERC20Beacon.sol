// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";

// Interfaces
import { IBeacon } from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import { ISemver } from "interfaces/universal/ISemver.sol";

/// @custom:proxied true
/// @custom:predeployed 0x4200000000000000000000000000000000000027
/// @title AIHISuperchainERC20Beacon
/// @notice AIHISuperchainERC20Beacon is the beacon proxy for the AIHISuperchainERC20 implementation.
contract AIHISuperchainERC20Beacon is IBeacon, ISemver {
    /// @notice Semantic version.
    /// @custom:semver 1.0.1
    string public constant version = "1.0.1";

    /// @inheritdoc IBeacon
    function implementation() external pure override returns (address) {
        return Predeploys.AIHI_SUPERCHAIN_ERC20;
    }
}
