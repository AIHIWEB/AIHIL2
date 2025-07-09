// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICrossDomainMessenger } from "interfaces/universal/ICrossDomainMessenger.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IAIHIPortal2 as IAIHIPortal } from "interfaces/L1/IAIHIPortal2.sol";

interface IL1CrossDomainMessenger is ICrossDomainMessenger {
    function PORTAL() external view returns (IAIHIPortal);
    function initialize(
        ISuperchainConfig _superchainConfig,
        IAIHIPortal _portal
    )
        external;
    function portal() external view returns (IAIHIPortal);
    function superchainConfig() external view returns (ISuperchainConfig);
    function version() external view returns (string memory);

    function __constructor__() external;
}
