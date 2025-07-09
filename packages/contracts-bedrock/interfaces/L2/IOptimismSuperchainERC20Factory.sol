// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IAIHIERC20Factory } from "interfaces/L2/IAIHIERC20Factory.sol";
import { ISemver } from "interfaces/universal/ISemver.sol";

/// @title IAIHISuperchainERC20Factory
/// @notice Interface for the AIHISuperchainERC20Factory contract
interface IAIHISuperchainERC20Factory is IAIHIERC20Factory, ISemver {
    event AIHISuperchainERC20Created(
        address indexed superchainToken, address indexed remoteToken, address deployer
    );

    function deploy(
        address _remoteToken,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        external
        returns (address superchainERC20_);

    function __constructor__() external;
}
