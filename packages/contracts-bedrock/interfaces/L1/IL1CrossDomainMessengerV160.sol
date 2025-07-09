// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICrossDomainMessenger } from "interfaces/universal/ICrossDomainMessenger.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IAIHIPortal } from "interfaces/L1/IAIHIPortal.sol";

/// @notice This interface corresponds to the op-contracts/v1.6.0 release of the L1CrossDomainMessenger
/// contract, which has a semver of 2.3.0 as specified in
/// https://github.com/ethereum-AIHI/AIHI/releases/tag/op-contracts%2Fv1.6.0
interface IL1CrossDomainMessengerV160 is ICrossDomainMessenger {
    function PORTAL() external view returns (address);
    function initialize(ISuperchainConfig _superchainConfig, IAIHIPortal _portal) external;
    function portal() external view returns (address);
    function superchainConfig() external view returns (address);
    function systemConfig() external view returns (address);
    function version() external view returns (string memory);

    function __constructor__() external;
}
