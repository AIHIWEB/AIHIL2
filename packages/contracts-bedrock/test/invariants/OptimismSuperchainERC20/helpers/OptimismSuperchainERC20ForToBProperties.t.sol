// SPDX-License-Identifier: AGPL-3
pragma solidity ^0.8.25;

import { AIHISuperchainERC20 } from "src/L2/AIHISuperchainERC20.sol";

contract AIHISuperchainERC20ForToBProperties is AIHISuperchainERC20 {
    /// @notice This is used by CryticERC20ExternalBasicProperties (only used
    /// in Medusa testing campaign)to know which properties to test, and
    /// remains here so Medusa and Foundry test campaigns can use a single
    /// setup
    bool public constant isMintableOrBurnable = true;
}
