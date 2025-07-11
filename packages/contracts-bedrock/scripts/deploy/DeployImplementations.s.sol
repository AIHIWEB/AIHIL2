// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";

import { LibString } from "@solady/utils/LibString.sol";

// Libraries
import { Chains } from "scripts/libraries/Chains.sol";

// Interfaces
import { IResourceMetering } from "interfaces/L1/IResourceMetering.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IProtocolVersions } from "interfaces/L1/IProtocolVersions.sol";
import { IDelayedWETH } from "interfaces/dispute/IDelayedWETH.sol";
import { IPreimageOracle } from "interfaces/cannon/IPreimageOracle.sol";
import { IMIPS } from "interfaces/cannon/IMIPS.sol";
import { IDisputeGameFactory } from "interfaces/dispute/IDisputeGameFactory.sol";
import { IAnchorStateRegistry } from "interfaces/dispute/IAnchorStateRegistry.sol";
import {
    IOPContractsManager,
    IOPContractsManagerGameTypeAdder,
    IOPContractsManagerDeployer,
    IOPContractsManagerUpgrader,
    IOPContractsManagerContractsContainer,
    IOPContractsManagerInteropMigrator
} from "interfaces/L1/IOPContractsManager.sol";
import { IAIHIPortal2 as IAIHIPortal } from "interfaces/L1/IAIHIPortal2.sol";
import { IETHLockbox } from "interfaces/L1/IETHLockbox.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";
import { IL1CrossDomainMessenger } from "interfaces/L1/IL1CrossDomainMessenger.sol";
import { IL1ERC721Bridge } from "interfaces/L1/IL1ERC721Bridge.sol";
import { IL1StandardBridge } from "interfaces/L1/IL1StandardBridge.sol";
import { IAIHIMintableERC20Factory } from "interfaces/universal/IAIHIMintableERC20Factory.sol";
import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { Solarray } from "scripts/libraries/Solarray.sol";
import { BaseDeployIO } from "scripts/deploy/BaseDeployIO.sol";

// See DeploySuperchain.s.sol for detailed comments on the script architecture used here.
contract DeployImplementationsInput is BaseDeployIO {
    uint256 internal _withdrawalDelaySeconds;
    uint256 internal _minProposalSizeBytes;
    uint256 internal _challengePeriodSeconds;
    uint256 internal _proofMaturityDelaySeconds;
    uint256 internal _disputeGameFinalityDelaySeconds;
    uint256 internal _mipsVersion;

    // This is used in opcm to signal which version of the L1 smart contracts is deployed.
    // It takes the format of `op-contracts/v*.*.*`.
    string internal _l1ContractsRelease;

    // Outputs from DeploySuperchain.s.sol.
    ISuperchainConfig internal _superchainConfigProxy;
    IProtocolVersions internal _protocolVersionsProxy;
    IProxyAdmin internal _superchainProxyAdmin;
    address internal _upgradeController;

    function set(bytes4 _sel, uint256 _value) public {
        require(_value != 0, "DeployImplementationsInput: cannot set zero value");

        if (_sel == this.withdrawalDelaySeconds.selector) {
            _withdrawalDelaySeconds = _value;
        } else if (_sel == this.minProposalSizeBytes.selector) {
            _minProposalSizeBytes = _value;
        } else if (_sel == this.challengePeriodSeconds.selector) {
            require(_value <= type(uint64).max, "DeployImplementationsInput: challengePeriodSeconds too large");
            _challengePeriodSeconds = _value;
        } else if (_sel == this.proofMaturityDelaySeconds.selector) {
            _proofMaturityDelaySeconds = _value;
        } else if (_sel == this.disputeGameFinalityDelaySeconds.selector) {
            _disputeGameFinalityDelaySeconds = _value;
        } else if (_sel == this.mipsVersion.selector) {
            _mipsVersion = _value;
        } else {
            revert("DeployImplementationsInput: unknown selector");
        }
    }

    function set(bytes4 _sel, string memory _value) public {
        require(!LibString.eq(_value, ""), "DeployImplementationsInput: cannot set empty string");
        if (_sel == this.l1ContractsRelease.selector) _l1ContractsRelease = _value;
        else revert("DeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "DeployImplementationsInput: cannot set zero address");
        if (_sel == this.superchainConfigProxy.selector) _superchainConfigProxy = ISuperchainConfig(_addr);
        else if (_sel == this.protocolVersionsProxy.selector) _protocolVersionsProxy = IProtocolVersions(_addr);
        else if (_sel == this.superchainProxyAdmin.selector) _superchainProxyAdmin = IProxyAdmin(_addr);
        else if (_sel == this.upgradeController.selector) _upgradeController = _addr;
        else revert("DeployImplementationsInput: unknown selector");
    }

    function withdrawalDelaySeconds() public view returns (uint256) {
        require(_withdrawalDelaySeconds != 0, "DeployImplementationsInput: not set");
        return _withdrawalDelaySeconds;
    }

    function minProposalSizeBytes() public view returns (uint256) {
        require(_minProposalSizeBytes != 0, "DeployImplementationsInput: not set");
        return _minProposalSizeBytes;
    }

    function challengePeriodSeconds() public view returns (uint256) {
        require(_challengePeriodSeconds != 0, "DeployImplementationsInput: not set");
        require(
            _challengePeriodSeconds <= type(uint64).max, "DeployImplementationsInput: challengePeriodSeconds too large"
        );
        return _challengePeriodSeconds;
    }

    function proofMaturityDelaySeconds() public view returns (uint256) {
        require(_proofMaturityDelaySeconds != 0, "DeployImplementationsInput: not set");
        return _proofMaturityDelaySeconds;
    }

    function disputeGameFinalityDelaySeconds() public view returns (uint256) {
        require(_disputeGameFinalityDelaySeconds != 0, "DeployImplementationsInput: not set");
        return _disputeGameFinalityDelaySeconds;
    }

    function mipsVersion() public view returns (uint256) {
        require(_mipsVersion != 0, "DeployImplementationsInput: not set");
        return _mipsVersion;
    }

    function l1ContractsRelease() public view returns (string memory) {
        require(!LibString.eq(_l1ContractsRelease, ""), "DeployImplementationsInput: not set");
        return _l1ContractsRelease;
    }

    function superchainConfigProxy() public view returns (ISuperchainConfig) {
        require(address(_superchainConfigProxy) != address(0), "DeployImplementationsInput: not set");
        return _superchainConfigProxy;
    }

    function protocolVersionsProxy() public view returns (IProtocolVersions) {
        require(address(_protocolVersionsProxy) != address(0), "DeployImplementationsInput: not set");
        return _protocolVersionsProxy;
    }

    function superchainProxyAdmin() public view returns (IProxyAdmin) {
        require(address(_superchainProxyAdmin) != address(0), "DeployImplementationsInput: not set");
        return _superchainProxyAdmin;
    }

    function upgradeController() public view returns (address) {
        require(address(_upgradeController) != address(0), "DeployImplementationsInput: not set");
        return _upgradeController;
    }
}

contract DeployImplementationsOutput is BaseDeployIO {
    IOPContractsManager internal _opcm;
    IOPContractsManagerContractsContainer internal _opcmContractsContainer;
    IOPContractsManagerGameTypeAdder internal _opcmGameTypeAdder;
    IOPContractsManagerDeployer internal _opcmDeployer;
    IOPContractsManagerUpgrader internal _opcmUpgrader;
    IOPContractsManagerInteropMigrator internal _opcmInteropMigrator;
    IDelayedWETH internal _delayedWETHImpl;
    IAIHIPortal internal _AIHIPortalImpl;
    IETHLockbox internal _ethLockboxImpl;
    IPreimageOracle internal _preimageOracleSingleton;
    IMIPS internal _mipsSingleton;
    ISystemConfig internal _systemConfigImpl;
    IL1CrossDomainMessenger internal _l1CrossDomainMessengerImpl;
    IL1ERC721Bridge internal _l1ERC721BridgeImpl;
    IL1StandardBridge internal _l1StandardBridgeImpl;
    IAIHIMintableERC20Factory internal _AIHIMintableERC20FactoryImpl;
    IDisputeGameFactory internal _disputeGameFactoryImpl;
    IAnchorStateRegistry internal _anchorStateRegistryImpl;
    ISuperchainConfig internal _superchainConfigImpl;
    IProtocolVersions internal _protocolVersionsImpl;

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "DeployImplementationsOutput: cannot set zero address");

        // forgefmt: disable-start
        if (_sel == this.opcm.selector) _opcm = IOPContractsManager(_addr);
        else if (_sel == this.opcmContractsContainer.selector) _opcmContractsContainer = IOPContractsManagerContractsContainer(_addr);
        else if (_sel == this.opcmGameTypeAdder.selector) _opcmGameTypeAdder = IOPContractsManagerGameTypeAdder(_addr);
        else if (_sel == this.opcmDeployer.selector) _opcmDeployer = IOPContractsManagerDeployer(_addr);
        else if (_sel == this.opcmUpgrader.selector) _opcmUpgrader = IOPContractsManagerUpgrader(_addr);
        else if (_sel == this.opcmInteropMigrator.selector) _opcmInteropMigrator = IOPContractsManagerInteropMigrator(_addr);
        else if (_sel == this.superchainConfigImpl.selector) _superchainConfigImpl = ISuperchainConfig(_addr);
        else if (_sel == this.protocolVersionsImpl.selector) _protocolVersionsImpl = IProtocolVersions(_addr);
        else if (_sel == this.AIHIPortalImpl.selector) _AIHIPortalImpl = IAIHIPortal(payable(_addr));
        else if (_sel == this.ethLockboxImpl.selector) _ethLockboxImpl = IETHLockbox(payable(_addr));
        else if (_sel == this.delayedWETHImpl.selector) _delayedWETHImpl = IDelayedWETH(payable(_addr));
        else if (_sel == this.preimageOracleSingleton.selector) _preimageOracleSingleton = IPreimageOracle(_addr);
        else if (_sel == this.mipsSingleton.selector) _mipsSingleton = IMIPS(_addr);
        else if (_sel == this.systemConfigImpl.selector) _systemConfigImpl = ISystemConfig(_addr);
        else if (_sel == this.l1CrossDomainMessengerImpl.selector) _l1CrossDomainMessengerImpl = IL1CrossDomainMessenger(_addr);
        else if (_sel == this.l1ERC721BridgeImpl.selector) _l1ERC721BridgeImpl = IL1ERC721Bridge(_addr);
        else if (_sel == this.l1StandardBridgeImpl.selector) _l1StandardBridgeImpl = IL1StandardBridge(payable(_addr));
        else if (_sel == this.AIHIMintableERC20FactoryImpl.selector) _AIHIMintableERC20FactoryImpl = IAIHIMintableERC20Factory(_addr);
        else if (_sel == this.disputeGameFactoryImpl.selector) _disputeGameFactoryImpl = IDisputeGameFactory(_addr);
        else if (_sel == this.anchorStateRegistryImpl.selector) _anchorStateRegistryImpl = IAnchorStateRegistry(_addr);
        else revert("DeployImplementationsOutput: unknown selector");
        // forgefmt: disable-end
    }

    function checkOutput(DeployImplementationsInput _dii) public view {
        // With 12 addresses, we'd get a stack too deep error if we tried to do this inline as a
        // single call to `Solarray.addresses`. So we split it into two calls.
        address[] memory addrs1 = Solarray.addresses(
            address(this.opcm()),
            address(this.AIHIPortalImpl()),
            address(this.delayedWETHImpl()),
            address(this.preimageOracleSingleton()),
            address(this.mipsSingleton()),
            address(this.superchainConfigImpl()),
            address(this.protocolVersionsImpl())
        );

        address[] memory addrs2 = Solarray.addresses(
            address(this.systemConfigImpl()),
            address(this.l1CrossDomainMessengerImpl()),
            address(this.l1ERC721BridgeImpl()),
            address(this.l1StandardBridgeImpl()),
            address(this.AIHIMintableERC20FactoryImpl()),
            address(this.disputeGameFactoryImpl()),
            address(this.anchorStateRegistryImpl()),
            address(this.ethLockboxImpl())
        );

        DeployUtils.assertValidContractAddresses(Solarray.extend(addrs1, addrs2));

        assertValidDeploy(_dii);
    }

    function opcm() public view returns (IOPContractsManager) {
        DeployUtils.assertValidContractAddress(address(_opcm));
        return _opcm;
    }

    function opcmContractsContainer() public view returns (IOPContractsManagerContractsContainer) {
        DeployUtils.assertValidContractAddress(address(_opcmContractsContainer));
        return _opcmContractsContainer;
    }

    function opcmGameTypeAdder() public view returns (IOPContractsManagerGameTypeAdder) {
        DeployUtils.assertValidContractAddress(address(_opcmGameTypeAdder));
        return _opcmGameTypeAdder;
    }

    function opcmDeployer() public view returns (IOPContractsManagerDeployer) {
        DeployUtils.assertValidContractAddress(address(_opcmDeployer));
        return _opcmDeployer;
    }

    function opcmUpgrader() public view returns (IOPContractsManagerUpgrader) {
        DeployUtils.assertValidContractAddress(address(_opcmUpgrader));
        return _opcmUpgrader;
    }

    function opcmInteropMigrator() public view returns (IOPContractsManagerInteropMigrator) {
        DeployUtils.assertValidContractAddress(address(_opcmInteropMigrator));
        return _opcmInteropMigrator;
    }

    function superchainConfigImpl() public view returns (ISuperchainConfig) {
        DeployUtils.assertValidContractAddress(address(_superchainConfigImpl));
        return _superchainConfigImpl;
    }

    function protocolVersionsImpl() public view returns (IProtocolVersions) {
        DeployUtils.assertValidContractAddress(address(_protocolVersionsImpl));
        return _protocolVersionsImpl;
    }

    function AIHIPortalImpl() public view returns (IAIHIPortal) {
        DeployUtils.assertValidContractAddress(address(_AIHIPortalImpl));
        return _AIHIPortalImpl;
    }

    function ethLockboxImpl() public view returns (IETHLockbox) {
        DeployUtils.assertValidContractAddress(address(_ethLockboxImpl));
        return _ethLockboxImpl;
    }

    function delayedWETHImpl() public view returns (IDelayedWETH) {
        DeployUtils.assertValidContractAddress(address(_delayedWETHImpl));
        return _delayedWETHImpl;
    }

    function preimageOracleSingleton() public view returns (IPreimageOracle) {
        DeployUtils.assertValidContractAddress(address(_preimageOracleSingleton));
        return _preimageOracleSingleton;
    }

    function mipsSingleton() public view returns (IMIPS) {
        DeployUtils.assertValidContractAddress(address(_mipsSingleton));
        return _mipsSingleton;
    }

    function systemConfigImpl() public view returns (ISystemConfig) {
        DeployUtils.assertValidContractAddress(address(_systemConfigImpl));
        return _systemConfigImpl;
    }

    function l1CrossDomainMessengerImpl() public view returns (IL1CrossDomainMessenger) {
        DeployUtils.assertValidContractAddress(address(_l1CrossDomainMessengerImpl));
        return _l1CrossDomainMessengerImpl;
    }

    function l1ERC721BridgeImpl() public view returns (IL1ERC721Bridge) {
        DeployUtils.assertValidContractAddress(address(_l1ERC721BridgeImpl));
        return _l1ERC721BridgeImpl;
    }

    function l1StandardBridgeImpl() public view returns (IL1StandardBridge) {
        DeployUtils.assertValidContractAddress(address(_l1StandardBridgeImpl));
        return _l1StandardBridgeImpl;
    }

    function AIHIMintableERC20FactoryImpl() public view returns (IAIHIMintableERC20Factory) {
        DeployUtils.assertValidContractAddress(address(_AIHIMintableERC20FactoryImpl));
        return _AIHIMintableERC20FactoryImpl;
    }

    function disputeGameFactoryImpl() public view returns (IDisputeGameFactory) {
        DeployUtils.assertValidContractAddress(address(_disputeGameFactoryImpl));
        return _disputeGameFactoryImpl;
    }

    function anchorStateRegistryImpl() public view returns (IAnchorStateRegistry) {
        DeployUtils.assertValidContractAddress(address(_anchorStateRegistryImpl));
        return _anchorStateRegistryImpl;
    }

    // -------- Deployment Assertions --------
    function assertValidDeploy(DeployImplementationsInput _dii) public view {
        assertValidDelayedWETHImpl(_dii);
        assertValidDisputeGameFactoryImpl(_dii);
        assertValidAnchorStateRegistryImpl(_dii);
        assertValidL1CrossDomainMessengerImpl(_dii);
        assertValidL1ERC721BridgeImpl(_dii);
        assertValidL1StandardBridgeImpl(_dii);
        assertValidMipsSingleton(_dii);
        assertValidOpcm(_dii);
        assertValidAIHIMintableERC20FactoryImpl(_dii);
        assertValidAIHIPortalImpl(_dii);
        assertValidETHLockboxImpl(_dii);
        assertValidPreimageOracleSingleton(_dii);
        assertValidSystemConfigImpl(_dii);
    }

    function assertValidOpcm(DeployImplementationsInput _dii) internal view {
        IOPContractsManager impl = IOPContractsManager(address(opcm()));
        require(address(impl.superchainConfig()) == address(_dii.superchainConfigProxy()), "OPCMI-10");
        require(address(impl.protocolVersions()) == address(_dii.protocolVersionsProxy()), "OPCMI-20");
        require(impl.upgradeController() == _dii.upgradeController(), "OPCMI-30");
    }

    function assertValidAIHIPortalImpl(DeployImplementationsInput) internal view {
        IAIHIPortal portal = AIHIPortalImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(portal), _isProxy: false, _slot: 0, _offset: 0 });

        require(address(portal.anchorStateRegistry()) == address(0), "PORTAL-10");
        require(address(portal.systemConfig()) == address(0), "PORTAL-20");
        require(address(portal.superchainConfig()) == address(0), "PORTAL-30");
        require(portal.l2Sender() == address(0), "PORTAL-40");

        // This slot is the custom gas token _balance and this check ensures
        // that it stays unset for forwards compatibility with custom gas token.
        require(vm.load(address(portal), bytes32(uint256(61))) == bytes32(0), "PORTAL-50");

        require(address(portal.ethLockbox()) == address(0), "PORTAL-60");
    }

    function assertValidETHLockboxImpl(DeployImplementationsInput) internal view {
        IETHLockbox lockbox = ethLockboxImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(lockbox), _isProxy: false, _slot: 0, _offset: 0 });

        require(address(lockbox.superchainConfig()) == address(0), "ELB-10");
        require(lockbox.authorizedPortals(AIHIPortalImpl()) == false, "ELB-20");
    }

    function assertValidDelayedWETHImpl(DeployImplementationsInput _dii) internal view {
        IDelayedWETH delayedWETH = delayedWETHImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(delayedWETH), _isProxy: false, _slot: 0, _offset: 0 });

        require(delayedWETH.owner() == address(0), "DW-10");
        require(delayedWETH.delay() == _dii.withdrawalDelaySeconds(), "DW-20");
        require(delayedWETH.config() == ISuperchainConfig(address(0)), "DW-30");
    }

    function assertValidPreimageOracleSingleton(DeployImplementationsInput _dii) internal view {
        IPreimageOracle oracle = preimageOracleSingleton();

        require(oracle.minProposalSize() == _dii.minProposalSizeBytes(), "PO-10");
        require(oracle.challengePeriod() == _dii.challengePeriodSeconds(), "PO-20");
    }

    function assertValidMipsSingleton(DeployImplementationsInput) internal view {
        IMIPS mips = mipsSingleton();
        require(address(mips.oracle()) == address(preimageOracleSingleton()), "MIPS-10");
    }

    function assertValidSystemConfigImpl(DeployImplementationsInput) internal view {
        ISystemConfig systemConfig = systemConfigImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(systemConfig), _isProxy: false, _slot: 0, _offset: 0 });

        require(systemConfig.owner() == address(0), "SYSCON-10");
        require(systemConfig.overhead() == 0, "SYSCON-20");
        require(systemConfig.scalar() == 0, "SYSCON-30");
        require(systemConfig.basefeeScalar() == 0, "SYSCON-40");
        require(systemConfig.blobbasefeeScalar() == 0, "SYSCON-50");
        require(systemConfig.batcherHash() == bytes32(0), "SYSCON-60");
        require(systemConfig.gasLimit() == 0, "SYSCON-70");
        require(systemConfig.unsafeBlockSigner() == address(0), "SYSCON-80");

        IResourceMetering.ResourceConfig memory resourceConfig = systemConfig.resourceConfig();
        require(resourceConfig.maxResourceLimit == 0, "SYSCON-90");
        require(resourceConfig.elasticityMultiplier == 0, "SYSCON-100");
        require(resourceConfig.baseFeeMaxChangeDenominator == 0, "SYSCON-110");
        require(resourceConfig.systemTxMaxGas == 0, "SYSCON-120");
        require(resourceConfig.minimumBaseFee == 0, "SYSCON-130");
        require(resourceConfig.maximumBaseFee == 0, "SYSCON-140");

        require(systemConfig.startBlock() == type(uint256).max, "SYSCON-150");
        require(systemConfig.batchInbox() == address(0), "SYSCON-160");
        require(systemConfig.l1CrossDomainMessenger() == address(0), "SYSCON-170");
        require(systemConfig.l1ERC721Bridge() == address(0), "SYSCON-180");
        require(systemConfig.l1StandardBridge() == address(0), "SYSCON-190");
        require(systemConfig.AIHIPortal() == address(0), "SYSCON-200");
        require(systemConfig.AIHIMintableERC20Factory() == address(0), "SYSCON-210");
    }

    function assertValidL1CrossDomainMessengerImpl(DeployImplementationsInput) internal view {
        IL1CrossDomainMessenger messenger = l1CrossDomainMessengerImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(messenger), _isProxy: false, _slot: 0, _offset: 20 });

        require(address(messenger.OTHER_MESSENGER()) == address(0), "L1xDM-10");
        require(address(messenger.otherMessenger()) == address(0), "L1xDM-20");
        require(address(messenger.PORTAL()) == address(0), "L1xDM-30");
        require(address(messenger.portal()) == address(0), "L1xDM-40");
        require(address(messenger.superchainConfig()) == address(0), "L1xDM-50");

        bytes32 xdmSenderSlot = vm.load(address(messenger), bytes32(uint256(204)));
        require(address(uint160(uint256(xdmSenderSlot))) == address(0), "L1xDM-60");
    }

    function assertValidL1ERC721BridgeImpl(DeployImplementationsInput) internal view {
        IL1ERC721Bridge bridge = l1ERC721BridgeImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(bridge), _isProxy: false, _slot: 0, _offset: 0 });

        require(address(bridge.OTHER_BRIDGE()) == address(0), "L721B-10");
        require(address(bridge.otherBridge()) == address(0), "L721B-20");
        require(address(bridge.MESSENGER()) == address(0), "L721B-30");
        require(address(bridge.messenger()) == address(0), "L721B-40");
        require(address(bridge.superchainConfig()) == address(0), "L721B-50");
    }

    function assertValidL1StandardBridgeImpl(DeployImplementationsInput) internal view {
        IL1StandardBridge bridge = l1StandardBridgeImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(bridge), _isProxy: false, _slot: 0, _offset: 0 });

        require(address(bridge.MESSENGER()) == address(0), "L1SB-10");
        require(address(bridge.messenger()) == address(0), "L1SB-20");
        require(address(bridge.OTHER_BRIDGE()) == address(0), "L1SB-30");
        require(address(bridge.otherBridge()) == address(0), "L1SB-40");
        require(address(bridge.superchainConfig()) == address(0), "L1SB-50");
    }

    function assertValidAIHIMintableERC20FactoryImpl(DeployImplementationsInput) internal view {
        IAIHIMintableERC20Factory factory = AIHIMintableERC20FactoryImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(factory), _isProxy: false, _slot: 0, _offset: 0 });

        require(address(factory.BRIDGE()) == address(0), "MERC20F-10");
        require(address(factory.bridge()) == address(0), "MERC20F-20");
    }

    function assertValidDisputeGameFactoryImpl(DeployImplementationsInput) internal view {
        IDisputeGameFactory factory = disputeGameFactoryImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(factory), _isProxy: false, _slot: 0, _offset: 0 });

        require(address(factory.owner()) == address(0), "DG-10");
    }

    function assertValidAnchorStateRegistryImpl(DeployImplementationsInput) internal view {
        IAnchorStateRegistry registry = anchorStateRegistryImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(registry), _isProxy: false, _slot: 0, _offset: 0 });
    }
}

contract DeployImplementations is Script {
    bytes32 internal _salt = DeployUtils.DEFAULT_SALT;

    // -------- Core Deployment Methods --------

    function run(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public {
        // Deploy the implementations.
        deploySuperchainConfigImpl(_dio);
        deployProtocolVersionsImpl(_dio);
        deploySystemConfigImpl(_dio);
        deployL1CrossDomainMessengerImpl(_dio);
        deployL1ERC721BridgeImpl(_dio);
        deployL1StandardBridgeImpl(_dio);
        deployAIHIMintableERC20FactoryImpl(_dio);
        deployAIHIPortalImpl(_dii, _dio);
        deployETHLockboxImpl(_dio);
        deployDelayedWETHImpl(_dii, _dio);
        deployPreimageOracleSingleton(_dii, _dio);
        deployMipsSingleton(_dii, _dio);
        deployDisputeGameFactoryImpl(_dio);
        deployAnchorStateRegistryImpl(_dii, _dio);

        // Deploy the OP Contracts Manager with the new implementations set.
        deployOPContractsManager(_dii, _dio);

        _dio.checkOutput(_dii);
    }

    // -------- Deployment Steps --------

    // --- OP Contracts Manager ---

    function createOPCMContract(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio,
        IOPContractsManager.Blueprints memory _blueprints,
        string memory _l1ContractsRelease
    )
        internal
        virtual
        returns (IOPContractsManager opcm_)
    {
        IOPContractsManager.Implementations memory implementations = IOPContractsManager.Implementations({
            superchainConfigImpl: address(_dio.superchainConfigImpl()),
            protocolVersionsImpl: address(_dio.protocolVersionsImpl()),
            l1ERC721BridgeImpl: address(_dio.l1ERC721BridgeImpl()),
            AIHIPortalImpl: address(_dio.AIHIPortalImpl()),
            ethLockboxImpl: address(_dio.ethLockboxImpl()),
            systemConfigImpl: address(_dio.systemConfigImpl()),
            AIHIMintableERC20FactoryImpl: address(_dio.AIHIMintableERC20FactoryImpl()),
            l1CrossDomainMessengerImpl: address(_dio.l1CrossDomainMessengerImpl()),
            l1StandardBridgeImpl: address(_dio.l1StandardBridgeImpl()),
            disputeGameFactoryImpl: address(_dio.disputeGameFactoryImpl()),
            anchorStateRegistryImpl: address(_dio.anchorStateRegistryImpl()),
            delayedWETHImpl: address(_dio.delayedWETHImpl()),
            mipsImpl: address(_dio.mipsSingleton())
        });

        deployOPCMBPImplsContainer(_dio, _blueprints, implementations);
        deployOPCMGameTypeAdder(_dio);
        deployOPCMDeployer(_dio);
        deployOPCMUpgrader(_dio);
        deployOPCMInteropMigrator(_dio);

        // Semgrep rule will fail because the arguments are encoded inside of a separate function.
        opcm_ = IOPContractsManager(
            // nosemgrep: sol-safety-deployutils-args
            DeployUtils.createDeterministic({
                _name: "OPContractsManager",
                _args: encodeOPCMConstructor(_l1ContractsRelease, _dii, _dio),
                _salt: _salt
            })
        );

        vm.label(address(opcm_), "OPContractsManager");
        _dio.set(_dio.opcm.selector, address(opcm_));
    }

    /// @notice Encodes the constructor of the OPContractsManager contract. Used to avoid stack too
    ///         deep errors inside of the createOPCMContract function.
    /// @param _l1ContractsRelease The release of the L1 contracts.
    /// @param _dii The deployment input parameters.
    /// @param _dio The deployment output parameters.
    /// @return encoded_ The encoded constructor.
    function encodeOPCMConstructor(
        string memory _l1ContractsRelease,
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        internal
        view
        returns (bytes memory encoded_)
    {
        encoded_ = DeployUtils.encodeConstructor(
            abi.encodeCall(
                IOPContractsManager.__constructor__,
                (
                    _dio.opcmGameTypeAdder(),
                    _dio.opcmDeployer(),
                    _dio.opcmUpgrader(),
                    _dio.opcmInteropMigrator(),
                    _dii.superchainConfigProxy(),
                    _dii.protocolVersionsProxy(),
                    _dii.superchainProxyAdmin(),
                    _l1ContractsRelease,
                    _dii.upgradeController()
                )
            )
        );
    }

    function deployOPContractsManager(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory l1ContractsRelease = _dii.l1ContractsRelease();

        // First we deploy the blueprints for the singletons deployed by OPCM.
        // forgefmt: disable-start
        IOPContractsManager.Blueprints memory blueprints;
        vm.startBroadcast(msg.sender);
        address checkAddress;
        (blueprints.addressManager, checkAddress) = DeployUtils.createDeterministicBlueprint(vm.getCode("AddressManager"), _salt);
        require(checkAddress == address(0), "OPCM-10");
        (blueprints.proxy, checkAddress) = DeployUtils.createDeterministicBlueprint(vm.getCode("Proxy"), _salt);
        require(checkAddress == address(0), "OPCM-20");
        (blueprints.proxyAdmin, checkAddress) = DeployUtils.createDeterministicBlueprint(vm.getCode("ProxyAdmin"), _salt);
        require(checkAddress == address(0), "OPCM-30");
        (blueprints.l1ChugSplashProxy, checkAddress) = DeployUtils.createDeterministicBlueprint(vm.getCode("L1ChugSplashProxy"), _salt);
        require(checkAddress == address(0), "OPCM-40");
        (blueprints.resolvedDelegateProxy, checkAddress) = DeployUtils.createDeterministicBlueprint(vm.getCode("ResolvedDelegateProxy"), _salt);
        require(checkAddress == address(0), "OPCM-50");
        // The max initcode/runtimecode size is 48KB/24KB.
        // But for Blueprint, the initcode is stored as runtime code, that's why it's necessary to split into 2 parts.
        (blueprints.permissionedDisputeGame1, blueprints.permissionedDisputeGame2) = DeployUtils.createDeterministicBlueprint(vm.getCode("PermissionedDisputeGame"), _salt);
        (blueprints.permissionlessDisputeGame1, blueprints.permissionlessDisputeGame2) = DeployUtils.createDeterministicBlueprint(vm.getCode("FaultDisputeGame"), _salt);
        (blueprints.superPermissionedDisputeGame1, blueprints.superPermissionedDisputeGame2) = DeployUtils.createDeterministicBlueprint(vm.getCode("SuperPermissionedDisputeGame"), _salt);
        (blueprints.superPermissionlessDisputeGame1, blueprints.superPermissionlessDisputeGame2) = DeployUtils.createDeterministicBlueprint(vm.getCode("SuperFaultDisputeGame"), _salt);
        // forgefmt: disable-end
        vm.stopBroadcast();

        IOPContractsManager opcm = createOPCMContract(_dii, _dio, blueprints, l1ContractsRelease);

        vm.label(address(opcm), "OPContractsManager");
        _dio.set(_dio.opcm.selector, address(opcm));
    }

    // --- Core Contracts ---

    function deploySuperchainConfigImpl(DeployImplementationsOutput _dio) public virtual {
        ISuperchainConfig impl = ISuperchainConfig(
            DeployUtils.createDeterministic({
                _name: "SuperchainConfig",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(ISuperchainConfig.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "SuperchainConfigImpl");
        _dio.set(_dio.superchainConfigImpl.selector, address(impl));
    }

    function deployProtocolVersionsImpl(DeployImplementationsOutput _dio) public virtual {
        IProtocolVersions impl = IProtocolVersions(
            DeployUtils.createDeterministic({
                _name: "ProtocolVersions",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IProtocolVersions.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "ProtocolVersionsImpl");
        _dio.set(_dio.protocolVersionsImpl.selector, address(impl));
    }

    function deploySystemConfigImpl(DeployImplementationsOutput _dio) public virtual {
        ISystemConfig impl = ISystemConfig(
            DeployUtils.createDeterministic({
                _name: "SystemConfig",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(ISystemConfig.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "SystemConfigImpl");
        _dio.set(_dio.systemConfigImpl.selector, address(impl));
    }

    function deployL1CrossDomainMessengerImpl(DeployImplementationsOutput _dio) public virtual {
        IL1CrossDomainMessenger impl = IL1CrossDomainMessenger(
            DeployUtils.createDeterministic({
                _name: "L1CrossDomainMessenger",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IL1CrossDomainMessenger.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "L1CrossDomainMessengerImpl");
        _dio.set(_dio.l1CrossDomainMessengerImpl.selector, address(impl));
    }

    function deployL1ERC721BridgeImpl(DeployImplementationsOutput _dio) public virtual {
        IL1ERC721Bridge impl = IL1ERC721Bridge(
            DeployUtils.createDeterministic({
                _name: "L1ERC721Bridge",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IL1ERC721Bridge.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "L1ERC721BridgeImpl");
        _dio.set(_dio.l1ERC721BridgeImpl.selector, address(impl));
    }

    function deployL1StandardBridgeImpl(DeployImplementationsOutput _dio) public virtual {
        IL1StandardBridge impl = IL1StandardBridge(
            DeployUtils.createDeterministic({
                _name: "L1StandardBridge",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IL1StandardBridge.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "L1StandardBridgeImpl");
        _dio.set(_dio.l1StandardBridgeImpl.selector, address(impl));
    }

    function deployAIHIMintableERC20FactoryImpl(DeployImplementationsOutput _dio) public virtual {
        IAIHIMintableERC20Factory impl = IAIHIMintableERC20Factory(
            DeployUtils.createDeterministic({
                _name: "AIHIMintableERC20Factory",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IAIHIMintableERC20Factory.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "AIHIMintableERC20FactoryImpl");
        _dio.set(_dio.AIHIMintableERC20FactoryImpl.selector, address(impl));
    }

    function deployETHLockboxImpl(DeployImplementationsOutput _dio) public virtual {
        IETHLockbox impl = IETHLockbox(
            DeployUtils.createDeterministic({
                _name: "ETHLockbox",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IETHLockbox.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "ETHLockboxImpl");
        _dio.set(_dio.ethLockboxImpl.selector, address(impl));
    }

    // --- Fault Proofs Contracts ---

    // The fault proofs contracts are configured as follows:
    // | Contract                | Proxied | Deployment                        | MCP Ready  |
    // |-------------------------|---------|-----------------------------------|------------|
    // | DisputeGameFactory      | Yes     | Bespoke                           | Yes        |
    // | AnchorStateRegistry     | Yes     | Bespoke                           | Yes         |
    // | FaultDisputeGame        | No      | Bespoke                           | No         | Not yet supported by OPCM
    // | PermissionedDisputeGame | No      | Bespoke                           | No         |
    // | DelayedWETH             | Yes     | Two bespoke (one per DisputeGame) | Yes *️⃣     |
    // | PreimageOracle          | No      | Shared                            | N/A        |
    // | MIPS                    | No      | Shared                            | N/A        |
    // | AIHIPortal2         | Yes     | Shared                            | Yes *️⃣     |
    //
    // - *️⃣ These contracts have immutable values which are intended to be constant for all contracts within a
    //   Superchain, and are therefore MCP ready for any chain using the Standard Configuration.
    //
    // This script only deploys the shared contracts. The bespoke contracts are deployed by
    // `DeployOPChain.s.sol`. When the shared contracts are proxied, the contracts deployed here are
    // "implementations", and when shared contracts are not proxied, they are "singletons". So
    // here we deploy:
    //
    //   - DisputeGameFactory (implementation)
    //   - AnchorStateRegistry (implementation)
    //   - AIHIPortal2 (implementation)
    //   - DelayedWETH (implementation)
    //   - PreimageOracle (singleton)
    //   - MIPS (singleton)
    //
    // For contracts which are not MCP ready neither the Proxy nor the implementation can be shared, therefore they
    // are deployed by `DeployOpChain.s.sol`.
    // These are:
    // - FaultDisputeGame (not proxied)
    // - PermissionedDisputeGame (not proxied)
    // - DelayedWeth (proxies only)
    // - AIHIPortal2 (proxies only)

    function deployAIHIPortalImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        uint256 proofMaturityDelaySeconds = _dii.proofMaturityDelaySeconds();
        IAIHIPortal impl = IAIHIPortal(
            DeployUtils.createDeterministic({
                _name: "AIHIPortal2",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IAIHIPortal.__constructor__, (proofMaturityDelaySeconds))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "AIHIPortalImpl");
        _dio.set(_dio.AIHIPortalImpl.selector, address(impl));
    }

    function deployDelayedWETHImpl(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        uint256 withdrawalDelaySeconds = _dii.withdrawalDelaySeconds();
        IDelayedWETH impl = IDelayedWETH(
            DeployUtils.createDeterministic({
                _name: "DelayedWETH",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IDelayedWETH.__constructor__, (withdrawalDelaySeconds))),
                _salt: _salt
            })
        );
        vm.label(address(impl), "DelayedWETHImpl");
        _dio.set(_dio.delayedWETHImpl.selector, address(impl));
    }

    function deployPreimageOracleSingleton(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        uint256 minProposalSizeBytes = _dii.minProposalSizeBytes();
        uint256 challengePeriodSeconds = _dii.challengePeriodSeconds();
        IPreimageOracle singleton = IPreimageOracle(
            DeployUtils.createDeterministic({
                _name: "PreimageOracle",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IPreimageOracle.__constructor__, (minProposalSizeBytes, challengePeriodSeconds))
                ),
                _salt: _salt
            })
        );
        vm.label(address(singleton), "PreimageOracleSingleton");
        _dio.set(_dio.preimageOracleSingleton.selector, address(singleton));
    }

    function deployMipsSingleton(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        uint256 mipsVersion = _dii.mipsVersion();
        IPreimageOracle preimageOracle = IPreimageOracle(address(_dio.preimageOracleSingleton()));

        // We want to ensure that the OPCM for upgrade 13 is deployed with Mips32 on production networks.
        if (mipsVersion != 2) {
            if (block.chainid == Chains.Mainnet || block.chainid == Chains.Sepolia) {
                revert("DeployImplementations: Only Mips64 should be deployed on Mainnet or Sepolia");
            }
        }

        IMIPS singleton = IMIPS(
            DeployUtils.createDeterministic({
                _name: mipsVersion == 1 ? "MIPS" : "MIPS64",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IMIPS.__constructor__, (preimageOracle))),
                _salt: _salt
            })
        );
        vm.label(address(singleton), "MIPSSingleton");
        _dio.set(_dio.mipsSingleton.selector, address(singleton));
    }

    function deployDisputeGameFactoryImpl(DeployImplementationsOutput _dio) public virtual {
        IDisputeGameFactory impl = IDisputeGameFactory(
            DeployUtils.createDeterministic({
                _name: "DisputeGameFactory",
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IDisputeGameFactory.__constructor__, ())),
                _salt: _salt
            })
        );
        vm.label(address(impl), "DisputeGameFactoryImpl");
        _dio.set(_dio.disputeGameFactoryImpl.selector, address(impl));
    }

    function deployAnchorStateRegistryImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        uint256 disputeGameFinalityDelaySeconds = _dii.disputeGameFinalityDelaySeconds();
        IAnchorStateRegistry impl = IAnchorStateRegistry(
            DeployUtils.createDeterministic({
                _name: "AnchorStateRegistry",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IAnchorStateRegistry.__constructor__, (disputeGameFinalityDelaySeconds))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "AnchorStateRegistryImpl");
        _dio.set(_dio.anchorStateRegistryImpl.selector, address(impl));
    }

    function deployOPCMBPImplsContainer(
        DeployImplementationsOutput _dio,
        IOPContractsManager.Blueprints memory _blueprints,
        IOPContractsManager.Implementations memory _implementations
    )
        public
        virtual
    {
        IOPContractsManagerContractsContainer impl = IOPContractsManagerContractsContainer(
            DeployUtils.createDeterministic({
                _name: "OPContractsManager.sol:OPContractsManagerContractsContainer",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IOPContractsManagerContractsContainer.__constructor__, (_blueprints, _implementations))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "OPContractsManagerBPImplsContainerImpl");
        _dio.set(_dio.opcmContractsContainer.selector, address(impl));
    }

    function deployOPCMGameTypeAdder(DeployImplementationsOutput _dio) public virtual {
        IOPContractsManagerGameTypeAdder impl = IOPContractsManagerGameTypeAdder(
            DeployUtils.createDeterministic({
                _name: "OPContractsManager.sol:OPContractsManagerGameTypeAdder",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IOPContractsManagerGameTypeAdder.__constructor__, (_dio.opcmContractsContainer()))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "OPContractsManagerGameTypeAdderImpl");
        _dio.set(_dio.opcmGameTypeAdder.selector, address(impl));
    }

    function deployOPCMDeployer(DeployImplementationsOutput _dio) public virtual {
        IOPContractsManagerDeployer impl = IOPContractsManagerDeployer(
            DeployUtils.createDeterministic({
                _name: "OPContractsManager.sol:OPContractsManagerDeployer",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IOPContractsManagerDeployer.__constructor__, (_dio.opcmContractsContainer()))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "OPContractsManagerDeployerImpl");
        _dio.set(_dio.opcmDeployer.selector, address(impl));
    }

    function deployOPCMUpgrader(DeployImplementationsOutput _dio) public virtual {
        IOPContractsManagerUpgrader impl = IOPContractsManagerUpgrader(
            DeployUtils.createDeterministic({
                _name: "OPContractsManager.sol:OPContractsManagerUpgrader",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IOPContractsManagerUpgrader.__constructor__, (_dio.opcmContractsContainer()))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "OPContractsManagerUpgraderImpl");
        _dio.set(_dio.opcmUpgrader.selector, address(impl));
    }

    function deployOPCMInteropMigrator(DeployImplementationsOutput _dio) public virtual {
        IOPContractsManagerInteropMigrator impl = IOPContractsManagerInteropMigrator(
            DeployUtils.createDeterministic({
                _name: "OPContractsManager.sol:OPContractsManagerInteropMigrator",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(IOPContractsManagerInteropMigrator.__constructor__, (_dio.opcmContractsContainer()))
                ),
                _salt: _salt
            })
        );
        vm.label(address(impl), "OPContractsManagerInteropMigratorImpl");
        _dio.set(_dio.opcmInteropMigrator.selector, address(impl));
    }

    // -------- Utilities --------

    function etchIOContracts() public returns (DeployImplementationsInput dii_, DeployImplementationsOutput dio_) {
        (dii_, dio_) = getIOContracts();

        DeployUtils.etchLabelAndAllowCheatcodes({
            _etchTo: address(dii_),
            _cname: "DeployImplementationsInput",
            _artifactPath: "DeployImplementations.s.sol:DeployImplementationsInput"
        });

        DeployUtils.etchLabelAndAllowCheatcodes({
            _etchTo: address(dio_),
            _cname: "DeployImplementationsOutput",
            _artifactPath: "DeployImplementations.s.sol:DeployImplementationsOutput"
        });
    }

    function getIOContracts() public view returns (DeployImplementationsInput dii_, DeployImplementationsOutput dio_) {
        dii_ = DeployImplementationsInput(DeployUtils.toIOAddress(msg.sender, "AIHI.DeployImplementationsInput"));
        dio_ = DeployImplementationsOutput(DeployUtils.toIOAddress(msg.sender, "AIHI.DeployImplementationsOutput"));
    }
}
