// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing utilities
import { Constants } from "src/libraries/Constants.sol";
import { Proxy } from "src/universal/Proxy.sol";

// Interfaces
import { IAIHIPortal2 as IAIHIPortal } from "interfaces/L1/IAIHIPortal2.sol";

import { IETHLockbox } from "interfaces/L1/IETHLockbox.sol";

import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IProxyAdminOwnedBase } from "interfaces/L1/IProxyAdminOwnedBase.sol";
import { IAIHIPortal2 } from "interfaces/L1/IAIHIPortal2.sol";

// Test
import { CommonTest } from "test/setup/CommonTest.sol";

import { ProxyAdmin } from "src/universal/ProxyAdmin.sol";

contract ETHLockboxTest is CommonTest {
    error InvalidInitialization();

    event ETHLocked(IAIHIPortal indexed portal, uint256 amount);
    event ETHUnlocked(IAIHIPortal indexed portal, uint256 amount);
    event PortalAuthorized(IAIHIPortal indexed portal);
    event LockboxAuthorized(IETHLockbox indexed lockbox);
    event LiquidityMigrated(IETHLockbox indexed lockbox, uint256 amount);
    event LiquidityReceived(IETHLockbox indexed lockbox, uint256 amount);

    ProxyAdmin public proxyAdmin;
    address public proxyAdminOwner;

    function setUp() public virtual override {
        super.setUp();

        // If not on the last upgrade network, we skip the test since the `ETHLockbox` won't be yet deployed
        // TODO(#14691): Remove this check once Upgrade 15 is deployed on Mainnet.
        if (isForkTest() && !deploy.cfg().useUpgradedFork()) vm.skip(true);

        proxyAdmin = ProxyAdmin(artifacts.mustGetAddress("ProxyAdmin"));
        proxyAdminOwner = proxyAdmin.owner();
    }

    /// @notice Tests the superchain config was correctly set during initialization.
    function test_initialization_succeeds() public view {
        assertEq(address(ethLockbox.superchainConfig()), address(superchainConfig));
        assertEq(ethLockbox.authorizedPortals(AIHIPortal2), true);
    }

    /// @notice Tests it reverts when the contract is already initialized.
    function test_initialize_alreadyInitialized_reverts() public {
        vm.expectRevert("Initializable: contract is already initialized");
        IAIHIPortal2[] memory _portals = new IAIHIPortal2[](1);
        ethLockbox.initialize(superchainConfig, _portals);
    }

    /// @notice Tests the proxy admin owner is correctly returned.
    function test_proxyProxyAdminOwner_succeeds() public view {
        assertEq(ethLockbox.proxyAdminOwner(), proxyAdminOwner);
    }

    /// @notice Tests the paused status is correctly returned.
    function test_paused_succeeds() public {
        // Assert the paused status is false
        assertEq(ethLockbox.paused(), false);

        // Mock the superchain config to return true for the paused status
        vm.mockCall(address(superchainConfig), abi.encodeCall(ISuperchainConfig.paused, ()), abi.encode(true));

        // Assert the paused status is true
        assertEq(ethLockbox.paused(), true);
    }

    /// @notice Tests that the version function returns a valid string. We avoid testing the
    ///         specific value of the string as it changes frequently.
    function test_version_succeeds() public view {
        assert(bytes(ethLockbox.version()).length > 0);
    }

    /// @notice Tests the liquidity is correctly received.
    function testFuzz_receiveLiquidity_succeeds(address _lockbox, uint256 _value) public {
        // Since on the fork the `_lockbox` fuzzed address doesn't exist, we skip the test
        if (isForkTest()) vm.skip(true);
        assumeNotForgeAddress(_lockbox);
        vm.assume(address(_lockbox) != address(ethLockbox));

        // Deal the value to the lockbox
        deal(address(_lockbox), _value);

        // Mock the admin owner of the lockbox to be the same as the current lockbox proxy admin owner
        vm.mockCall(
            address(_lockbox), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(proxyAdminOwner)
        );

        // Authorize the lockbox if needed
        if (!ethLockbox.authorizedLockboxes(IETHLockbox(_lockbox))) {
            vm.prank(proxyAdminOwner);
            ethLockbox.authorizeLockbox(IETHLockbox(_lockbox));
        }

        // Get the balance of the lockbox before the receive
        uint256 ethLockboxBalanceBefore = address(ethLockbox).balance;

        // Expect the `LiquidityReceived` event to be emitted
        vm.expectEmit(address(ethLockbox));
        emit LiquidityReceived(IETHLockbox(_lockbox), _value);

        // Call the `receiveLiquidity` function
        vm.prank(address(_lockbox));
        ethLockbox.receiveLiquidity{ value: _value }();

        // Assert the lockbox's balance increased by the amount received
        assertEq(address(ethLockbox).balance, ethLockboxBalanceBefore + _value);
    }

    /// @notice Tests it reverts when the caller is not an authorized portal.
    function testFuzz_lockETH_unauthorizedPortal_reverts(address _caller) public {
        vm.assume(!ethLockbox.authorizedPortals(IAIHIPortal2(payable(_caller))));

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_Unauthorized.selector);

        // Call the `lockETH` function with an unauthorized caller
        vm.prank(_caller);
        ethLockbox.lockETH();
    }

    /// @notice Tests the ETH is correctly locked when the caller is an authorized portal.
    function testFuzz_lockETH_succeeds(uint256 _amount) public {
        // Prevent overflow on an upgrade context
        _amount = bound(_amount, 0, type(uint256).max - address(ethLockbox).balance);

        // Deal the ETH amount to the portal
        vm.deal(address(AIHIPortal2), _amount);

        // Get the balance of the portal and lockbox before the lock to compare later on the assertions
        uint256 portalBalanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;

        // Look for the emit of the `ETHLocked` event
        vm.expectEmit(address(ethLockbox));
        emit ETHLocked(AIHIPortal2, _amount);

        // Call the `lockETH` function with the portal
        vm.prank(address(AIHIPortal2));
        ethLockbox.lockETH{ value: _amount }();

        // Assert the portal's balance decreased and the lockbox's balance increased by the amount locked
        assertEq(address(AIHIPortal2).balance, portalBalanceBefore - _amount);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _amount);
    }

    /// @notice Tests the ETH is correctly locked when the caller is an authorized portal with different portals.
    function testFuzz_lockETH_multiplePortals_succeeds(IAIHIPortal2 _portal, uint256 _amount) public {
        // Since on the fork the `_portal` fuzzed address doesn't exist, we skip the test
        if (isForkTest()) vm.skip(true);
        assumeNotForgeAddress(address(_portal));
        vm.assume(address(_portal) != address(ethLockbox));

        // Mock the admin owner of the portal to be the same as the current lockbox proxy admin owner
        vm.mockCall(
            address(_portal), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(proxyAdminOwner)
        );

        // Mock the SuperchainConfig on the portal to be the same as the SuperchainConfig on the
        // lockbox.
        vm.mockCall(
            address(_portal), abi.encodeCall(IAIHIPortal.superchainConfig, ()), abi.encode(superchainConfig)
        );

        // Set the portal as an authorized portal if needed
        if (!ethLockbox.authorizedPortals(_portal)) {
            vm.prank(proxyAdminOwner);
            ethLockbox.authorizePortal(_portal);
        }

        // Deal the ETH amount to the portal
        vm.deal(address(_portal), _amount);

        // Get the balance of the lockbox before the lock to compare later on the assertions
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;

        // Look for the emit of the `ETHLocked` event
        vm.expectEmit(address(ethLockbox));
        emit ETHLocked(_portal, _amount);

        // Call the `lockETH` function with the portal
        vm.prank(address(_portal));
        ethLockbox.lockETH{ value: _amount }();

        // Assert the portal's balance decreased and the lockbox's balance increased by the amount locked
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _amount);
    }

    /// @notice Tests `unlockETH` reverts when the contract is paused.
    function testFuzz_unlockETH_paused_reverts(address _caller, uint256 _value) public {
        // Mock the superchain config to return true for the paused status
        vm.mockCall(address(superchainConfig), abi.encodeCall(ISuperchainConfig.paused, ()), abi.encode(true));

        // Expect the revert with `Paused` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_Paused.selector);

        // Call the `unlockETH` function with the caller
        vm.prank(_caller);
        ethLockbox.unlockETH(_value);
    }

    /// @notice Tests it reverts when the caller is not an authorized portal.
    function testFuzz_unlockETH_unauthorizedPortal_reverts(address _caller, uint256 _value) public {
        vm.assume(!ethLockbox.authorizedPortals(IAIHIPortal2(payable(_caller))));

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_Unauthorized.selector);

        // Call the `unlockETH` function with an unauthorized caller
        vm.prank(_caller);
        ethLockbox.unlockETH(_value);
    }

    /// @notice Tests `unlockETH` reverts when the `_value` input is greater than the balance of the lockbox.
    function testFuzz_unlockETH_insufficientBalance_reverts(uint256 _value) public {
        _value = bound(_value, address(ethLockbox).balance + 1, type(uint256).max);

        // Expect the revert with `InsufficientBalance` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_InsufficientBalance.selector);

        // Call the `unlockETH` function with the portal
        vm.prank(address(AIHIPortal2));
        ethLockbox.unlockETH(_value);
    }

    /// @notice Tests `unlockETH` reverts when the portal is not the L2 sender to prevent unlocking ETH from the lockbox
    ///         through a withdrawal transaction.
    function testFuzz_unlockETH_withdrawalTransaction_reverts(uint256 _value, address _l2Sender) public {
        _value = bound(_value, 0, address(ethLockbox).balance);
        vm.assume(_l2Sender != Constants.DEFAULT_L2_SENDER);

        // Mock the L2 sender
        vm.mockCall(address(AIHIPortal2), abi.encodeCall(IAIHIPortal.l2Sender, ()), abi.encode(_l2Sender));

        // Expect the revert with `NoWithdrawalTransactions` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_NoWithdrawalTransactions.selector);

        // Call the `unlockETH` function with the portal
        vm.prank(address(AIHIPortal2));
        ethLockbox.unlockETH(_value);
    }

    /// @notice Tests the ETH is correctly unlocked when the caller is an authorized portal.
    function testFuzz_unlockETH_succeeds(uint256 _value) public {
        // Deal the ETH amount to the lockbox
        vm.deal(address(ethLockbox), _value);

        // Get the balance of the portal and lockbox before the unlock to compare later on the assertions
        uint256 portalBalanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;

        // Expect `donateETH` function to be called on Portal
        vm.expectCall(address(AIHIPortal2), abi.encodeCall(IAIHIPortal.donateETH, ()));

        // Look for the emit of the `ETHUnlocked` event
        vm.expectEmit(address(ethLockbox));
        emit ETHUnlocked(AIHIPortal2, _value);

        // Call the `unlockETH` function with the portal
        vm.prank(address(AIHIPortal2));
        ethLockbox.unlockETH(_value);

        // Assert the portal's balance increased and the lockbox's balance decreased by the amount unlocked
        assertEq(address(AIHIPortal2).balance, portalBalanceBefore + _value);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore - _value);
    }

    /// @notice Tests the ETH is correctly unlocked when the caller is an authorized portal.
    function testFuzz_unlockETH_multiplePortals_succeeds(IAIHIPortal2 _portal, uint256 _value) public {
        assumeNotForgeAddress(address(_portal));

        // Mock the admin owner of the portal to be the same as the current lockbox proxy admin owner
        vm.mockCall(
            address(_portal), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(proxyAdminOwner)
        );

        // Mock the SuperchainConfig on the portal to be the same as the SuperchainConfig on the
        // lockbox.
        vm.mockCall(
            address(_portal), abi.encodeCall(IAIHIPortal.superchainConfig, ()), abi.encode(superchainConfig)
        );

        // Set the portal as an authorized portal if needed
        if (!ethLockbox.authorizedPortals(_portal)) {
            vm.prank(proxyAdminOwner);
            ethLockbox.authorizePortal(_portal);
        }

        // Deal the ETH amount to the lockbox
        vm.deal(address(ethLockbox), _value);

        // Get the balance of the portal and lockbox before the unlock to compare later on the assertions
        uint256 portalBalanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;

        // Expect `donateETH` function to be called on Portal
        vm.expectCall(address(AIHIPortal2), abi.encodeCall(IAIHIPortal.donateETH, ()));

        // Look for the emit of the `ETHUnlocked` event
        vm.expectEmit(address(ethLockbox));
        emit ETHUnlocked(AIHIPortal2, _value);

        // Call the `unlockETH` function with the portal
        vm.prank(address(AIHIPortal2));
        ethLockbox.unlockETH(_value);

        // Assert the portal's balance increased and the lockbox's balance decreased by the amount unlocked
        assertEq(address(AIHIPortal2).balance, portalBalanceBefore + _value);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore - _value);
    }

    /// @notice Tests the `authorizePortal` function reverts when the caller is not the proxy admin.
    function testFuzz_authorizePortal_unauthorized_reverts(address _caller) public {
        vm.assume(_caller != proxyAdminOwner);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_Unauthorized.selector);

        // Call the `authorizePortal` function with an unauthorized caller
        vm.prank(_caller);
        ethLockbox.authorizePortal(AIHIPortal2);
    }

    /// @notice Tests the `authorizePortal` function reverts when the proxy admin owner of the portal is not the same as
    /// the one of the lockbox.
    function testFuzz_authorizePortal_differentProxyAdminOwner_reverts(IAIHIPortal2 _portal) public {
        assumeNotForgeAddress(address(_portal));
        vm.mockCall(address(_portal), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(address(0)));

        // Expect the revert with `DifferentOwner` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_DifferentProxyAdminOwner.selector);

        // Call the `authorizePortal` function
        vm.prank(proxyAdminOwner);
        ethLockbox.authorizePortal(_portal);
    }

    /// @notice Tests the authorizePortal function reverts when the portal has a different
    ///         SuperchainConfig than the one configured in the lockbox.
    /// @param _portal The portal to authorize.
    function testFuzz_authorizePortal_differentSuperchainConfig_reverts(IAIHIPortal2 _portal) public {
        assumeNotForgeAddress(address(_portal));

        // Mock the portal to have the right proxyAdminOwner.
        vm.mockCall(
            address(_portal), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(proxyAdminOwner)
        );

        // Mock the portal to have the wrong SuperchainConfig.
        vm.mockCall(address(_portal), abi.encodeCall(IAIHIPortal.superchainConfig, ()), abi.encode(address(0)));

        // Expect the revert with `DifferentSuperchainConfig` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_DifferentSuperchainConfig.selector);

        // Call the `authorizePortal` function
        vm.prank(proxyAdminOwner);
        ethLockbox.authorizePortal(_portal);
    }

    /// @notice Tests the `authorizeLockbox` function succeeds using the `AIHIPortal2` address as the portal.
    function test_authorizePortal_succeeds() public {
        // Calculate the correct storage slot for the mapping value
        bytes32 mappingSlot = bytes32(uint256(1)); // position on the layout
        address key = address(AIHIPortal2);
        bytes32 slot = keccak256(abi.encode(key, mappingSlot));

        // Reset the authorization status to false
        vm.store(address(ethLockbox), slot, bytes32(0));

        // Expect the `PortalAuthorized` event to be emitted
        vm.expectEmit(address(ethLockbox));
        emit PortalAuthorized(AIHIPortal2);

        // Call the `authorizePortal` function with the portal
        vm.prank(proxyAdminOwner);
        ethLockbox.authorizePortal(AIHIPortal2);

        // Assert the portal is authorized
        assertTrue(ethLockbox.authorizedPortals(AIHIPortal2));
    }

    /// @notice Tests the `authorizeLockbox` function succeeds
    function testFuzz_authorizePortal_succeeds(IAIHIPortal2 _portal) public {
        assumeNotForgeAddress(address(_portal));

        // Mock the admin owner of the portal to be the same as the current lockbox proxy admin owner
        vm.mockCall(
            address(_portal), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(proxyAdminOwner)
        );

        // Mock the SuperchainConfig on the portal to be the same as the SuperchainConfig on the
        // Lockbox.
        vm.mockCall(
            address(_portal), abi.encodeCall(IAIHIPortal.superchainConfig, ()), abi.encode(superchainConfig)
        );

        // Expect the `PortalAuthorized` event to be emitted
        vm.expectEmit(address(ethLockbox));
        emit PortalAuthorized(_portal);

        // Call the `authorizePortal` function with the portal
        vm.prank(proxyAdminOwner);
        ethLockbox.authorizePortal(_portal);

        // Assert the portal is authorized
        assertTrue(ethLockbox.authorizedPortals(_portal));
    }

    /// @notice Tests the `authorizeLockbox` function reverts when the caller is not the proxy admin.
    function testFuzz_authorizeLockbox_unauthorized_reverts(address _caller) public {
        vm.assume(_caller != proxyAdminOwner);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_Unauthorized.selector);

        // Call the `authorizeLockbox` function with an unauthorized caller
        vm.prank(_caller);
        ethLockbox.authorizeLockbox(ethLockbox);
    }

    /// @notice Tests the `authorizeLockbox` function reverts when the proxy admin owner of the lockbox is not the same
    /// as the proxy admin owner of
    ///         the proxy admin.
    function testFuzz_authorizeLockbox_differentProxyAdminOwner_reverts(address _lockbox) public {
        assumeNotForgeAddress(_lockbox);

        vm.mockCall(address(_lockbox), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(address(0)));

        // Expect the revert with `ETHLockbox_DifferentProxyAdminOwner` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_DifferentProxyAdminOwner.selector);

        // Call the `authorizeLockbox` function with the lockbox
        vm.prank(proxyAdminOwner);
        ethLockbox.authorizeLockbox(IETHLockbox(_lockbox));
    }

    /// @notice Tests the `authorizeLockbox` function succeeds
    function testFuzz_authorizeLockbox_succeeds(address _lockbox) public {
        assumeNotForgeAddress(_lockbox);

        // Mock the admin owner of the lockbox to be the same as the current lockbox proxy admin owner
        vm.mockCall(
            address(_lockbox), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(proxyAdminOwner)
        );

        // Expect the `LockboxAuthorized` event to be emitted
        vm.expectEmit(address(ethLockbox));
        emit LockboxAuthorized(IETHLockbox(_lockbox));

        // Authorize the lockbox
        vm.prank(proxyAdminOwner);
        ethLockbox.authorizeLockbox(IETHLockbox(_lockbox));

        // Assert the lockbox is authorized
        assertTrue(ethLockbox.authorizedLockboxes(IETHLockbox(_lockbox)));
    }

    /// @notice Tests the `migrateLiquidity` function reverts when the caller is not the proxy admin.
    function testFuzz_migrateLiquidity_unauthorized_reverts(address _caller) public {
        vm.assume(_caller != proxyAdminOwner);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_Unauthorized.selector);

        // Call the `migrateLiquidity` function with an unauthorized caller
        vm.prank(_caller);
        ethLockbox.migrateLiquidity(ethLockbox);
    }

    /// @notice Tests the `migrateLiquidity` function reverts when the proxy admin owner of the lockbox is not the same
    /// as the proxy admin owner of
    ///         the proxy admin.
    function testFuzz_migrateLiquidity_differentProxyAdminOwner_reverts(address _lockbox) public {
        assumeNotForgeAddress(_lockbox);

        vm.mockCall(address(_lockbox), abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()), abi.encode(address(0)));

        // Expect the revert with `ETHLockbox_DifferentProxyAdminOwner` selector
        vm.expectRevert(IETHLockbox.ETHLockbox_DifferentProxyAdminOwner.selector);

        // Call the `migrateLiquidity` function with the lockbox
        vm.prank(proxyAdminOwner);
        ethLockbox.migrateLiquidity(IETHLockbox(_lockbox));
    }

    /// @notice Tests the `migrateLiquidity` function succeeds
    function testFuzz_migrateLiquidity_succeeds(
        uint256 _originLockboxBalance,
        uint256 _destinationLockboxBalance
    )
        public
    {
        // Since on the fork the `_lockbox` fuzzed address doesn't exist, we skip the test
        if (isForkTest()) vm.skip(true);

        // Bound balances to avoid overflow
        _originLockboxBalance = bound(_originLockboxBalance, 0, type(uint256).max - address(ethLockbox).balance);
        _destinationLockboxBalance = bound(_destinationLockboxBalance, 0, type(uint256).max - _originLockboxBalance);

        // Deploy a new Proxy for the destination lockbox
        address destinationLockbox = address(new Proxy(address(proxyAdmin)));

        // Get the ETHLockbox implementation of the origin `ethLockbox` proxy
        vm.prank(address(proxyAdmin));
        address implementation = Proxy(payable(address(ethLockbox))).implementation();

        // Upgrade the destination lockbox proxy to the `ETHLockbox` implementation
        vm.prank(address(proxyAdmin));
        Proxy(payable(destinationLockbox)).upgradeTo(implementation);

        // Authorize the origin lockbox on the destination lockbox
        vm.prank(proxyAdminOwner);
        IETHLockbox(destinationLockbox).authorizeLockbox(ethLockbox);

        // Mock the calls for checks on the destination lockbox so it can receive the migration
        vm.mockCall(
            address(destinationLockbox),
            abi.encodeCall(IProxyAdminOwnedBase.proxyAdminOwner, ()),
            abi.encode(proxyAdminOwner)
        );
        vm.mockCall(
            address(destinationLockbox), abi.encodeCall(IETHLockbox.authorizedLockboxes, (ethLockbox)), abi.encode(true)
        );

        // Deal the balance to both lockboxes
        deal(address(ethLockbox), _originLockboxBalance);
        deal(address(destinationLockbox), _destinationLockboxBalance);

        // Get balances before the migration
        uint256 originLockboxBalanceBefore = address(ethLockbox).balance;
        uint256 destLockboxBalanceBefore = address(destinationLockbox).balance;

        // Expect the `LiquidityMigrated` event to be emitted
        vm.expectEmit(address(ethLockbox));
        emit LiquidityMigrated(IETHLockbox(destinationLockbox), originLockboxBalanceBefore);

        // Call the `migrateLiquidity` function with the lockbox
        vm.prank(proxyAdminOwner);
        ethLockbox.migrateLiquidity(IETHLockbox(destinationLockbox));

        // Assert the liquidity was migrated
        assertEq(address(ethLockbox).balance, 0);
        assertEq(address(destinationLockbox).balance, destLockboxBalanceBefore + originLockboxBalanceBefore);
    }
}
