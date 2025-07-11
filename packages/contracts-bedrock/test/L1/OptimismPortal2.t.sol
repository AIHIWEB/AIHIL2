// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Forge
import { VmSafe } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";

// Testing
import { CommonTest } from "test/setup/CommonTest.sol";
import { NextImpl } from "test/mocks/NextImpl.sol";
import { EIP1967Helper } from "test/mocks/EIP1967Helper.sol";

// Scripts
import { ForgeArtifacts, StorageSlot } from "scripts/libraries/ForgeArtifacts.sol";

// Contracts
import { SuperchainConfig } from "src/L1/SuperchainConfig.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";

// Libraries
import { Types } from "src/libraries/Types.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { Constants } from "src/libraries/Constants.sol";
import { AddressAliasHelper } from "src/vendor/AddressAliasHelper.sol";
import { EIP1967Helper } from "test/mocks/EIP1967Helper.sol";
import "src/dispute/lib/Types.sol";

// Interfaces
import { IResourceMetering } from "interfaces/L1/IResourceMetering.sol";
import { IAIHIPortal2 as IAIHIPortal } from "interfaces/L1/IAIHIPortal2.sol";
import { IDisputeGame } from "interfaces/dispute/IDisputeGame.sol";
import { IFaultDisputeGame } from "interfaces/dispute/IFaultDisputeGame.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { IAnchorStateRegistry } from "interfaces/dispute/IAnchorStateRegistry.sol";
import { IETHLockbox } from "interfaces/L1/IETHLockbox.sol";

contract AIHIPortal2_Test is CommonTest {
    address depositor;

    function setUp() public virtual override {
        super.setUp();
        depositor = makeAddr("depositor");
    }

    /// @notice Tests that the version function returns a valid string. We avoid testing the
    ///         specific value of the string as it changes frequently.
    function test_version_succeeds() external view {
        assert(bytes(AIHIPortal2.version()).length > 0);
    }

    /// @dev Tests that the constructor sets the correct values.
    /// @notice Marked virtual to be overridden in
    ///         test/kontrol/deployment/DeploymentSummary.t.sol
    function test_constructor_succeeds() external virtual {
        IAIHIPortal opImpl = IAIHIPortal(payable(EIP1967Helper.getImplementation(address(AIHIPortal2))));
        assertEq(address(opImpl.anchorStateRegistry()), address(0));
        assertEq(address(opImpl.systemConfig()), address(0));
        assertEq(address(opImpl.superchainConfig()), address(0));
        assertEq(opImpl.l2Sender(), address(0));
        assertEq(address(opImpl.anchorStateRegistry()), address(0));
        assertEq(address(opImpl.ethLockbox()), address(0));
    }

    /// @dev Tests that the initializer sets the correct values.
    /// @notice Marked virtual to be overridden in
    ///         test/kontrol/deployment/DeploymentSummary.t.sol
    function test_initialize_succeeds() external virtual {
        assertEq(address(AIHIPortal2.anchorStateRegistry()), address(anchorStateRegistry));
        assertEq(address(AIHIPortal2.disputeGameFactory()), address(disputeGameFactory));
        assertEq(address(AIHIPortal2.superchainConfig()), address(superchainConfig));
        assertEq(AIHIPortal2.l2Sender(), Constants.DEFAULT_L2_SENDER);
        assertEq(AIHIPortal2.paused(), false);
        assertEq(address(AIHIPortal2.systemConfig()), address(systemConfig));
        assertEq(address(AIHIPortal2.ethLockbox()), address(ethLockbox));

        returnIfForkTest(
            "AIHIPortal2_Initialize_Test: Do not check guardian and respectedGameType on forked networks"
        );
        address guardian = superchainConfig.guardian();
        // This check is not valid for forked tests, as the guardian is not the same as the one in hardhat.json
        assertEq(guardian, deploy.cfg().superchainConfigGuardian());

        // This check is not valid on forked tests as the respectedGameType varies between OP Chains.
        assertEq(AIHIPortal2.respectedGameType().raw(), deploy.cfg().respectedGameType());
    }

    /// @dev Tests that the upgrade function succeeds.
    function testFuzz_upgrade_succeeds(address _newAnchorStateRegistry, uint256 _balance) external {
        // Prevent overflow on an upgrade context
        _balance = bound(_balance, 0, type(uint256).max - address(ethLockbox).balance);

        // Set the initialize state of the portal to false.
        vm.store(address(AIHIPortal2), bytes32(uint256(0)), bytes32(uint256(0)));

        // Set the balance of the portal and get the lockbox balance before the upgrade.
        deal(address(AIHIPortal2), _balance);
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;

        // Expect the ETH to be migrated to the lockbox.
        vm.expectCall(address(ethLockbox), _balance, abi.encodeCall(ethLockbox.lockETH, ()));

        // Call the upgrade function.
        vm.prank(Predeploys.PROXY_ADMIN);
        AIHIPortal2.upgrade(IAnchorStateRegistry(_newAnchorStateRegistry), IETHLockbox(ethLockbox));

        // Assert the portal is properly upgraded.
        assertEq(address(AIHIPortal2.ethLockbox()), address(ethLockbox));
        assertEq(address(AIHIPortal2.anchorStateRegistry()), _newAnchorStateRegistry);
        assertEq(address(AIHIPortal2).balance, 0);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _balance);
    }

    /// @dev Tests that `pause` successfully pauses
    ///      when called by the GUARDIAN.
    function test_pause_succeeds() external {
        address guardian = AIHIPortal2.guardian();

        assertEq(AIHIPortal2.paused(), false);

        vm.expectEmit(address(superchainConfig));
        emit Paused("identifier");

        vm.prank(guardian);
        superchainConfig.pause("identifier");

        assertEq(AIHIPortal2.paused(), true);
    }

    /// @dev Tests that `pause` reverts when called by a non-GUARDIAN.
    function test_pause_onlyGuardian_reverts() external {
        assertEq(AIHIPortal2.paused(), false);

        assertTrue(AIHIPortal2.guardian() != alice);
        vm.expectRevert("SuperchainConfig: only guardian can pause");
        vm.prank(alice);
        superchainConfig.pause("identifier");

        assertEq(AIHIPortal2.paused(), false);
    }

    /// @dev Tests that `unpause` successfully unpauses
    ///      when called by the GUARDIAN.
    function test_unpause_succeeds() external {
        address guardian = AIHIPortal2.guardian();

        vm.prank(guardian);
        superchainConfig.pause("identifier");
        assertEq(AIHIPortal2.paused(), true);

        vm.expectEmit(address(superchainConfig));
        emit Unpaused();
        vm.prank(guardian);
        superchainConfig.unpause();

        assertEq(AIHIPortal2.paused(), false);
    }

    /// @dev Tests that `unpause` reverts when called by a non-GUARDIAN.
    function test_unpause_onlyGuardian_reverts() external {
        address guardian = AIHIPortal2.guardian();

        vm.prank(guardian);
        superchainConfig.pause("identifier");
        assertEq(AIHIPortal2.paused(), true);

        assertTrue(AIHIPortal2.guardian() != alice);
        vm.expectRevert("SuperchainConfig: only guardian can unpause");
        vm.prank(alice);
        superchainConfig.unpause();

        assertEq(AIHIPortal2.paused(), true);
    }

    /// @dev Tests that `receive` successdully deposits ETH.
    function testFuzz_receive_succeeds(uint256 _value) external {
        // Prevent overflow on an upgrade context
        _value = bound(_value, 0, type(uint256).max - address(ethLockbox).balance);
        uint256 balanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;
        _value = bound(_value, 0, type(uint256).max - balanceBefore);

        vm.expectEmit(address(AIHIPortal2));
        emitTransactionDeposited({
            _from: alice,
            _to: alice,
            _value: _value,
            _mint: _value,
            _gasLimit: 100_000,
            _isCreation: false,
            _data: hex""
        });

        // Expect call to the ETHLockbox to lock the funds only if the value is greater than 0.
        vm.expectCall(address(ethLockbox), _value, abi.encodeCall(ethLockbox.lockETH, ()), _value > 0 ? 1 : 0);

        // give alice money and send as an eoa
        vm.deal(alice, _value);
        vm.prank(alice, alice);
        (bool s,) = address(AIHIPortal2).call{ value: _value }(hex"");

        assertTrue(s);
        assertEq(address(AIHIPortal2).balance, balanceBefore);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _value);
    }

    /// @dev Tests that `depositTransaction` reverts when the destination address is non-zero
    ///      for a contract creation deposit.
    function test_depositTransaction_contractCreation_reverts() external {
        // contract creation must have a target of address(0)
        vm.expectRevert(IAIHIPortal.AIHIPortal_BadTarget.selector);
        AIHIPortal2.depositTransaction(address(1), 1, 0, true, hex"");
    }

    /// @dev Tests that `depositTransaction` reverts when the data is too large.
    ///      This places an upper bound on unsafe blocks sent over p2p.
    function test_depositTransaction_largeData_reverts() external {
        uint256 size = 120_001;
        uint64 gasLimit = AIHIPortal2.minimumGasLimit(uint64(size));
        vm.expectRevert(IAIHIPortal.AIHIPortal_CalldataTooLarge.selector);
        AIHIPortal2.depositTransaction({
            _to: address(0),
            _value: 0,
            _gasLimit: gasLimit,
            _isCreation: false,
            _data: new bytes(size)
        });
    }

    /// @dev Tests that `depositTransaction` reverts when the gas limit is too small.
    function test_depositTransaction_smallGasLimit_reverts() external {
        vm.expectRevert(IAIHIPortal.AIHIPortal_GasLimitTooLow.selector);
        AIHIPortal2.depositTransaction({ _to: address(1), _value: 0, _gasLimit: 0, _isCreation: false, _data: hex"" });
    }

    /// @dev Tests that `depositTransaction` succeeds for small,
    ///      but sufficient, gas limits.
    function testFuzz_depositTransaction_smallGasLimit_succeeds(bytes memory _data, bool _shouldFail) external {
        uint64 gasLimit = AIHIPortal2.minimumGasLimit(uint64(_data.length));
        if (_shouldFail) {
            gasLimit = uint64(bound(gasLimit, 0, gasLimit - 1));
            vm.expectRevert(IAIHIPortal.AIHIPortal_GasLimitTooLow.selector);
        }

        AIHIPortal2.depositTransaction({
            _to: address(0x40),
            _value: 0,
            _gasLimit: gasLimit,
            _isCreation: false,
            _data: _data
        });
    }

    /// @dev Tests that `minimumGasLimit` succeeds for small calldata sizes.
    ///      The gas limit should be 21k for 0 calldata and increase linearly
    ///      for larger calldata sizes.
    function test_minimumGasLimit_succeeds() external view {
        assertEq(AIHIPortal2.minimumGasLimit(0), 21_000);
        assertTrue(AIHIPortal2.minimumGasLimit(2) > AIHIPortal2.minimumGasLimit(1));
        assertTrue(AIHIPortal2.minimumGasLimit(3) > AIHIPortal2.minimumGasLimit(2));
    }

    /// @dev Tests that `depositTransaction` succeeds for an EOA.
    function testFuzz_depositTransaction_eoa_succeeds(
        address _to,
        uint64 _gasLimit,
        uint256 _value,
        uint256 _mint,
        bool _isCreation,
        bytes memory _data
    )
        external
    {
        // Prevent overflow on an upgrade context
        _mint = bound(_mint, 0, type(uint256).max - address(ethLockbox).balance);
        _gasLimit = uint64(
            bound(
                _gasLimit,
                AIHIPortal2.minimumGasLimit(uint64(_data.length)),
                systemConfig.resourceConfig().maxResourceLimit
            )
        );
        if (_isCreation) _to = address(0);

        uint256 balanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;
        _mint = bound(_mint, 0, type(uint256).max - balanceBefore);

        // EOA emulation
        vm.expectEmit(address(AIHIPortal2));
        emitTransactionDeposited({
            _from: depositor,
            _to: _to,
            _value: _value,
            _mint: _mint,
            _gasLimit: _gasLimit,
            _isCreation: _isCreation,
            _data: _data
        });

        // Expect call to the ETHLockbox to lock the funds only if the value is greater than 0.
        vm.expectCall(address(ethLockbox), _mint, abi.encodeCall(ethLockbox.lockETH, ()), _mint > 0 ? 1 : 0);

        vm.deal(depositor, _mint);
        vm.prank(depositor, depositor);
        AIHIPortal2.depositTransaction{ value: _mint }({
            _to: _to,
            _value: _value,
            _gasLimit: _gasLimit,
            _isCreation: _isCreation,
            _data: _data
        });

        assertEq(address(AIHIPortal2).balance, balanceBefore);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _mint);
    }

    /// @dev Tests that `depositTransaction` succeeds for an EOA using 7702 delegation.
    function testFuzz_depositTransaction_eoa7702_succeeds(
        address _to,
        uint64 _gasLimit,
        uint256 _value,
        uint256 _mint,
        bool _isCreation,
        bytes memory _data,
        address _7702Target
    )
        external
    {
        assumeNotForgeAddress(_7702Target);
        // Prevent overflow on an upgrade context
        _mint = bound(_mint, 0, type(uint256).max - address(ethLockbox).balance);

        _gasLimit = uint64(
            bound(
                _gasLimit,
                AIHIPortal2.minimumGasLimit(uint64(_data.length)),
                systemConfig.resourceConfig().maxResourceLimit
            )
        );
        if (_isCreation) _to = address(0);

        uint256 portalBalanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;
        _mint = bound(_mint, 0, type(uint256).max - portalBalanceBefore);

        // EOA emulation
        vm.expectEmit(address(AIHIPortal2));
        emitTransactionDeposited({
            _from: depositor,
            _to: _to,
            _value: _value,
            _mint: _mint,
            _gasLimit: _gasLimit,
            _isCreation: _isCreation,
            _data: _data
        });

        // 7702 delegation using the 7702 prefix
        vm.etch(depositor, abi.encodePacked(hex"EF0100", _7702Target));

        vm.deal(depositor, _mint);
        vm.prank(depositor, address(0x0420));
        AIHIPortal2.depositTransaction{ value: _mint }({
            _to: _to,
            _value: _value,
            _gasLimit: _gasLimit,
            _isCreation: _isCreation,
            _data: _data
        });
        assertEq(address(AIHIPortal2).balance, portalBalanceBefore);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _mint);
    }

    /// @dev Tests that `depositTransaction` succeeds for a contract.
    function testFuzz_depositTransaction_contract_succeeds(
        address _to,
        uint64 _gasLimit,
        uint256 _value,
        uint256 _mint,
        bool _isCreation,
        bytes memory _data
    )
        external
    {
        // Prevent overflow on an upgrade context
        _mint = bound(_mint, 0, type(uint256).max - address(ethLockbox).balance);
        _gasLimit = uint64(
            bound(
                _gasLimit,
                AIHIPortal2.minimumGasLimit(uint64(_data.length)),
                systemConfig.resourceConfig().maxResourceLimit
            )
        );
        if (_isCreation) _to = address(0);

        uint256 balanceBefore = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;
        _mint = bound(_mint, 0, type(uint256).max - balanceBefore);

        vm.expectEmit(address(AIHIPortal2));
        emitTransactionDeposited({
            _from: AddressAliasHelper.applyL1ToL2Alias(address(this)),
            _to: _to,
            _value: _value,
            _mint: _mint,
            _gasLimit: _gasLimit,
            _isCreation: _isCreation,
            _data: _data
        });

        // Expect call to the ETHLockbox to lock the funds only if the value is greater than 0.
        vm.expectCall(address(ethLockbox), _mint, abi.encodeCall(ethLockbox.lockETH, ()), _mint > 0 ? 1 : 0);

        vm.deal(address(this), _mint);
        vm.prank(address(this));
        AIHIPortal2.depositTransaction{ value: _mint }({
            _to: _to,
            _value: _value,
            _gasLimit: _gasLimit,
            _isCreation: _isCreation,
            _data: _data
        });
        assertEq(address(AIHIPortal2).balance, balanceBefore);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _mint);
    }

    /// @dev Tests that the donateETH function donates ETH and does no state read/write
    function test_donateETH_succeeds(uint256 _amount) external {
        vm.startPrank(alice);
        vm.deal(alice, _amount);

        uint256 preBalance = address(AIHIPortal2).balance;
        uint256 lockboxBalanceBefore = address(ethLockbox).balance;
        _amount = bound(_amount, 0, type(uint256).max - preBalance);

        vm.startStateDiffRecording();
        AIHIPortal2.donateETH{ value: _amount }();
        VmSafe.AccountAccess[] memory accountAccesses = vm.stopAndReturnStateDiff();

        // not necessary since it's checked below
        assertEq(address(AIHIPortal2).balance, preBalance + _amount);
        // check that the ETHLockbox balance is unchanged
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore);

        // 0 for extcodesize of proxy before being called by this test,
        // 1 for the call to the proxy by the pranked address
        // 2 for the delegate call to the impl by the proxy
        assertEq(accountAccesses.length, 3);
        assertEq(uint8(accountAccesses[1].kind), uint8(VmSafe.AccountAccessKind.Call));
        assertEq(uint8(accountAccesses[2].kind), uint8(VmSafe.AccountAccessKind.DelegateCall));

        // to of 1 is the AIHI portal proxy
        assertEq(accountAccesses[1].account, address(AIHIPortal2));
        // accessor is the pranked address
        assertEq(accountAccesses[1].accessor, alice);
        // value is the amount of ETH donated
        assertEq(accountAccesses[1].value, _amount);
        // old balance is the balance of the AIHI portal before the donation
        assertEq(accountAccesses[1].oldBalance, preBalance);
        // new balance is the balance of the AIHI portal after the donation
        assertEq(accountAccesses[1].newBalance, preBalance + _amount);
        // data is the selector of the donateETH function
        assertEq(accountAccesses[1].data, abi.encodePacked(AIHIPortal2.donateETH.selector));
        // reverted of alice call to proxy is false
        assertEq(accountAccesses[1].reverted, false);
        // reverted of delegate call of proxy to impl is false
        assertEq(accountAccesses[2].reverted, false);
        // storage accesses of delegate call of proxy to impl is empty (No storage read or write!)
        assertEq(accountAccesses[2].storageAccesses.length, 0);
    }

    /// @dev Tests that `migrateToSuperRoots` reverts if the caller is not the proxy admin owner.
    function testFuzz_migrateToSuperRoots_notProxyAdminOwner_reverts(address _caller) external {
        vm.assume(_caller != AIHIPortal2.proxyAdminOwner());
        vm.expectRevert(IAIHIPortal.AIHIPortal_Unauthorized.selector);

        vm.prank(_caller);
        AIHIPortal2.migrateToSuperRoots(IETHLockbox(address(1)), IAnchorStateRegistry(address(1)));
    }

    /// @dev Tests that `migrateToSuperRoots` reverts if the new registry is the same as the
    ///      current one.
    /// @param _newLockbox The new ETHLockbox to migrate to.
    function testFuzz_migrateToSuperRoots_usingSameRegistry_reverts(address _newLockbox) external {
        vm.assume(_newLockbox != address(AIHIPortal2.ethLockbox()));

        // Use the same registry as the current one.
        IAnchorStateRegistry newAnchorStateRegistry = AIHIPortal2.anchorStateRegistry();

        // Trigger the call from the right address.
        address caller = AIHIPortal2.proxyAdminOwner();

        // Expect the migration to revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_MigratingToSameRegistry.selector);
        vm.prank(caller);
        AIHIPortal2.migrateToSuperRoots(IETHLockbox(_newLockbox), newAnchorStateRegistry);
    }

    /// @dev Tests that `migrateToSuperRoots` updates the ETHLockbox contract, updates the
    ///      AnchorStateRegistry, and sets the superRootsActive flag to true.
    /// @param _newLockbox The new ETHLockbox to migrate to.
    /// @param _newAnchorStateRegistry The new AnchorStateRegistry to migrate to.
    function testFuzz_migrateToSuperRoots_succeeds(address _newLockbox, address _newAnchorStateRegistry) external {
        address oldLockbox = address(AIHIPortal2.ethLockbox());
        address oldAnchorStateRegistry = address(AIHIPortal2.anchorStateRegistry());
        vm.assume(_newLockbox != oldLockbox);
        vm.assume(_newAnchorStateRegistry != oldAnchorStateRegistry);

        vm.expectEmit(address(AIHIPortal2));
        emit PortalMigrated(oldLockbox, _newLockbox, oldAnchorStateRegistry, _newAnchorStateRegistry);

        vm.prank(AIHIPortal2.proxyAdminOwner());
        AIHIPortal2.migrateToSuperRoots(IETHLockbox(_newLockbox), IAnchorStateRegistry(_newAnchorStateRegistry));

        assertEq(address(AIHIPortal2.ethLockbox()), _newLockbox);
        assertEq(address(AIHIPortal2.anchorStateRegistry()), _newAnchorStateRegistry);
        assertTrue(AIHIPortal2.superRootsActive());
    }
}

contract AIHIPortal2_FinalizeWithdrawal_Test is CommonTest {
    // Reusable default values for a test withdrawal
    Types.WithdrawalTransaction _defaultTx;
    IFaultDisputeGame game;
    uint256 _proposedGameIndex;
    uint256 _proposedBlockNumber;
    bytes32 _stateRoot;
    bytes32 _storageRoot;
    bytes32 _outputRoot;
    bytes32 _withdrawalHash;
    bytes[] _withdrawalProof;
    Types.OutputRootProof internal _outputRootProof;

    // Use a constructor to set the storage vars above, so as to minimize the number of ffi calls.
    constructor() {
        super.setUp();

        _defaultTx = Types.WithdrawalTransaction({
            nonce: 0,
            sender: alice,
            target: bob,
            value: 100,
            gasLimit: 100_000,
            data: hex"aa" // includes calldata for ERC20 withdrawal test
         });

        // Get withdrawal proof data we can use for testing.
        (_stateRoot, _storageRoot, _outputRoot, _withdrawalHash, _withdrawalProof) =
            ffi.getProveWithdrawalTransactionInputs(_defaultTx);

        // Setup a dummy output root proof for reuse.
        _outputRootProof = Types.OutputRootProof({
            version: bytes32(uint256(0)),
            stateRoot: _stateRoot,
            messagePasserStorageRoot: _storageRoot,
            latestBlockhash: bytes32(uint256(0))
        });
    }

    /// @dev Setup the system for a ready-to-use state.
    function setUp() public virtual override {
        if (isForkTest()) {
            // Set the proposed block number to be the next block number on the forked network
            (, _proposedBlockNumber) = anchorStateRegistry.getAnchorRoot();
            _proposedBlockNumber += 1;

            // Set the init bond of anchor game type 0 to be 0.
            // It is a mapping so the storage slot is calculated as keccak256(abi.encode(key, slot)).
            // The storage slot for the initBond mapping is 102, see `snapshots/storageLayout/DisputeGameFactory.json`.
            vm.store(
                address(disputeGameFactory), keccak256(abi.encode(GameType.wrap(0), uint256(102))), bytes32(uint256(0))
            );
        } else {
            // Set up the dummy game.
            _proposedBlockNumber = 0xFF;
        }

        // Warp forward in time to ensure that the game is created after the retirement timestamp.
        vm.warp(anchorStateRegistry.retirementTimestamp() + 1);

        GameType respectedGameType = AIHIPortal2.respectedGameType();
        game = IFaultDisputeGame(
            payable(
                address(
                    disputeGameFactory.create{ value: disputeGameFactory.initBonds(respectedGameType) }(
                        respectedGameType, Claim.wrap(_outputRoot), abi.encode(_proposedBlockNumber)
                    )
                )
            )
        );

        // Grab the index of the game we just created.
        _proposedGameIndex = disputeGameFactory.gameCount() - 1;

        // Warp beyond the chess clocks and finalize the game.
        vm.warp(block.timestamp + game.maxClockDuration().raw() + 1 seconds);

        // Fund the portal so that we can withdraw ETH.
        vm.deal(address(ethLockbox), 0xFFFFFFFF);
    }

    /// @dev Asserts that the reentrant call will revert.
    function callPortalAndExpectRevert() external payable {
        vm.expectRevert(IAIHIPortal.AIHIPortal_NoReentrancy.selector);
        // Arguments here don't matter, as the require check is the first thing that happens.
        // We assume that this has already been proven.
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
        // Assert that the withdrawal was not finalized.
        assertFalse(AIHIPortal2.finalizedWithdrawals(Hashing.hashWithdrawal(_defaultTx)));
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts when the target is the portal contract or the lockbox.
    function test_finalizeWithdrawalTransaction_badTarget_reverts() external {
        _defaultTx.target = address(AIHIPortal2);
        vm.expectRevert(IAIHIPortal.AIHIPortal_BadTarget.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        _defaultTx.target = address(ethLockbox);
        vm.expectRevert(IAIHIPortal.AIHIPortal_BadTarget.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @notice Sets the supeRootsActive variable to the provided value.
    /// @param _superRootsActive The value to set the superRootsActive variable to.
    function setSuperRootsActive(bool _superRootsActive) public {
        // Get the slot for superRootsActive.
        StorageSlot memory slot = ForgeArtifacts.getSlot("AIHIPortal2", "superRootsActive");

        // Load the existing storage slot value.
        bytes32 existingValue = vm.load(address(AIHIPortal2), bytes32(slot.slot));

        // Inject the bool into the existing storage slot value with a bitwise OR.
        // Shift the bool left by the offset of the storage slot and OR with existing value.
        bytes32 newValue =
            bytes32(uint256(uint8(_superRootsActive ? 1 : 0)) << slot.offset * 8 | uint256(existingValue));

        // Store the new value at the correct slot/offset.
        vm.store(address(AIHIPortal2), bytes32(slot.slot), newValue);
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when paused.
    function test_proveWithdrawalTransaction_paused_reverts() external {
        vm.prank(AIHIPortal2.guardian());
        superchainConfig.pause("identifier");

        vm.expectRevert(IAIHIPortal.AIHIPortal_CallPaused.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when the target is the portal contract.
    function test_proveWithdrawalTransaction_onSelfCall_reverts() external {
        _defaultTx.target = address(AIHIPortal2);
        vm.expectRevert(IAIHIPortal.AIHIPortal_BadTarget.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        _defaultTx.target = address(ethLockbox);
        vm.expectRevert(IAIHIPortal.AIHIPortal_BadTarget.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when the current timestamp is less
    ///      than or equal to the creation timestamp of the dispute game.
    function testFuzz_proveWithdrawalTransaction_timestampLessThanOrEqualToCreation_reverts(uint64 _timestamp)
        external
    {
        // Set the timestamp to be less than or equal to the creation timestamp of the dispute game.
        _timestamp = uint64(bound(_timestamp, 0, game.createdAt().raw()));
        vm.warp(_timestamp);

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidProofTimestamp.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when the outputRootProof does not match the output root
    function test_proveWithdrawalTransaction_onInvalidOutputRootProof_reverts() external {
        // Modify the version to invalidate the withdrawal proof.
        _outputRootProof.version = bytes32(uint256(1));
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidOutputRootProof.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when the withdrawal is missing.
    function test_proveWithdrawalTransaction_onInvalidWithdrawalProof_reverts() external {
        // modify the default test values to invalidate the proof.
        _defaultTx.data = hex"abcd";
        vm.expectRevert("MerkleTrie: path remainder must share all nibbles with key");
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when the withdrawal has already been proven, and the new
    ///      game has the `CHALLENGER_WINS` status.
    function test_proveWithdrawalTransaction_replayProveDifferentGameChallengerWins_reverts() external {
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Create a new dispute game, and mock both games to be CHALLENGER_WINS.
        IDisputeGame game2 = disputeGameFactory.create(
            AIHIPortal2.respectedGameType(), Claim.wrap(_outputRoot), abi.encode(_proposedBlockNumber + 1)
        );
        _proposedGameIndex = disputeGameFactory.gameCount() - 1;
        vm.mockCall(address(game), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));
        vm.mockCall(address(game2), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));

        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidDisputeGame.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts if the game was not the respected game type when created.
    function test_proveWithdrawalTransaction_wasNotRespectedGameTypeWhenCreated_reverts() external {
        vm.mockCall(address(game), abi.encodeCall(game.wasRespectedGameTypeWhenCreated, ()), abi.encode(false));
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidDisputeGame.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts if the game is a legacy game that does not implement
    ///      `wasRespectedGameTypeWhenCreated`.
    function test_proveWithdrawalTransaction_legacyGame_reverts() external {
        vm.mockCallRevert(address(game), abi.encodeCall(game.wasRespectedGameTypeWhenCreated, ()), "");
        vm.expectRevert(); // nosemgrep: sol-safety-expectrevert-no-args
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` succeeds if the game was created after the
    ///      game retirement timestamp.
    function testFuzz_proveWithdrawalTransaction_createdAfterRetirementTimestamp_succeeds(uint64 _createdAt) external {
        _createdAt = uint64(bound(_createdAt, AIHIPortal2.respectedGameTypeUpdatedAt() + 1, type(uint64).max - 1));
        vm.warp(_createdAt + 1);
        vm.mockCall(address(game), abi.encodeCall(game.createdAt, ()), abi.encode(uint64(_createdAt)));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts if the game was created before or at
    ///      the game retirement timestamp.
    function testFuzz_proveWithdrawalTransaction_createdBeforeOrAtRetirementTimestamp_reverts(uint64 _createdAt)
        external
    {
        _createdAt = uint64(bound(_createdAt, 0, AIHIPortal2.respectedGameTypeUpdatedAt()));
        vm.mockCall(address(game), abi.encodeCall(game.createdAt, ()), abi.encode(uint64(_createdAt)));
        vm.expectRevert(IAIHIPortal.AIHIPortal_ImproperDisputeGame.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` can be re-executed if the dispute game proven against has resolved
    ///      against the favor of the root claim.
    function test_proveWithdrawalTransaction_replayProveBadProposal_succeeds() external {
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Mock the status of the dispute game we just proved against to be CHALLENGER_WINS.
        vm.mockCall(address(game), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));

        // Create a new game to re-prove against
        disputeGameFactory.create(
            AIHIPortal2.respectedGameType(), Claim.wrap(_outputRoot), abi.encode(_proposedBlockNumber + 1)
        );
        _proposedGameIndex = disputeGameFactory.gameCount() - 1;

        // Warp 1 second into the future so we're not in the same block as the dispute game.
        vm.warp(block.timestamp + 1 seconds);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` can be re-executed if the dispute game proven against is no longer
    ///      of the respected game type.
    function test_proveWithdrawalTransaction_replayRespectedGameTypeChanged_succeeds() external {
        // Prove the withdrawal against a game with the current respected game type.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Create a new game.
        IDisputeGame newGame =
            disputeGameFactory.create(GameType.wrap(0), Claim.wrap(_outputRoot), abi.encode(_proposedBlockNumber + 1));

        // Update the respected game type to 0xbeef.
        vm.prank(AIHIPortal2.guardian());
        anchorStateRegistry.setRespectedGameType(GameType.wrap(0xbeef));

        // Create a new game and mock the game type as 0xbeef in the factory.
        vm.mockCall(
            address(disputeGameFactory),
            abi.encodeCall(disputeGameFactory.gameAtIndex, (_proposedGameIndex + 1)),
            abi.encode(GameType.wrap(0xbeef), Timestamp.wrap(uint64(block.timestamp)), IDisputeGame(address(newGame)))
        );

        // Warp 1 second into the future so we're not in the same block as the dispute game.
        vm.warp(block.timestamp + 1 seconds);

        // Re-proving should be successful against the new game.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex + 1,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when using the Output Roots version of
    ///      `proveWithdrawalTransaction` when `superRootsActive` is true.
    function test_proveWithdrawalTransaction_outputRootVersionWhenSuperRootsActive_reverts() external {
        // Set superRootsActive to true.
        setSuperRootsActive(true);

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_WrongProofMethod.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when using the Super Roots version of
    ///      `proveWithdrawalTransaction` when `superRootsActive` is false.
    function test_proveWithdrawalTransaction_superRootsVersionWhenSuperRootsInactive_reverts() external {
        // Set up a dummy super root proof.
        Types.OutputRootWithChainId[] memory outputRootWithChainIdArr = new Types.OutputRootWithChainId[](1);
        outputRootWithChainIdArr[0] =
            Types.OutputRootWithChainId({ root: _outputRoot, chainId: systemConfig.l2ChainId() });
        Types.SuperRootProof memory superRootProof = Types.SuperRootProof({
            version: 0x01,
            timestamp: uint64(block.timestamp),
            outputRoots: outputRootWithChainIdArr
        });

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_WrongProofMethod.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameProxy: game,
            _outputRootIndex: 0,
            _superRootProof: superRootProof,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when using the Super Roots version of
    ///      `proveWithdrawalTransaction` when the provided proof is invalid.
    function test_proveWithdrawalTransaction_superRootsVersionBadProof_reverts() external {
        // Enable super roots.
        setSuperRootsActive(true);

        // Set up a dummy super root proof.
        Types.OutputRootWithChainId[] memory outputRootWithChainIdArr = new Types.OutputRootWithChainId[](1);
        outputRootWithChainIdArr[0] =
            Types.OutputRootWithChainId({ root: _outputRoot, chainId: systemConfig.l2ChainId() });
        Types.SuperRootProof memory superRootProof = Types.SuperRootProof({
            version: 0x01,
            timestamp: uint64(block.timestamp),
            outputRoots: outputRootWithChainIdArr
        });

        // Should revert because the proof is wrong.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidSuperRootProof.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameProxy: game,
            _outputRootIndex: 0,
            _superRootProof: superRootProof,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when using the Super Roots version of
    ///      `proveWithdrawalTransaction` when the provided proof is valid but the index is out of
    ///      bounds.
    function test_proveWithdrawalTransaction_superRootsVersionBadIndex_reverts() external {
        // Enable super roots.
        setSuperRootsActive(true);

        // Set up a dummy super root proof.
        Types.OutputRootWithChainId[] memory outputRootWithChainIdArr = new Types.OutputRootWithChainId[](1);
        outputRootWithChainIdArr[0] =
            Types.OutputRootWithChainId({ root: _outputRoot, chainId: systemConfig.l2ChainId() });
        Types.SuperRootProof memory superRootProof = Types.SuperRootProof({
            version: 0x01,
            timestamp: uint64(block.timestamp),
            outputRoots: outputRootWithChainIdArr
        });

        // Figure out what the right hash would be.
        bytes32 expectedSuperRoot = Hashing.hashSuperRootProof(superRootProof);

        // Mock the game to return the expected super root.
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(expectedSuperRoot));

        // Should revert because the proof is wrong.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidOutputRootIndex.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameProxy: game,
            _outputRootIndex: outputRootWithChainIdArr.length, // out of bounds
            _superRootProof: superRootProof,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when using the Super Roots version of
    ///      `proveWithdrawalTransaction` when the provided proof is valid, index is correct, but
    ///      the output root has the wrong chain id.
    function test_proveWithdrawalTransaction_superRootsVersionBadChainId_reverts() external {
        // Enable super roots.
        setSuperRootsActive(true);

        // Set up a dummy super root proof.
        Types.OutputRootWithChainId[] memory outputRootWithChainIdArr = new Types.OutputRootWithChainId[](1);
        outputRootWithChainIdArr[0] = Types.OutputRootWithChainId({
            root: _outputRoot,
            chainId: systemConfig.l2ChainId() + 1 // wrong chain id
         });
        Types.SuperRootProof memory superRootProof = Types.SuperRootProof({
            version: 0x01,
            timestamp: uint64(block.timestamp),
            outputRoots: outputRootWithChainIdArr
        });

        // Figure out what the right hash would be.
        bytes32 expectedSuperRoot = Hashing.hashSuperRootProof(superRootProof);

        // Mock the game to return the expected super root.
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(expectedSuperRoot));

        // Should revert because the proof is wrong.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidOutputRootChainId.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameProxy: game,
            _outputRootIndex: 0,
            _superRootProof: superRootProof,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` reverts when using the Super Roots version of
    ///      `proveWithdrawalTransaction` when the provided proof is valid, index is correct, chain
    ///      id is correct, but the output root proof is invalid.
    function test_proveWithdrawalTransaction_superRootsVersionBadOutputRootProof_reverts() external {
        // Enable super roots.
        setSuperRootsActive(true);

        // Set up a dummy super root proof.
        Types.OutputRootWithChainId[] memory outputRootWithChainIdArr = new Types.OutputRootWithChainId[](1);
        outputRootWithChainIdArr[0] = Types.OutputRootWithChainId({
            root: keccak256(abi.encode(_outputRoot)), // random root so the proof is wrong
            chainId: systemConfig.l2ChainId()
        });
        Types.SuperRootProof memory superRootProof = Types.SuperRootProof({
            version: 0x01,
            timestamp: uint64(block.timestamp),
            outputRoots: outputRootWithChainIdArr
        });

        // Figure out what the right hash would be.
        bytes32 expectedSuperRoot = Hashing.hashSuperRootProof(superRootProof);

        // Mock the game to return the expected super root.
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(expectedSuperRoot));

        // Should revert because the proof is wrong.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidOutputRootProof.selector);
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameProxy: game,
            _outputRootIndex: 0,
            _superRootProof: superRootProof,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` succeeds when all parameters are valid.
    function test_proveWithdrawalTransaction_superRootsVersion_succeeds() external {
        // Enable super roots.
        setSuperRootsActive(true);

        // Set up a dummy super root proof.
        Types.OutputRootWithChainId[] memory outputRootWithChainIdArr = new Types.OutputRootWithChainId[](1);
        outputRootWithChainIdArr[0] =
            Types.OutputRootWithChainId({ root: _outputRoot, chainId: systemConfig.l2ChainId() });
        Types.SuperRootProof memory superRootProof = Types.SuperRootProof({
            version: 0x01,
            timestamp: uint64(block.timestamp),
            outputRoots: outputRootWithChainIdArr
        });

        // Figure out what the right hash would be.
        bytes32 expectedSuperRoot = Hashing.hashSuperRootProof(superRootProof);

        // Mock the game to return the expected super root.
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(expectedSuperRoot));

        // Should succeed.
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameProxy: game,
            _outputRootIndex: 0,
            _superRootProof: superRootProof,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `proveWithdrawalTransaction` succeeds.
    function test_proveWithdrawalTransaction_validWithdrawalProof_succeeds() external {
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts when attempting to replay using a secondary proof
    ///      submitter.
    function test_finalizeWithdrawalTransaction_secondProofReplay_reverts() external {
        uint256 bobBalanceBefore = address(bob).balance;

        // Submit the first proof for the withdrawal hash.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Submit a second proof for the same withdrawal hash.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(0xb0b));
        vm.prank(address(0xb0b));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp and resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1 seconds);

        vm.expectEmit(true, true, false, true);
        emit WithdrawalFinalized(_withdrawalHash, true);
        AIHIPortal2.finalizeWithdrawalTransactionExternalProof(_defaultTx, address(0xb0b));

        vm.expectRevert(IAIHIPortal.AIHIPortal_AlreadyFinalized.selector);
        AIHIPortal2.finalizeWithdrawalTransactionExternalProof(_defaultTx, address(this));

        assert(address(bob).balance == bobBalanceBefore + 100);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the target reverts and caller is the
    /// ESTIMATION_ADDRESS.
    function test_finalizeWithdrawalTransaction_targetFailsAndCallerIsEstimationAddress_reverts() external {
        vm.etch(bob, hex"fe"); // Contract with just the invalid opcode.

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        AIHIPortal2.proveWithdrawalTransaction(_defaultTx, _proposedGameIndex, _outputRootProof, _withdrawalProof);

        // Warp and resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1 seconds);

        vm.startPrank(alice, Constants.ESTIMATION_ADDRESS);
        vm.expectRevert(IAIHIPortal.AIHIPortal_GasEstimation.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` succeeds when _tx.data is empty.
    function test_finalizeWithdrawalTransaction_noTxData_succeeds() external {
        Types.WithdrawalTransaction memory _defaultTx_noData = Types.WithdrawalTransaction({
            nonce: 0,
            sender: alice,
            target: bob,
            value: 100,
            gasLimit: 100_000,
            data: hex""
        });
        // Get withdrawal proof data we can use for testing.
        (
            bytes32 _stateRoot_noData,
            bytes32 _storageRoot_noData,
            bytes32 _outputRoot_noData,
            bytes32 _withdrawalHash_noData,
            bytes[] memory _withdrawalProof_noData
        ) = ffi.getProveWithdrawalTransactionInputs(_defaultTx_noData);
        // Setup a dummy output root proof for reuse.
        Types.OutputRootProof memory _outputRootProof_noData = Types.OutputRootProof({
            version: bytes32(uint256(0)),
            stateRoot: _stateRoot_noData,
            messagePasserStorageRoot: _storageRoot_noData,
            latestBlockhash: bytes32(uint256(0))
        });
        IFaultDisputeGame game_noData = IFaultDisputeGame(
            payable(
                address(
                    disputeGameFactory.create(
                        AIHIPortal2.respectedGameType(),
                        Claim.wrap(_outputRoot_noData),
                        abi.encode(_proposedBlockNumber)
                    )
                )
            )
        );
        uint256 _proposedGameIndex_noData = disputeGameFactory.gameCount() - 1;
        // Warp beyond the chess clocks and finalize the game.
        vm.warp(block.timestamp + game_noData.maxClockDuration().raw() + 1 seconds);
        // Fund the portal so that we can withdraw ETH.
        vm.store(address(AIHIPortal2), bytes32(uint256(61)), bytes32(uint256(0xFFFFFFFF)));
        vm.deal(address(ethLockbox), 0xFFFFFFFF);

        uint256 bobBalanceBefore = bob.balance;

        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash_noData, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash_noData, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx_noData,
            _disputeGameIndex: _proposedGameIndex_noData,
            _outputRootProof: _outputRootProof_noData,
            _withdrawalProof: _withdrawalProof_noData
        });

        // Warp and resolve the dispute game.
        game_noData.resolveClaim(0, 0);
        game_noData.resolve();
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1 seconds);

        vm.expectEmit(true, true, false, true);
        emit WithdrawalFinalized(_withdrawalHash_noData, true);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx_noData);

        assert(bob.balance == bobBalanceBefore + 100);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` succeeds.
    function test_finalizeWithdrawalTransaction_provenWithdrawalHashEther_succeeds() external {
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp and resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1 seconds);

        vm.expectEmit(true, true, false, true);
        emit WithdrawalFinalized(_withdrawalHash, true);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        assert(address(bob).balance == bobBalanceBefore + 100);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` succeeds using a different proof than an earlier one by another
    ///      party.
    function test_finalizeWithdrawalTransaction_secondaryProof_succeeds() external {
        uint256 bobBalanceBefore = address(bob).balance;

        // Create a secondary dispute game.
        IDisputeGame secondGame = disputeGameFactory.create(
            AIHIPortal2.respectedGameType(), Claim.wrap(_outputRoot), abi.encode(_proposedBlockNumber + 1)
        );

        // Warp 1 second into the future so that the proof is submitted after the timestamp of game creation.
        vm.warp(block.timestamp + 1);

        // Prove the withdrawal transaction against the invalid dispute game, as 0xb0b.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(0xb0b));
        vm.prank(address(0xb0b));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex + 1,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Mock the status of the dispute game 0xb0b proves against to be CHALLENGER_WINS.
        vm.mockCall(address(secondGame), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));

        // Prove the withdrawal transaction against the invalid dispute game, as the test contract, against the original
        // game.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp and resolve the original dispute game.
        game.resolveClaim(0, 0);
        game.resolve();
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1 seconds);

        // Ensure both proofs are registered successfully.
        assertEq(AIHIPortal2.numProofSubmitters(_withdrawalHash), 2);

        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        vm.prank(address(0xb0b));
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        vm.expectEmit(true, true, false, true);
        emit WithdrawalFinalized(_withdrawalHash, true);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        assert(address(bob).balance == bobBalanceBefore + 100);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the contract is paused.
    function test_finalizeWithdrawalTransaction_paused_reverts() external {
        vm.prank(AIHIPortal2.guardian());
        superchainConfig.pause("identifier");

        vm.expectRevert(IAIHIPortal.AIHIPortal_CallPaused.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the withdrawal has not been
    function test_finalizeWithdrawalTransaction_ifWithdrawalNotProven_reverts() external {
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectRevert(IAIHIPortal.AIHIPortal_Unproven.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        assert(address(bob).balance == bobBalanceBefore);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the withdrawal has not been
    ///      proven long enough ago.
    function test_finalizeWithdrawalTransaction_ifWithdrawalProofNotOldEnough_reverts() external {
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        vm.expectRevert(IAIHIPortal.AIHIPortal_ProofNotOldEnough.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        assert(address(bob).balance == bobBalanceBefore);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the provenWithdrawal's timestamp
    ///      is less than the dispute game's creation timestamp.
    function test_finalizeWithdrawalTransaction_timestampLessThanGameCreation_reverts() external {
        uint256 bobBalanceBefore = address(bob).balance;

        // Prove our withdrawal
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp to after the finalization period
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Mock a createdAt change in the dispute game.
        vm.mockCall(address(game), abi.encodeCall(game.createdAt, ()), abi.encode(block.timestamp + 1));

        // Attempt to finalize the withdrawal
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidProofTimestamp.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Ensure that bob's balance has remained the same
        assertEq(bobBalanceBefore, address(bob).balance);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the dispute game has not resolved in favor of the
    ///      root claim.
    function test_finalizeWithdrawalTransaction_ifDisputeGameNotResolved_reverts() external {
        uint256 bobBalanceBefore = address(bob).balance;

        // Prove our withdrawal
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp to after the finalization period
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Attempt to finalize the withdrawal
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Ensure that bob's balance has remained the same
        assertEq(bobBalanceBefore, address(bob).balance);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the target reverts.
    function test_finalizeWithdrawalTransaction_targetFails_fails() external {
        uint256 bobBalanceBefore = address(bob).balance;
        vm.etch(bob, hex"fe"); // Contract with just the invalid opcode.

        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalFinalized(_withdrawalHash, false);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        assert(address(bob).balance == bobBalanceBefore);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the withdrawal has already been
    ///      finalized.
    function test_finalizeWithdrawalTransaction_onReplay_reverts() external {
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalFinalized(_withdrawalHash, true);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        vm.expectRevert(IAIHIPortal.AIHIPortal_AlreadyFinalized.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the withdrawal transaction
    ///      does not have enough gas to execute.
    function test_finalizeWithdrawalTransaction_onInsufficientGas_reverts() external {
        // This number was identified through trial and error.
        uint256 gasLimit = 150_000;
        Types.WithdrawalTransaction memory insufficientGasTx = Types.WithdrawalTransaction({
            nonce: 0,
            sender: alice,
            target: bob,
            value: 100,
            gasLimit: gasLimit,
            data: hex""
        });

        // Get updated proof inputs.
        (bytes32 stateRoot, bytes32 storageRoot,,, bytes[] memory withdrawalProof) =
            ffi.getProveWithdrawalTransactionInputs(insufficientGasTx);
        Types.OutputRootProof memory outputRootProof = Types.OutputRootProof({
            version: bytes32(0),
            stateRoot: stateRoot,
            messagePasserStorageRoot: storageRoot,
            latestBlockhash: bytes32(0)
        });

        vm.mockCall(
            address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(Hashing.hashOutputRootProof(outputRootProof))
        );

        AIHIPortal2.proveWithdrawalTransaction({
            _tx: insufficientGasTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: outputRootProof,
            _withdrawalProof: withdrawalProof
        });

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);
        vm.expectRevert("SafeCall: Not enough gas");
        AIHIPortal2.finalizeWithdrawalTransaction{ gas: gasLimit }(insufficientGasTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if a sub-call attempts to finalize
    ///      another withdrawal.
    function test_finalizeWithdrawalTransaction_onReentrancy_reverts() external {
        uint256 bobBalanceBefore = address(bob).balance;

        // Copy and modify the default test values to attempt a reentrant call by first calling to
        // this contract's callPortalAndExpectRevert() function above.
        Types.WithdrawalTransaction memory _testTx = _defaultTx;
        _testTx.target = address(this);
        _testTx.data = abi.encodeCall(this.callPortalAndExpectRevert, ());

        // Get modified proof inputs.
        (
            bytes32 stateRoot,
            bytes32 storageRoot,
            bytes32 outputRoot,
            bytes32 withdrawalHash,
            bytes[] memory withdrawalProof
        ) = ffi.getProveWithdrawalTransactionInputs(_testTx);
        Types.OutputRootProof memory outputRootProof = Types.OutputRootProof({
            version: bytes32(0),
            stateRoot: stateRoot,
            messagePasserStorageRoot: storageRoot,
            latestBlockhash: bytes32(0)
        });

        // Return a mock output root from the game.
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(outputRoot));

        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(withdrawalHash, alice, address(this));
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction(_testTx, _proposedGameIndex, outputRootProof, withdrawalProof);

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);
        vm.expectCall(address(this), _testTx.data);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalFinalized(withdrawalHash, true);
        AIHIPortal2.finalizeWithdrawalTransaction(_testTx);

        // Ensure that bob's balance was not changed by the reentrant call.
        assert(address(bob).balance == bobBalanceBefore);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` succeeds.
    function testDiff_finalizeWithdrawalTransaction_succeeds(
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasLimit,
        bytes memory _data
    )
        external
    {
        skipIfForkTest("Skipping on forked tests because of the L2ToL1MessageParser call below");

        vm.assume(
            _target != address(AIHIPortal2) // Cannot call the AIHI portal or a contract
                && _target.code.length == 0 // No accounts with code
                && _target != CONSOLE // The console has no code but behaves like a contract
                && uint160(_target) > 9 // No precompiles (or zero address)
        );

        // Total ETH supply is currently about 120M ETH.
        uint256 value = bound(_value, 0, 200_000_000 ether);
        vm.deal(address(ethLockbox), value);

        uint256 gasLimit = bound(_gasLimit, 0, 50_000_000);
        uint256 nonce = l2ToL1MessagePasser.messageNonce();

        // Get a withdrawal transaction and mock proof from the differential testing script.
        Types.WithdrawalTransaction memory _tx = Types.WithdrawalTransaction({
            nonce: nonce,
            sender: _sender,
            target: _target,
            value: value,
            gasLimit: gasLimit,
            data: _data
        });
        (
            bytes32 stateRoot,
            bytes32 storageRoot,
            bytes32 outputRoot,
            bytes32 withdrawalHash,
            bytes[] memory withdrawalProof
        ) = ffi.getProveWithdrawalTransactionInputs(_tx);

        // Create the output root proof
        Types.OutputRootProof memory proof = Types.OutputRootProof({
            version: bytes32(uint256(0)),
            stateRoot: stateRoot,
            messagePasserStorageRoot: storageRoot,
            latestBlockhash: bytes32(uint256(0))
        });

        // Ensure the values returned from ffi are correct
        assertEq(outputRoot, Hashing.hashOutputRootProof(proof));
        assertEq(withdrawalHash, Hashing.hashWithdrawal(_tx));

        // Setup the dispute game to return the output root
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(outputRoot));

        // Prove the withdrawal transaction
        AIHIPortal2.proveWithdrawalTransaction(_tx, _proposedGameIndex, proof, withdrawalProof);
        (IDisputeGame _game,) = AIHIPortal2.provenWithdrawals(withdrawalHash, address(this));
        assertTrue(_game.rootClaim().raw() != bytes32(0));

        // Resolve the dispute game
        game.resolveClaim(0, 0);
        game.resolve();

        // Warp past the finalization period
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Finalize the withdrawal transaction
        vm.expectCallMinGas(_tx.target, _tx.value, uint64(_tx.gasLimit), _tx.data);
        AIHIPortal2.finalizeWithdrawalTransaction(_tx);
        assertTrue(AIHIPortal2.finalizedWithdrawals(withdrawalHash));
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` succeeds even if the respected game type is changed.
    function test_finalizeWithdrawalTransaction_wasRespectedGameType_succeeds(
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasLimit,
        bytes memory _data,
        GameType _newGameType
    )
        external
    {
        skipIfForkTest("Skipping on forked tests because of the L2ToL1MessageParser call below");

        vm.assume(
            _target != address(AIHIPortal2) // Cannot call the AIHI portal or a contract
                && _target.code.length == 0 // No accounts with code
                && _target != CONSOLE // The console has no code but behaves like a contract
                && uint160(_target) > 9 // No precompiles (or zero address)
        );

        // Bound to prevent changes in respectedGameTypeUpdatedAt
        _newGameType = GameType.wrap(uint32(bound(_newGameType.raw(), 0, type(uint32).max - 1)));

        // Total ETH supply is currently about 120M ETH.
        uint256 value = bound(_value, 0, 200_000_000 ether);
        vm.deal(address(ethLockbox), value);

        uint256 gasLimit = bound(_gasLimit, 0, 50_000_000);
        uint256 nonce = l2ToL1MessagePasser.messageNonce();

        // Get a withdrawal transaction and mock proof from the differential testing script.
        Types.WithdrawalTransaction memory _tx = Types.WithdrawalTransaction({
            nonce: nonce,
            sender: _sender,
            target: _target,
            value: value,
            gasLimit: gasLimit,
            data: _data
        });
        (
            bytes32 stateRoot,
            bytes32 storageRoot,
            bytes32 outputRoot,
            bytes32 withdrawalHash,
            bytes[] memory withdrawalProof
        ) = ffi.getProveWithdrawalTransactionInputs(_tx);

        // Create the output root proof
        Types.OutputRootProof memory proof = Types.OutputRootProof({
            version: bytes32(uint256(0)),
            stateRoot: stateRoot,
            messagePasserStorageRoot: storageRoot,
            latestBlockhash: bytes32(uint256(0))
        });

        // Ensure the values returned from ffi are correct
        assertEq(outputRoot, Hashing.hashOutputRootProof(proof));
        assertEq(withdrawalHash, Hashing.hashWithdrawal(_tx));

        // Setup the dispute game to return the output root
        vm.mockCall(address(game), abi.encodeCall(game.rootClaim, ()), abi.encode(outputRoot));

        // Prove the withdrawal transaction
        AIHIPortal2.proveWithdrawalTransaction(_tx, _proposedGameIndex, proof, withdrawalProof);
        (IDisputeGame _game,) = AIHIPortal2.provenWithdrawals(withdrawalHash, address(this));
        assertTrue(_game.rootClaim().raw() != bytes32(0));

        // Resolve the dispute game
        game.resolveClaim(0, 0);
        game.resolve();

        // Warp past the finalization period
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Change the respectedGameType
        vm.prank(AIHIPortal2.guardian());
        anchorStateRegistry.setRespectedGameType(_newGameType);

        // Withdrawal transaction still finalizable
        vm.expectCallMinGas(_tx.target, _tx.value, uint64(_tx.gasLimit), _tx.data);
        AIHIPortal2.finalizeWithdrawalTransaction(_tx);
        assertTrue(AIHIPortal2.finalizedWithdrawals(withdrawalHash));
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the withdrawal's dispute game has been blacklisted.
    function test_finalizeWithdrawalTransaction_blacklisted_reverts() external {
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        vm.prank(AIHIPortal2.guardian());
        anchorStateRegistry.blacklistDisputeGame(IDisputeGame(address(game)));

        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the withdrawal's dispute game is still in the air
    ///      gap.
    function test_finalizeWithdrawalTransaction_gameInAirGap_reverts() external {
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp past the finalization period.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        // Attempt to finalize the withdrawal directly after the game resolves. This should fail.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Finalize the withdrawal transaction. This should succeed.
        vm.warp(block.timestamp + AIHIPortal2.disputeGameFinalityDelaySeconds() + 1);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
        assertTrue(AIHIPortal2.finalizedWithdrawals(_withdrawalHash));
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the respected game type was updated after the
    ///      dispute game was created.
    function test_finalizeWithdrawalTransaction_gameOlderThanRespectedGameTypeUpdate_reverts() external {
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp past the finalization period.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        // Warp past the dispute game finality delay.
        vm.warp(block.timestamp + AIHIPortal2.disputeGameFinalityDelaySeconds() + 1);

        // Set respectedGameTypeUpdatedAt.
        vm.prank(AIHIPortal2.guardian());
        anchorStateRegistry.updateRetirementTimestamp();

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the game was not the respected game type when it was
    /// created. `proveWithdrawalTransaction` should already prevent this, but we remove that assumption here.
    function test_finalizeWithdrawalTransaction_gameWasNotRespectedGameType_reverts() external {
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp past the finalization period.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        // Warp past the dispute game finality delay.
        vm.warp(block.timestamp + AIHIPortal2.disputeGameFinalityDelaySeconds() + 1);

        vm.mockCall(address(game), abi.encodeCall(game.wasRespectedGameTypeWhenCreated, ()), abi.encode(false));

        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests that `finalizeWithdrawalTransaction` reverts if the game is a legacy game that does not implement
    ///      `wasRespectedGameTypeWhenCreated`.  `proveWithdrawalTransaction` should already prevent this, but we remove
    ///      that assumption here.
    function test_finalizeWithdrawalTransaction_legacyGame_reverts() external {
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(address(AIHIPortal2));
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp past the finalization period.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();

        // Warp past the dispute game finality delay.
        vm.warp(block.timestamp + AIHIPortal2.disputeGameFinalityDelaySeconds() + 1);

        // Mock the wasRespectedGameTypeWhenCreated call to revert.
        vm.mockCallRevert(address(game), abi.encodeCall(game.wasRespectedGameTypeWhenCreated, ()), "");

        // Should revert.
        vm.expectRevert(); // nosemgrep: sol-safety-expectrevert-no-args
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
    }

    /// @dev Tests an e2e prove -> finalize path, checking the edges of each delay for correctness.
    function test_finalizeWithdrawalTransaction_delayEdges_succeeds() external {
        // Prove the withdrawal transaction.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Attempt to finalize the withdrawal transaction 1 second before the proof has matured. This should fail.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds());
        vm.expectRevert(IAIHIPortal.AIHIPortal_ProofNotOldEnough.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Warp 1 second in the future, past the proof maturity delay, and attempt to finalize the withdrawal.
        // This should also fail, since the dispute game has not resolved yet.
        vm.warp(block.timestamp + 1 seconds);
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Finalize the dispute game and attempt to finalize the withdrawal again. This should also fail, since the
        // air gap dispute game delay has not elapsed.
        game.resolveClaim(0, 0);
        game.resolve();
        vm.warp(block.timestamp + AIHIPortal2.disputeGameFinalityDelaySeconds());
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Warp 1 second in the future, past the air gap dispute game delay, and attempt to finalize the withdrawal.
        // This should succeed.
        vm.warp(block.timestamp + 1 seconds);
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);
        assertTrue(AIHIPortal2.finalizedWithdrawals(_withdrawalHash));
    }

    /// @notice Tests that checkWithdrawal succeeds if the withdrawal has been proven, the dispute
    /// game has been finalized, and the root claim is valid.
    function test_checkWithdrawal_succeeds() external {
        // Prove the withdrawal transaction.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp past the finalization period.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Mark the dispute game as CHALLENGER_WINS.
        vm.mockCall(address(game), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));

        // Mock isGameClaimValid to return true.
        vm.mockCall(
            address(anchorStateRegistry), abi.encodeCall(anchorStateRegistry.isGameClaimValid, (game)), abi.encode(true)
        );

        // Should succeed.
        AIHIPortal2.checkWithdrawal(_withdrawalHash, address(this));
    }

    /// @notice Tests that checkWithdrawal reverts if the withdrawal has already been finalized.
    function test_checkWithdrawal_ifAlreadyFinalized_reverts() external {
        // Prove the withdrawal transaction.
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProven(_withdrawalHash, alice, bob);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalProvenExtension1(_withdrawalHash, address(this));
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp and resolve the dispute game.
        game.resolveClaim(0, 0);
        game.resolve();
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Finalize the withdrawal.
        AIHIPortal2.finalizeWithdrawalTransaction(_defaultTx);

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_AlreadyFinalized.selector);
        AIHIPortal2.checkWithdrawal(_withdrawalHash, address(this));
    }

    /// @notice Tests that checkWithdrawal reverts if the withdrawal has not been proven.
    function test_checkWithdrawal_ifUnproven_reverts() external {
        // Don't prove the withdrawal transaction.
        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_Unproven.selector);
        AIHIPortal2.checkWithdrawal(_withdrawalHash, address(this));
    }

    /// @notice Tests that checkWithdrawal reverts if the proof timestamp is greater than the game
    /// creation timestamp.
    function testFuzz_checkWithdrawal_ifInvalidProofTimestamp_reverts(uint64 _createdAt) external {
        // Prove the withdrawal transaction.
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Mock the game creation timestamp to be greater than the proof timestamp.
        _createdAt = uint64(bound(_createdAt, block.timestamp, type(uint64).max));
        vm.mockCall(address(game), abi.encodeCall(game.createdAt, ()), abi.encode(_createdAt));

        // Warp beyond the proof maturity delay.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Mark the dispute game as CHALLENGER_WINS.
        vm.mockCall(address(game), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));

        // Mock isGameClaimValid to return true.
        vm.mockCall(
            address(anchorStateRegistry), abi.encodeCall(anchorStateRegistry.isGameClaimValid, (game)), abi.encode(true)
        );

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidProofTimestamp.selector);
        AIHIPortal2.checkWithdrawal(_withdrawalHash, address(this));
    }

    /// @notice Tests that checkWithdrawal reverts if the proof timestamp is less than the proof
    /// maturity delay.
    function test_checkWithdrawal_ifProofNotOldEnough_reverts() external {
        // Prove but don't warp ahead past the proof maturity delay.
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Should revert.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() - 1);
        vm.expectRevert(IAIHIPortal.AIHIPortal_ProofNotOldEnough.selector);
        AIHIPortal2.checkWithdrawal(_withdrawalHash, address(this));
    }

    /// @notice Tests that checkWithdrawal reverts if the root claim is invalid.
    function test_checkWithdrawal_ifInvalidRootClaim_reverts() external {
        // Prove the withdrawal.
        AIHIPortal2.proveWithdrawalTransaction({
            _tx: _defaultTx,
            _disputeGameIndex: _proposedGameIndex,
            _outputRootProof: _outputRootProof,
            _withdrawalProof: _withdrawalProof
        });

        // Warp past the proof maturity delay.
        vm.warp(block.timestamp + AIHIPortal2.proofMaturityDelaySeconds() + 1);

        // Mock the game to have CHALLENGER_WINS status
        vm.mockCall(address(game), abi.encodeCall(game.status, ()), abi.encode(GameStatus.CHALLENGER_WINS));

        // Should revert.
        vm.expectRevert(IAIHIPortal.AIHIPortal_InvalidRootClaim.selector);
        AIHIPortal2.checkWithdrawal(_withdrawalHash, address(this));
    }
}

contract AIHIPortal2_Upgradeable_Test is CommonTest {
    function setUp() public override {
        super.setUp();
    }

    /// @dev Tests that the proxy is initialized correctly.
    function test_params_initValuesOnProxy_succeeds() external {
        skipIfForkTest("AIHIPortal2_Test: resource config varies on mainnet");
        (uint128 prevBaseFee, uint64 prevBoughtGas, uint64 prevBlockNum) = AIHIPortal2.params();
        IResourceMetering.ResourceConfig memory rcfg = systemConfig.resourceConfig();

        assertEq(prevBaseFee, rcfg.minimumBaseFee);
        assertEq(prevBoughtGas, 0);
        assertEq(prevBlockNum, block.number);
    }

    /// @dev Tests that the proxy can be upgraded.
    function test_upgradeToAndCall_upgrading_succeeds() external {
        // Check an unused slot before upgrading.
        bytes32 slot21Before = vm.load(address(AIHIPortal2), bytes32(uint256(21)));
        assertEq(bytes32(0), slot21Before);

        NextImpl nextImpl = new NextImpl();

        vm.startPrank(EIP1967Helper.getAdmin(address(AIHIPortal2)));
        // The value passed to the initialize must be larger than the last value
        // that initialize was called with.
        IProxy(payable(address(AIHIPortal2))).upgradeToAndCall(
            address(nextImpl), abi.encodeCall(NextImpl.initialize, (3))
        );
        assertEq(IProxy(payable(address(AIHIPortal2))).implementation(), address(nextImpl));

        // Verify that the NextImpl contract initialized its values according as expected
        bytes32 slot21After = vm.load(address(AIHIPortal2), bytes32(uint256(21)));
        bytes32 slot21Expected = NextImpl(address(AIHIPortal2)).slot21Init();
        assertEq(slot21Expected, slot21After);
    }
}

contract AIHIPortal2_LiquidityMigration_Test is CommonTest {
    function setUp() public override {
        super.setUp();
    }

    /// @notice Tests the liquidity migration from the portal to the lockbox reverts if not called by the admin owner.
    function testFuzz_migrateLiquidity_notProxyAdminOwner_reverts(address _caller) external {
        vm.assume(_caller != AIHIPortal2.proxyAdminOwner());
        vm.expectRevert(IAIHIPortal.AIHIPortal_Unauthorized.selector);
        vm.prank(_caller);
        AIHIPortal2.migrateLiquidity();
    }

    /// @notice Tests that the liquidity migration from the portal to the lockbox succeeds.
    function test_migrateLiquidity_succeeds(uint256 _portalBalance) external {
        _portalBalance = uint256(bound(_portalBalance, 0, type(uint256).max - address(ethLockbox).balance));
        vm.deal(address(AIHIPortal2), _portalBalance);

        uint256 lockboxBalanceBefore = address(ethLockbox).balance;
        address proxyAdminOwner = AIHIPortal2.proxyAdminOwner();

        vm.expectCall(address(ethLockbox), _portalBalance, abi.encodeCall(ethLockbox.lockETH, ()));

        vm.expectEmit(address(AIHIPortal2));
        emit ETHMigrated(address(ethLockbox), _portalBalance);

        vm.prank(proxyAdminOwner);
        AIHIPortal2.migrateLiquidity();

        assertEq(address(AIHIPortal2).balance, 0);
        assertEq(address(ethLockbox).balance, lockboxBalanceBefore + _portalBalance);
    }
}

/// @title AIHIPortal2_upgrade_Test
/// @notice Reusable test for the current upgrade() function in the AIHIPortal2 contract. If
///         the upgrade() function is changed, tests inside of this contract should be updated to
///         reflect the new function. If the upgrade() function is removed, remove the
///         corresponding tests but leave this contract in place so it's easy to add tests back
///         in the future.
contract AIHIPortal2_upgrade_Test is CommonTest {
    function setUp() public override {
        super.setUp();
    }

    /// @notice Tests that the upgrade() function succeeds.
    function test_upgrade_succeeds() external {
        // Get the slot for _initialized.
        StorageSlot memory slot = ForgeArtifacts.getSlot("AIHIPortal2", "_initialized");

        // Set the initialized slot to 0.
        vm.store(address(AIHIPortal2), bytes32(slot.slot), bytes32(0));

        // Trigger upgrade().
        AIHIPortal2.upgrade(IAnchorStateRegistry(address(0xdeadbeef)), IETHLockbox(ethLockbox));

        // Verify that the initialized slot was updated.
        bytes32 initializedSlotAfter = vm.load(address(AIHIPortal2), bytes32(slot.slot));
        assertEq(initializedSlotAfter, bytes32(uint256(2)));

        // Verify that the AnchorStateRegistry was set.
        assertEq(address(AIHIPortal2.anchorStateRegistry()), address(0xdeadbeef));
    }

    /// @notice Tests that the upgrade() function reverts if called a second time.
    function test_upgrade_upgradeTwice_reverts() external {
        // Get the slot for _initialized.
        StorageSlot memory slot = ForgeArtifacts.getSlot("AIHIPortal2", "_initialized");

        // Set the initialized slot to 0.
        vm.store(address(AIHIPortal2), bytes32(slot.slot), bytes32(0));

        // Trigger first upgrade.
        AIHIPortal2.upgrade(IAnchorStateRegistry(address(0xdeadbeef)), IETHLockbox(ethLockbox));

        // Try to trigger second upgrade.
        vm.expectRevert("Initializable: contract is already initialized");
        AIHIPortal2.upgrade(IAnchorStateRegistry(address(0xdeadbeef)), IETHLockbox(ethLockbox));
    }

    /// @notice Tests that the upgrade() function reverts if called after initialization.
    function test_upgrade_afterInitialization_reverts() external {
        // Get the slot for _initialized.
        StorageSlot memory slot = ForgeArtifacts.getSlot("AIHIPortal2", "_initialized");

        // Slot value should be set to 2 (already initialized).
        bytes32 initializedSlotBefore = vm.load(address(AIHIPortal2), bytes32(slot.slot));
        assertEq(initializedSlotBefore, bytes32(uint256(2)));

        // AnchorStateRegistry address should be non-zero.
        assertNotEq(address(AIHIPortal2.anchorStateRegistry()), address(0));

        // Try to trigger upgrade().
        vm.expectRevert("Initializable: contract is already initialized");
        AIHIPortal2.upgrade(IAnchorStateRegistry(address(0xdeadbeef)), IETHLockbox(ethLockbox));
    }
}

/// @title AIHIPortal2_ResourceFuzz_Test
/// @dev Test various values of the resource metering config to ensure that deposits cannot be
///      broken by changing the config.
contract AIHIPortal2_ResourceFuzz_Test is CommonTest {
    /// @dev The max gas limit observed throughout this test. Setting this too high can cause
    ///      the test to take too long to run.
    uint256 constant MAX_GAS_LIMIT = 30_000_000;

    function setUp() public override {
        super.setUp();
    }

    /// @dev Test that various values of the resource metering config will not break deposits.
    function testFuzz_systemConfigDeposit_succeeds(
        uint32 _maxResourceLimit,
        uint8 _elasticityMultiplier,
        uint8 _baseFeeMaxChangeDenominator,
        uint32 _minimumBaseFee,
        uint32 _systemTxMaxGas,
        uint128 _maximumBaseFee,
        uint64 _gasLimit,
        uint64 _prevBoughtGas,
        uint128 _prevBaseFee,
        uint8 _blockDiff
    )
        external
    {
        // Get the set system gas limit
        uint64 gasLimit = systemConfig.gasLimit();

        // Bound resource config
        _systemTxMaxGas = uint32(bound(_systemTxMaxGas, 0, gasLimit - 21000));
        _maxResourceLimit = uint32(bound(_maxResourceLimit, 21000, MAX_GAS_LIMIT / 8));
        _maxResourceLimit = uint32(bound(_maxResourceLimit, 21000, gasLimit - _systemTxMaxGas));
        _maximumBaseFee = uint128(bound(_maximumBaseFee, 1, type(uint128).max));
        _minimumBaseFee = uint32(bound(_minimumBaseFee, 0, _maximumBaseFee - 1));
        _gasLimit = uint64(bound(_gasLimit, 21000, _maxResourceLimit));
        _gasLimit = uint64(bound(_gasLimit, 0, gasLimit));
        _prevBaseFee = uint128(bound(_prevBaseFee, 0, 3 gwei));
        _prevBoughtGas = uint64(bound(_prevBoughtGas, 0, _maxResourceLimit - _gasLimit));
        _blockDiff = uint8(bound(_blockDiff, 0, 3));
        _baseFeeMaxChangeDenominator = uint8(bound(_baseFeeMaxChangeDenominator, 2, type(uint8).max));
        _elasticityMultiplier = uint8(bound(_elasticityMultiplier, 1, type(uint8).max));

        // Prevent values that would cause reverts
        vm.assume(uint256(_maxResourceLimit) + uint256(_systemTxMaxGas) <= gasLimit);
        vm.assume(((_maxResourceLimit / _elasticityMultiplier) * _elasticityMultiplier) == _maxResourceLimit);

        // Although we typically want to limit the usage of vm.assume, we've constructed the above
        // bounds to satisfy the assumptions listed in this specific section. These assumptions
        // serve only to act as an additional sanity check on top of the bounds and should not
        // result in an unnecessary number of test rejections.
        vm.assume(gasLimit >= _gasLimit);
        vm.assume(_minimumBaseFee < _maximumBaseFee);

        // Base fee can increase quickly and mean that we can't buy the amount of gas we want.
        // Here we add a VM assumption to bound the potential increase.
        // Compute the maximum possible increase in base fee.
        uint256 maxPercentIncrease = uint256(_elasticityMultiplier - 1) * 100 / uint256(_baseFeeMaxChangeDenominator);
        // Assume that we have enough gas to burn.
        // Compute the maximum amount of gas we'd need to burn.
        // Assume we need 1/5 of our gas to do other stuff.
        vm.assume(_prevBaseFee * maxPercentIncrease * _gasLimit / 100 < MAX_GAS_LIMIT * 4 / 5);

        // Pick a pseudorandom block number
        vm.roll(uint256(keccak256(abi.encode(_blockDiff))) % uint256(type(uint16).max) + uint256(_blockDiff));

        // Create a resource config to mock the call to the system config with
        IResourceMetering.ResourceConfig memory rcfg = IResourceMetering.ResourceConfig({
            maxResourceLimit: _maxResourceLimit,
            elasticityMultiplier: _elasticityMultiplier,
            baseFeeMaxChangeDenominator: _baseFeeMaxChangeDenominator,
            minimumBaseFee: _minimumBaseFee,
            systemTxMaxGas: _systemTxMaxGas,
            maximumBaseFee: _maximumBaseFee
        });
        vm.mockCall(address(systemConfig), abi.encodeCall(systemConfig.resourceConfig, ()), abi.encode(rcfg));

        // Set the resource params
        uint256 _prevBlockNum = block.number - _blockDiff;
        vm.store(
            address(AIHIPortal2),
            bytes32(uint256(1)),
            bytes32((_prevBlockNum << 192) | (uint256(_prevBoughtGas) << 128) | _prevBaseFee)
        );
        // Ensure that the storage setting is correct
        (uint128 prevBaseFee, uint64 prevBoughtGas, uint64 prevBlockNum) = AIHIPortal2.params();
        assertEq(prevBaseFee, _prevBaseFee);
        assertEq(prevBoughtGas, _prevBoughtGas);
        assertEq(prevBlockNum, _prevBlockNum);

        // Do a deposit, should not revert
        AIHIPortal2.depositTransaction{ gas: MAX_GAS_LIMIT }({
            _to: address(0x20),
            _value: 0x40,
            _gasLimit: _gasLimit,
            _isCreation: false,
            _data: hex""
        });
    }
}
