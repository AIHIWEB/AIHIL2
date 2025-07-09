// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISemver } from "interfaces/universal/ISemver.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IProxyAdminOwnedBase } from "interfaces/L1/IProxyAdminOwnedBase.sol";
import { IAIHIPortal2 } from "interfaces/L1/IAIHIPortal2.sol";

interface IETHLockbox is IProxyAdminOwnedBase, ISemver {
    error ETHLockbox_Unauthorized();
    error ETHLockbox_Paused();
    error ETHLockbox_InsufficientBalance();
    error ETHLockbox_NoWithdrawalTransactions();
    error ETHLockbox_DifferentProxyAdminOwner();
    error ETHLockbox_DifferentSuperchainConfig();

    event Initialized(uint8 version);
    event ETHLocked(IAIHIPortal2 indexed portal, uint256 amount);
    event ETHUnlocked(IAIHIPortal2 indexed portal, uint256 amount);
    event PortalAuthorized(IAIHIPortal2 indexed portal);
    event LockboxAuthorized(IETHLockbox indexed lockbox);
    event LiquidityMigrated(IETHLockbox indexed lockbox, uint256 amount);
    event LiquidityReceived(IETHLockbox indexed lockbox, uint256 amount);

    function initialize(ISuperchainConfig _superchainConfig, IAIHIPortal2[] calldata _portals) external;
    function superchainConfig() external view returns (ISuperchainConfig);
    function paused() external view returns (bool);
    function authorizedPortals(IAIHIPortal2) external view returns (bool);
    function authorizedLockboxes(IETHLockbox) external view returns (bool);
    function receiveLiquidity() external payable;
    function lockETH() external payable;
    function unlockETH(uint256 _value) external;
    function authorizePortal(IAIHIPortal2 _portal) external;
    function authorizeLockbox(IETHLockbox _lockbox) external;
    function migrateLiquidity(IETHLockbox _lockbox) external;

    function __constructor__() external;
}
