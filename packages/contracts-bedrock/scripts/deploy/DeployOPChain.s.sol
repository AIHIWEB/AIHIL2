// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { Solarray } from "scripts/libraries/Solarray.sol";
import { BaseDeployIO } from "scripts/deploy/BaseDeployIO.sol";

import { IResourceMetering } from "interfaces/L1/IResourceMetering.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IBigStepper } from "interfaces/dispute/IBigStepper.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Constants } from "src/libraries/Constants.sol";
import { Constants as ScriptConstants } from "scripts/libraries/Constants.sol";

import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { IOPContractsManager } from "interfaces/L1/IOPContractsManager.sol";
import { IAddressManager } from "interfaces/legacy/IAddressManager.sol";
import { IDelayedWETH } from "interfaces/dispute/IDelayedWETH.sol";
import { IDisputeGameFactory } from "interfaces/dispute/IDisputeGameFactory.sol";
import { IAnchorStateRegistry } from "interfaces/dispute/IAnchorStateRegistry.sol";
import { IFaultDisputeGame } from "interfaces/dispute/IFaultDisputeGame.sol";
import { IPermissionedDisputeGame } from "interfaces/dispute/IPermissionedDisputeGame.sol";
import { Claim, Duration, GameType, GameTypes, Hash } from "src/dispute/lib/Types.sol";

import { IAIHIPortal2 as IAIHIPortal } from "interfaces/L1/IAIHIPortal2.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";
import { IL1CrossDomainMessenger } from "interfaces/L1/IL1CrossDomainMessenger.sol";
import { IL1ERC721Bridge } from "interfaces/L1/IL1ERC721Bridge.sol";
import { IL1StandardBridge } from "interfaces/L1/IL1StandardBridge.sol";
import { IAIHIMintableERC20Factory } from "interfaces/universal/IAIHIMintableERC20Factory.sol";
import { IETHLockbox } from "interfaces/L1/IETHLockbox.sol";

contract DeployOPChainInput is BaseDeployIO {
    address internal _opChainProxyAdminOwner;
    address internal _systemConfigOwner;
    address internal _batcher;
    address internal _unsafeBlockSigner;
    address internal _proposer;
    address internal _challenger;

    // TODO Add fault proofs inputs in a future PR.
    uint32 internal _basefeeScalar;
    uint32 internal _blobBaseFeeScalar;
    uint256 internal _l2ChainId;
    IOPContractsManager internal _opcm;
    string internal _saltMixer;
    uint64 internal _gasLimit;

    // Configurable dispute game inputs
    GameType internal _disputeGameType;
    Claim internal _disputeAbsolutePrestate;
    uint256 internal _disputeMaxGameDepth;
    uint256 internal _disputeSplitDepth;
    Duration internal _disputeClockExtension;
    Duration internal _disputeMaxClockDuration;
    bool internal _allowCustomDisputeParameters;

    uint32 internal _operatorFeeScalar;
    uint64 internal _operatorFeeConstant;

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "DeployOPChainInput: cannot set zero address");
        if (_sel == this.opChainProxyAdminOwner.selector) _opChainProxyAdminOwner = _addr;
        else if (_sel == this.systemConfigOwner.selector) _systemConfigOwner = _addr;
        else if (_sel == this.batcher.selector) _batcher = _addr;
        else if (_sel == this.unsafeBlockSigner.selector) _unsafeBlockSigner = _addr;
        else if (_sel == this.proposer.selector) _proposer = _addr;
        else if (_sel == this.challenger.selector) _challenger = _addr;
        else if (_sel == this.opcm.selector) _opcm = IOPContractsManager(_addr);
        else revert("DeployOPChainInput: unknown selector");
    }

    function set(bytes4 _sel, uint256 _value) public {
        if (_sel == this.basefeeScalar.selector) {
            _basefeeScalar = SafeCast.toUint32(_value);
        } else if (_sel == this.blobBaseFeeScalar.selector) {
            _blobBaseFeeScalar = SafeCast.toUint32(_value);
        } else if (_sel == this.l2ChainId.selector) {
            require(_value != 0 && _value != block.chainid, "DeployOPChainInput: invalid l2ChainId");
            _l2ChainId = _value;
        } else if (_sel == this.gasLimit.selector) {
            _gasLimit = SafeCast.toUint64(_value);
        } else if (_sel == this.disputeGameType.selector) {
            _disputeGameType = GameType.wrap(SafeCast.toUint32(_value));
        } else if (_sel == this.disputeMaxGameDepth.selector) {
            _disputeMaxGameDepth = SafeCast.toUint64(_value);
        } else if (_sel == this.disputeSplitDepth.selector) {
            _disputeSplitDepth = SafeCast.toUint64(_value);
        } else if (_sel == this.disputeClockExtension.selector) {
            _disputeClockExtension = Duration.wrap(SafeCast.toUint64(_value));
        } else if (_sel == this.disputeMaxClockDuration.selector) {
            _disputeMaxClockDuration = Duration.wrap(SafeCast.toUint64(_value));
        } else if (_sel == this.operatorFeeScalar.selector) {
            _operatorFeeScalar = SafeCast.toUint32(_value);
        } else if (_sel == this.operatorFeeConstant.selector) {
            _operatorFeeConstant = SafeCast.toUint64(_value);
        } else {
            revert("DeployOPChainInput: unknown selector");
        }
    }

    function set(bytes4 _sel, string memory _value) public {
        require((bytes(_value).length != 0), "DeployImplementationsInput: cannot set empty string");
        if (_sel == this.saltMixer.selector) _saltMixer = _value;
        else revert("DeployOPChainInput: unknown selector");
    }

    function set(bytes4 _sel, bytes32 _value) public {
        if (_sel == this.disputeAbsolutePrestate.selector) _disputeAbsolutePrestate = Claim.wrap(_value);
        else revert("DeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, bool _value) public {
        if (_sel == this.allowCustomDisputeParameters.selector) _allowCustomDisputeParameters = _value;
        else revert("DeployOPChainInput: unknown selector");
    }

    function opChainProxyAdminOwner() public view returns (address) {
        require(_opChainProxyAdminOwner != address(0), "DeployOPChainInput: not set");
        return _opChainProxyAdminOwner;
    }

    function systemConfigOwner() public view returns (address) {
        require(_systemConfigOwner != address(0), "DeployOPChainInput: not set");
        return _systemConfigOwner;
    }

    function batcher() public view returns (address) {
        require(_batcher != address(0), "DeployOPChainInput: not set");
        return _batcher;
    }

    function unsafeBlockSigner() public view returns (address) {
        require(_unsafeBlockSigner != address(0), "DeployOPChainInput: not set");
        return _unsafeBlockSigner;
    }

    function proposer() public view returns (address) {
        require(_proposer != address(0), "DeployOPChainInput: not set");
        return _proposer;
    }

    function challenger() public view returns (address) {
        require(_challenger != address(0), "DeployOPChainInput: not set");
        return _challenger;
    }

    function basefeeScalar() public view returns (uint32) {
        require(_basefeeScalar != 0, "DeployOPChainInput: not set");
        return _basefeeScalar;
    }

    function blobBaseFeeScalar() public view returns (uint32) {
        require(_blobBaseFeeScalar != 0, "DeployOPChainInput: not set");
        return _blobBaseFeeScalar;
    }

    function l2ChainId() public view returns (uint256) {
        require(_l2ChainId != 0, "DeployOPChainInput: not set");
        require(_l2ChainId != block.chainid, "DeployOPChainInput: invalid l2ChainId");
        return _l2ChainId;
    }

    function startingAnchorRoot() public pure returns (bytes memory) {
        // WARNING: For now always hardcode the starting permissioned game anchor root to 0xdead,
        // and we do not set anything for the permissioned game. This is because we currently only
        // support deploying straight to permissioned games, and the starting root does not
        // matter for that, as long as it is non-zero, since no games will be played. We do not
        // deploy the permissionless game (and therefore do not set a starting root for it here)
        // because to to update to the permissionless game, we will need to update its starting
        // anchor root and deploy a new permissioned dispute game contract anyway.
        //
        // You can `console.logBytes(abi.encode(ScriptConstants.DEFAULT_OUTPUT_ROOT()))` to get the bytes that
        // are hardcoded into `op-chain-ops/deployer/opcm/opchain.go`

        return abi.encode(ScriptConstants.DEFAULT_OUTPUT_ROOT());
    }

    function opcm() public view returns (IOPContractsManager) {
        require(address(_opcm) != address(0), "DeployOPChainInput: not set");
        DeployUtils.assertValidContractAddress(address(_opcm));
        return _opcm;
    }

    function saltMixer() public view returns (string memory) {
        return _saltMixer;
    }

    function gasLimit() public view returns (uint64) {
        return _gasLimit;
    }

    function disputeGameType() public view returns (GameType) {
        return _disputeGameType;
    }

    function disputeAbsolutePrestate() public view returns (Claim) {
        return _disputeAbsolutePrestate;
    }

    function disputeMaxGameDepth() public view returns (uint256) {
        return _disputeMaxGameDepth;
    }

    function disputeSplitDepth() public view returns (uint256) {
        return _disputeSplitDepth;
    }

    function disputeClockExtension() public view returns (Duration) {
        return _disputeClockExtension;
    }

    function disputeMaxClockDuration() public view returns (Duration) {
        return _disputeMaxClockDuration;
    }

    function allowCustomDisputeParameters() public view returns (bool) {
        return _allowCustomDisputeParameters;
    }

    function operatorFeeScalar() public view returns (uint32) {
        return _operatorFeeScalar;
    }

    function operatorFeeConstant() public view returns (uint64) {
        return _operatorFeeConstant;
    }
}

contract DeployOPChainOutput is BaseDeployIO {
    IProxyAdmin internal _opChainProxyAdmin;
    IAddressManager internal _addressManager;
    IL1ERC721Bridge internal _l1ERC721BridgeProxy;
    ISystemConfig internal _systemConfigProxy;
    IAIHIMintableERC20Factory internal _AIHIMintableERC20FactoryProxy;
    IL1StandardBridge internal _l1StandardBridgeProxy;
    IL1CrossDomainMessenger internal _l1CrossDomainMessengerProxy;
    IAIHIPortal internal _AIHIPortalProxy;
    IETHLockbox internal _ethLockboxProxy;
    IDisputeGameFactory internal _disputeGameFactoryProxy;
    IAnchorStateRegistry internal _anchorStateRegistryProxy;
    IFaultDisputeGame internal _faultDisputeGame;
    IPermissionedDisputeGame internal _permissionedDisputeGame;
    IDelayedWETH internal _delayedWETHPermissionedGameProxy;
    IDelayedWETH internal _delayedWETHPermissionlessGameProxy;

    function set(bytes4 _sel, address _addr) public virtual {
        require(_addr != address(0), "DeployOPChainOutput: cannot set zero address");
        // forgefmt: disable-start
        if (_sel == this.opChainProxyAdmin.selector) _opChainProxyAdmin = IProxyAdmin(_addr) ;
        else if (_sel == this.addressManager.selector) _addressManager = IAddressManager(_addr) ;
        else if (_sel == this.l1ERC721BridgeProxy.selector) _l1ERC721BridgeProxy = IL1ERC721Bridge(_addr) ;
        else if (_sel == this.systemConfigProxy.selector) _systemConfigProxy = ISystemConfig(_addr) ;
        else if (_sel == this.AIHIMintableERC20FactoryProxy.selector) _AIHIMintableERC20FactoryProxy = IAIHIMintableERC20Factory(_addr) ;
        else if (_sel == this.l1StandardBridgeProxy.selector) _l1StandardBridgeProxy = IL1StandardBridge(payable(_addr)) ;
        else if (_sel == this.l1CrossDomainMessengerProxy.selector) _l1CrossDomainMessengerProxy = IL1CrossDomainMessenger(_addr) ;
        else if (_sel == this.AIHIPortalProxy.selector) _AIHIPortalProxy = IAIHIPortal(payable(_addr)) ;
        else if (_sel == this.ethLockboxProxy.selector) _ethLockboxProxy = IETHLockbox(payable(_addr)) ;
        else if (_sel == this.disputeGameFactoryProxy.selector) _disputeGameFactoryProxy = IDisputeGameFactory(_addr) ;
        else if (_sel == this.anchorStateRegistryProxy.selector) _anchorStateRegistryProxy = IAnchorStateRegistry(_addr) ;
        else if (_sel == this.faultDisputeGame.selector) _faultDisputeGame = IFaultDisputeGame(_addr) ;
        else if (_sel == this.permissionedDisputeGame.selector) _permissionedDisputeGame = IPermissionedDisputeGame(_addr) ;
        else if (_sel == this.delayedWETHPermissionedGameProxy.selector) _delayedWETHPermissionedGameProxy = IDelayedWETH(payable(_addr)) ;
        else if (_sel == this.delayedWETHPermissionlessGameProxy.selector) _delayedWETHPermissionlessGameProxy = IDelayedWETH(payable(_addr)) ;
        else revert("DeployOPChainOutput: unknown selector");
        // forgefmt: disable-end
    }

    function opChainProxyAdmin() public view returns (IProxyAdmin) {
        DeployUtils.assertValidContractAddress(address(_opChainProxyAdmin));
        return _opChainProxyAdmin;
    }

    function addressManager() public view returns (IAddressManager) {
        DeployUtils.assertValidContractAddress(address(_addressManager));
        return _addressManager;
    }

    function l1ERC721BridgeProxy() public returns (IL1ERC721Bridge) {
        DeployUtils.assertValidContractAddress(address(_l1ERC721BridgeProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_l1ERC721BridgeProxy));
        return _l1ERC721BridgeProxy;
    }

    function systemConfigProxy() public returns (ISystemConfig) {
        DeployUtils.assertValidContractAddress(address(_systemConfigProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_systemConfigProxy));
        return _systemConfigProxy;
    }

    function AIHIMintableERC20FactoryProxy() public returns (IAIHIMintableERC20Factory) {
        DeployUtils.assertValidContractAddress(address(_AIHIMintableERC20FactoryProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_AIHIMintableERC20FactoryProxy));
        return _AIHIMintableERC20FactoryProxy;
    }

    function l1StandardBridgeProxy() public returns (IL1StandardBridge) {
        DeployUtils.assertValidContractAddress(address(_l1StandardBridgeProxy));
        DeployUtils.assertL1ChugSplashImplementationSet(address(_l1StandardBridgeProxy));
        return _l1StandardBridgeProxy;
    }

    function l1CrossDomainMessengerProxy() public view returns (IL1CrossDomainMessenger) {
        DeployUtils.assertValidContractAddress(address(_l1CrossDomainMessengerProxy));
        DeployUtils.assertResolvedDelegateProxyImplementationSet("OVM_L1CrossDomainMessenger", addressManager());
        return _l1CrossDomainMessengerProxy;
    }

    function AIHIPortalProxy() public returns (IAIHIPortal) {
        DeployUtils.assertValidContractAddress(address(_AIHIPortalProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_AIHIPortalProxy));
        return _AIHIPortalProxy;
    }

    function ethLockboxProxy() public returns (IETHLockbox) {
        DeployUtils.assertValidContractAddress(address(_ethLockboxProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_ethLockboxProxy));
        return _ethLockboxProxy;
    }

    function disputeGameFactoryProxy() public returns (IDisputeGameFactory) {
        DeployUtils.assertValidContractAddress(address(_disputeGameFactoryProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_disputeGameFactoryProxy));
        return _disputeGameFactoryProxy;
    }

    function anchorStateRegistryProxy() public returns (IAnchorStateRegistry) {
        DeployUtils.assertValidContractAddress(address(_anchorStateRegistryProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_anchorStateRegistryProxy));
        return _anchorStateRegistryProxy;
    }

    function faultDisputeGame() public view returns (IFaultDisputeGame) {
        DeployUtils.assertValidContractAddress(address(_faultDisputeGame));
        return _faultDisputeGame;
    }

    function permissionedDisputeGame() public view returns (IPermissionedDisputeGame) {
        DeployUtils.assertValidContractAddress(address(_permissionedDisputeGame));
        return _permissionedDisputeGame;
    }

    function delayedWETHPermissionedGameProxy() public returns (IDelayedWETH) {
        DeployUtils.assertValidContractAddress(address(_delayedWETHPermissionedGameProxy));
        DeployUtils.assertERC1967ImplementationSet(address(_delayedWETHPermissionedGameProxy));
        return _delayedWETHPermissionedGameProxy;
    }

    function delayedWETHPermissionlessGameProxy() public view returns (IDelayedWETH) {
        // TODO: Eventually switch from Permissioned to Permissionless. Add this check back in.
        // DeployUtils.assertValidContractAddress(address(_delayedWETHPermissionlessGameProxy));
        return _delayedWETHPermissionlessGameProxy;
    }
}

contract DeployOPChain is Script {
    // -------- Core Deployment Methods --------

    function run(DeployOPChainInput _doi, DeployOPChainOutput _doo) public {
        IOPContractsManager opcm = _doi.opcm();

        IOPContractsManager.Roles memory roles = IOPContractsManager.Roles({
            opChainProxyAdminOwner: _doi.opChainProxyAdminOwner(),
            systemConfigOwner: _doi.systemConfigOwner(),
            batcher: _doi.batcher(),
            unsafeBlockSigner: _doi.unsafeBlockSigner(),
            proposer: _doi.proposer(),
            challenger: _doi.challenger()
        });
        IOPContractsManager.DeployInput memory deployInput = IOPContractsManager.DeployInput({
            roles: roles,
            basefeeScalar: _doi.basefeeScalar(),
            blobBasefeeScalar: _doi.blobBaseFeeScalar(),
            l2ChainId: _doi.l2ChainId(),
            startingAnchorRoot: _doi.startingAnchorRoot(),
            saltMixer: _doi.saltMixer(),
            gasLimit: _doi.gasLimit(),
            disputeGameType: _doi.disputeGameType(),
            disputeAbsolutePrestate: _doi.disputeAbsolutePrestate(),
            disputeMaxGameDepth: _doi.disputeMaxGameDepth(),
            disputeSplitDepth: _doi.disputeSplitDepth(),
            disputeClockExtension: _doi.disputeClockExtension(),
            disputeMaxClockDuration: _doi.disputeMaxClockDuration()
        });

        vm.broadcast(msg.sender);
        IOPContractsManager.DeployOutput memory deployOutput = opcm.deploy(deployInput);

        vm.label(address(deployOutput.opChainProxyAdmin), "opChainProxyAdmin");
        vm.label(address(deployOutput.addressManager), "addressManager");
        vm.label(address(deployOutput.l1ERC721BridgeProxy), "l1ERC721BridgeProxy");
        vm.label(address(deployOutput.systemConfigProxy), "systemConfigProxy");
        vm.label(address(deployOutput.AIHIMintableERC20FactoryProxy), "AIHIMintableERC20FactoryProxy");
        vm.label(address(deployOutput.l1StandardBridgeProxy), "l1StandardBridgeProxy");
        vm.label(address(deployOutput.l1CrossDomainMessengerProxy), "l1CrossDomainMessengerProxy");
        vm.label(address(deployOutput.AIHIPortalProxy), "AIHIPortalProxy");
        vm.label(address(deployOutput.ethLockboxProxy), "ethLockboxProxy");
        vm.label(address(deployOutput.disputeGameFactoryProxy), "disputeGameFactoryProxy");
        vm.label(address(deployOutput.anchorStateRegistryProxy), "anchorStateRegistryProxy");
        // vm.label(address(deployOutput.faultDisputeGame), "faultDisputeGame");
        vm.label(address(deployOutput.permissionedDisputeGame), "permissionedDisputeGame");
        vm.label(address(deployOutput.delayedWETHPermissionedGameProxy), "delayedWETHPermissionedGameProxy");
        // TODO: Eventually switch from Permissioned to Permissionless.
        // vm.label(address(deployOutput.delayedWETHPermissionlessGameProxy), "delayedWETHPermissionlessGameProxy");

        _doo.set(_doo.opChainProxyAdmin.selector, address(deployOutput.opChainProxyAdmin));
        _doo.set(_doo.addressManager.selector, address(deployOutput.addressManager));
        _doo.set(_doo.l1ERC721BridgeProxy.selector, address(deployOutput.l1ERC721BridgeProxy));
        _doo.set(_doo.systemConfigProxy.selector, address(deployOutput.systemConfigProxy));
        _doo.set(
            _doo.AIHIMintableERC20FactoryProxy.selector, address(deployOutput.AIHIMintableERC20FactoryProxy)
        );
        _doo.set(_doo.l1StandardBridgeProxy.selector, address(deployOutput.l1StandardBridgeProxy));
        _doo.set(_doo.l1CrossDomainMessengerProxy.selector, address(deployOutput.l1CrossDomainMessengerProxy));
        _doo.set(_doo.AIHIPortalProxy.selector, address(deployOutput.AIHIPortalProxy));
        _doo.set(_doo.ethLockboxProxy.selector, address(deployOutput.ethLockboxProxy));
        _doo.set(_doo.disputeGameFactoryProxy.selector, address(deployOutput.disputeGameFactoryProxy));
        _doo.set(_doo.anchorStateRegistryProxy.selector, address(deployOutput.anchorStateRegistryProxy));
        // _doo.set(_doo.faultDisputeGame.selector, address(deployOutput.faultDisputeGame));
        _doo.set(_doo.permissionedDisputeGame.selector, address(deployOutput.permissionedDisputeGame));
        _doo.set(_doo.delayedWETHPermissionedGameProxy.selector, address(deployOutput.delayedWETHPermissionedGameProxy));
        // TODO: Eventually switch from Permissioned to Permissionless.
        // _doo.set(
        //     _doo.delayedWETHPermissionlessGameProxy.selector,
        // address(deployOutput.delayedWETHPermissionlessGameProxy)
        // );

        checkOutput(_doi, _doo);
    }

    function checkOutput(DeployOPChainInput _doi, DeployOPChainOutput _doo) public {
        // With 16 addresses, we'd get a stack too deep error if we tried to do this inline as a
        // single call to `Solarray.addresses`. So we split it into two calls.
        address[] memory addrs1 = Solarray.addresses(
            address(_doo.opChainProxyAdmin()),
            address(_doo.addressManager()),
            address(_doo.l1ERC721BridgeProxy()),
            address(_doo.systemConfigProxy()),
            address(_doo.AIHIMintableERC20FactoryProxy()),
            address(_doo.l1StandardBridgeProxy()),
            address(_doo.l1CrossDomainMessengerProxy())
        );
        address[] memory addrs2 = Solarray.addresses(
            address(_doo.AIHIPortalProxy()),
            address(_doo.disputeGameFactoryProxy()),
            address(_doo.anchorStateRegistryProxy()),
            address(_doo.permissionedDisputeGame()),
            // address(_doo.faultDisputeGame()),
            address(_doo.delayedWETHPermissionedGameProxy()),
            address(_doo.ethLockboxProxy())
        );
        // TODO: Eventually switch from Permissioned to Permissionless. Add this address back in.
        // address(_delayedWETHPermissionlessGameProxy)

        DeployUtils.assertValidContractAddresses(Solarray.extend(addrs1, addrs2));
        assertValidDeploy(_doi, _doo);
    }

    // -------- Deployment Assertions --------
    function assertValidDeploy(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        assertValidAnchorStateRegistryProxy(_doi, _doo);
        assertValidDelayedWETH(_doi, _doo);
        assertValidDisputeGameFactory(_doi, _doo);
        assertValidL1CrossDomainMessenger(_doi, _doo);
        assertValidL1ERC721Bridge(_doi, _doo);
        assertValidL1StandardBridge(_doi, _doo);
        assertValidAIHIMintableERC20Factory(_doi, _doo);
        assertValidAIHIPortal(_doi, _doo);
        assertValidETHLockbox(_doi, _doo);
        assertValidPermissionedDisputeGame(_doi, _doo);
        assertValidSystemConfig(_doi, _doo);
        assertValidAddressManager(_doi, _doo);
        assertValidOPChainProxyAdmin(_doi, _doo);
    }

    function assertValidPermissionedDisputeGame(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IPermissionedDisputeGame game = _doo.permissionedDisputeGame();

        require(GameType.unwrap(game.gameType()) == GameType.unwrap(GameTypes.PERMISSIONED_CANNON), "DPG-10");

        if (_doi.allowCustomDisputeParameters()) {
            return;
        }

        // This hex string is the absolutePrestate of the latest op-program release, see where the
        // `EXPECTED_PRESTATE_HASH` is defined in `config.yml`.
        require(
            Claim.unwrap(game.absolutePrestate())
                == bytes32(hex"038512e02c4c3f7bdaec27d00edf55b7155e0905301e1a88083e4e0a6764d54c"),
            "DPG-20"
        );

        IOPContractsManager opcm = _doi.opcm();
        address mipsImpl = opcm.implementations().mipsImpl;
        require(game.vm() == IBigStepper(mipsImpl), "DPG-30");

        require(address(game.weth()) == address(_doo.delayedWETHPermissionedGameProxy()), "DPG-40");
        require(address(game.anchorStateRegistry()) == address(_doo.anchorStateRegistryProxy()), "DPG-50");
        require(game.l2ChainId() == _doi.l2ChainId(), "DPG-60");
        require(game.l2BlockNumber() == 0, "DPG-70");
        require(Duration.unwrap(game.clockExtension()) == 10800, "DPG-80");
        require(Duration.unwrap(game.maxClockDuration()) == 302400, "DPG-110");
        require(game.splitDepth() == 30, "DPG-90");
        require(game.maxGameDepth() == 73, "DPG-100");
    }

    function assertValidAnchorStateRegistryProxy(DeployOPChainInput, DeployOPChainOutput _doo) internal {
        // First we check the proxy as itself.
        IProxy proxy = IProxy(payable(address(_doo.anchorStateRegistryProxy())));
        vm.prank(address(0));
        address admin = proxy.admin();
        require(admin == address(_doo.opChainProxyAdmin()), "ANCHORP-10");

        // Then we check the proxy as ASR.
        DeployUtils.assertInitialized({
            _contractAddress: address(_doo.anchorStateRegistryProxy()),
            _isProxy: true,
            _slot: 0,
            _offset: 0
        });

        require(
            address(_doo.anchorStateRegistryProxy().disputeGameFactory()) == address(_doo.disputeGameFactoryProxy()),
            "ANCHORP-30"
        );

        (Hash actualRoot,) = _doo.anchorStateRegistryProxy().anchors(GameTypes.PERMISSIONED_CANNON);
        bytes32 expectedRoot = 0xdead000000000000000000000000000000000000000000000000000000000000;
        require(Hash.unwrap(actualRoot) == expectedRoot, "ANCHORP-40");
    }

    function assertValidSystemConfig(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        ISystemConfig systemConfig = _doo.systemConfigProxy();

        DeployUtils.assertInitialized({ _contractAddress: address(systemConfig), _isProxy: true, _slot: 0, _offset: 0 });

        require(systemConfig.owner() == _doi.systemConfigOwner(), "SYSCON-10");
        require(systemConfig.basefeeScalar() == _doi.basefeeScalar(), "SYSCON-20");
        require(systemConfig.blobbasefeeScalar() == _doi.blobBaseFeeScalar(), "SYSCON-30");
        require(systemConfig.batcherHash() == bytes32(uint256(uint160(_doi.batcher()))), "SYSCON-40");
        require(systemConfig.gasLimit() == uint64(60_000_000), "SYSCON-50");
        require(systemConfig.unsafeBlockSigner() == _doi.unsafeBlockSigner(), "SYSCON-60");
        require(systemConfig.scalar() >> 248 == 1, "SYSCON-70");

        IResourceMetering.ResourceConfig memory rConfig = Constants.DEFAULT_RESOURCE_CONFIG();
        IResourceMetering.ResourceConfig memory outputConfig = systemConfig.resourceConfig();
        require(outputConfig.maxResourceLimit == rConfig.maxResourceLimit, "SYSCON-80");
        require(outputConfig.elasticityMultiplier == rConfig.elasticityMultiplier, "SYSCON-90");
        require(outputConfig.baseFeeMaxChangeDenominator == rConfig.baseFeeMaxChangeDenominator, "SYSCON-100");
        require(outputConfig.systemTxMaxGas == rConfig.systemTxMaxGas, "SYSCON-110");
        require(outputConfig.minimumBaseFee == rConfig.minimumBaseFee, "SYSCON-120");
        require(outputConfig.maximumBaseFee == rConfig.maximumBaseFee, "SYSCON-130");

        require(systemConfig.startBlock() == block.number, "SYSCON-140");
        require(systemConfig.batchInbox() == _doi.opcm().chainIdToBatchInboxAddress(_doi.l2ChainId()), "SYSCON-150");

        require(systemConfig.l1CrossDomainMessenger() == address(_doo.l1CrossDomainMessengerProxy()), "SYSCON-160");
        require(systemConfig.l1ERC721Bridge() == address(_doo.l1ERC721BridgeProxy()), "SYSCON-170");
        require(systemConfig.l1StandardBridge() == address(_doo.l1StandardBridgeProxy()), "SYSCON-180");
        require(systemConfig.AIHIPortal() == address(_doo.AIHIPortalProxy()), "SYSCON-190");
        require(
            systemConfig.AIHIMintableERC20Factory() == address(_doo.AIHIMintableERC20FactoryProxy()),
            "SYSCON-200"
        );
    }

    function assertValidL1CrossDomainMessenger(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IL1CrossDomainMessenger messenger = _doo.l1CrossDomainMessengerProxy();

        DeployUtils.assertInitialized({ _contractAddress: address(messenger), _isProxy: true, _slot: 0, _offset: 20 });

        require(address(messenger.OTHER_MESSENGER()) == Predeploys.L2_CROSS_DOMAIN_MESSENGER, "L1xDM-10");
        require(address(messenger.otherMessenger()) == Predeploys.L2_CROSS_DOMAIN_MESSENGER, "L1xDM-20");

        require(address(messenger.PORTAL()) == address(_doo.AIHIPortalProxy()), "L1xDM-30");
        require(address(messenger.portal()) == address(_doo.AIHIPortalProxy()), "L1xDM-40");
        require(address(messenger.superchainConfig()) == address(_doi.opcm().superchainConfig()), "L1xDM-50");

        bytes32 xdmSenderSlot = vm.load(address(messenger), bytes32(uint256(204)));
        require(address(uint160(uint256(xdmSenderSlot))) == Constants.DEFAULT_L2_SENDER, "L1xDM-60");
    }

    function assertValidL1StandardBridge(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IL1StandardBridge bridge = _doo.l1StandardBridgeProxy();
        IL1CrossDomainMessenger messenger = _doo.l1CrossDomainMessengerProxy();

        DeployUtils.assertInitialized({ _contractAddress: address(bridge), _isProxy: true, _slot: 0, _offset: 0 });

        require(address(bridge.MESSENGER()) == address(messenger), "L1SB-10");
        require(address(bridge.messenger()) == address(messenger), "L1SB-20");
        require(address(bridge.OTHER_BRIDGE()) == Predeploys.L2_STANDARD_BRIDGE, "L1SB-30");
        require(address(bridge.otherBridge()) == Predeploys.L2_STANDARD_BRIDGE, "L1SB-40");
        require(address(bridge.superchainConfig()) == address(_doi.opcm().superchainConfig()), "L1SB-50");
    }

    function assertValidAIHIMintableERC20Factory(DeployOPChainInput, DeployOPChainOutput _doo) internal {
        IAIHIMintableERC20Factory factory = _doo.AIHIMintableERC20FactoryProxy();

        DeployUtils.assertInitialized({ _contractAddress: address(factory), _isProxy: true, _slot: 0, _offset: 0 });

        require(factory.BRIDGE() == address(_doo.l1StandardBridgeProxy()), "MERC20F-10");
        require(factory.bridge() == address(_doo.l1StandardBridgeProxy()), "MERC20F-20");
    }

    function assertValidL1ERC721Bridge(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IL1ERC721Bridge bridge = _doo.l1ERC721BridgeProxy();

        DeployUtils.assertInitialized({ _contractAddress: address(bridge), _isProxy: true, _slot: 0, _offset: 0 });

        require(address(bridge.OTHER_BRIDGE()) == Predeploys.L2_ERC721_BRIDGE, "L721B-10");
        require(address(bridge.otherBridge()) == Predeploys.L2_ERC721_BRIDGE, "L721B-20");

        require(address(bridge.MESSENGER()) == address(_doo.l1CrossDomainMessengerProxy()), "L721B-30");
        require(address(bridge.messenger()) == address(_doo.l1CrossDomainMessengerProxy()), "L721B-40");
        require(address(bridge.superchainConfig()) == address(_doi.opcm().superchainConfig()), "L721B-50");
    }

    function assertValidAIHIPortal(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IAIHIPortal portal = _doo.AIHIPortalProxy();
        ISuperchainConfig superchainConfig = ISuperchainConfig(address(_doi.opcm().superchainConfig()));

        require(address(portal.anchorStateRegistry()) == address(_doo.anchorStateRegistryProxy()), "PORTAL-10");
        require(address(portal.disputeGameFactory()) == address(_doo.disputeGameFactoryProxy()), "PORTAL-20");
        require(address(portal.systemConfig()) == address(_doo.systemConfigProxy()), "PORTAL-30");
        require(address(portal.superchainConfig()) == address(superchainConfig), "PORTAL-40");
        require(portal.guardian() == superchainConfig.guardian(), "PORTAL-50");
        require(portal.paused() == superchainConfig.paused(), "PORTAL-60");
        require(portal.l2Sender() == Constants.DEFAULT_L2_SENDER, "PORTAL-70");

        // This slot is the custom gas token _balance and this check ensures
        // that it stays unset for forwards compatibility with custom gas token.
        require(vm.load(address(portal), bytes32(uint256(61))) == bytes32(0), "PORTAL-80");

        // Check once the portal is updated to use the new lockbox.
        require(address(portal.ethLockbox()) == address(_doo.ethLockboxProxy()), "PORTAL-90");
        require(portal.proxyAdminOwner() == _doi.opChainProxyAdminOwner(), "PORTAL-100");
    }

    function assertValidETHLockbox(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IETHLockbox lockbox = _doo.ethLockboxProxy();

        require(address(lockbox.superchainConfig()) == address(_doi.opcm().superchainConfig()), "ETHLOCKBOX-10");
        require(lockbox.authorizedPortals(_doo.AIHIPortalProxy()), "ETHLOCKBOX-20");
        require(lockbox.proxyAdminOwner() == _doi.opChainProxyAdminOwner(), "ETHLOCKBOX-30");
    }

    function assertValidDisputeGameFactory(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IDisputeGameFactory factory = _doo.disputeGameFactoryProxy();

        DeployUtils.assertInitialized({ _contractAddress: address(factory), _isProxy: true, _slot: 0, _offset: 0 });

        require(
            address(factory.gameImpls(GameTypes.PERMISSIONED_CANNON)) == address(_doo.permissionedDisputeGame()),
            "DF-10"
        );
        require(factory.owner() == address(_doi.opChainProxyAdminOwner()), "DF-20");
    }

    function assertValidDelayedWETH(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IDelayedWETH permissioned = _doo.delayedWETHPermissionedGameProxy();

        require(permissioned.owner() == address(_doi.opChainProxyAdminOwner()), "DWETH-10");

        IProxy proxy = IProxy(payable(address(permissioned)));
        vm.prank(address(0));
        address admin = proxy.admin();
        require(admin == address(_doo.opChainProxyAdmin()), "DWETH-20");
    }

    function assertValidAddressManager(DeployOPChainInput, DeployOPChainOutput _doo) internal view {
        require(_doo.addressManager().owner() == address(_doo.opChainProxyAdmin()), "AM-10");
    }

    function assertValidOPChainProxyAdmin(DeployOPChainInput _doi, DeployOPChainOutput _doo) internal {
        IProxyAdmin admin = _doo.opChainProxyAdmin();
        require(admin.owner() == _doi.opChainProxyAdminOwner(), "OPCPA-10");
        require(
            admin.getProxyImplementation(address(_doo.l1CrossDomainMessengerProxy()))
                == DeployUtils.assertResolvedDelegateProxyImplementationSet(
                    "OVM_L1CrossDomainMessenger", _doo.addressManager()
                ),
            "OPCPA-20"
        );
        require(address(admin.addressManager()) == address(_doo.addressManager()), "OPCPA-30");
        require(
            admin.getProxyImplementation(address(_doo.l1StandardBridgeProxy()))
                == DeployUtils.assertL1ChugSplashImplementationSet(address(_doo.l1StandardBridgeProxy())),
            "OPCPA-40"
        );
        require(
            admin.getProxyImplementation(address(_doo.l1ERC721BridgeProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.l1ERC721BridgeProxy())),
            "OPCPA-50"
        );
        require(
            admin.getProxyImplementation(address(_doo.AIHIPortalProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.AIHIPortalProxy())),
            "OPCPA-60"
        );
        require(
            admin.getProxyImplementation(address(_doo.systemConfigProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.systemConfigProxy())),
            "OPCPA-70"
        );
        require(
            admin.getProxyImplementation(address(_doo.AIHIMintableERC20FactoryProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.AIHIMintableERC20FactoryProxy())),
            "OPCPA-80"
        );
        require(
            admin.getProxyImplementation(address(_doo.disputeGameFactoryProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.disputeGameFactoryProxy())),
            "OPCPA-90"
        );
        require(
            admin.getProxyImplementation(address(_doo.delayedWETHPermissionedGameProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.delayedWETHPermissionedGameProxy())),
            "OPCPA-100"
        );
        require(
            admin.getProxyImplementation(address(_doo.anchorStateRegistryProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.anchorStateRegistryProxy())),
            "OPCPA-110"
        );
        require(
            admin.getProxyImplementation(address(_doo.ethLockboxProxy()))
                == DeployUtils.assertERC1967ImplementationSet(address(_doo.ethLockboxProxy())),
            "OPCPA-120"
        );
    }

    // -------- Utilities --------

    function etchIOContracts() public returns (DeployOPChainInput doi_, DeployOPChainOutput doo_) {
        (doi_, doo_) = getIOContracts();
        vm.etch(address(doi_), type(DeployOPChainInput).runtimeCode);
        vm.etch(address(doo_), type(DeployOPChainOutput).runtimeCode);
    }

    function getIOContracts() public view returns (DeployOPChainInput doi_, DeployOPChainOutput doo_) {
        doi_ = DeployOPChainInput(DeployUtils.toIOAddress(msg.sender, "AIHI.DeployOPChainInput"));
        doo_ = DeployOPChainOutput(DeployUtils.toIOAddress(msg.sender, "AIHI.DeployOPChainOutput"));
    }
}
