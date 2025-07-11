// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Forge
import { Script } from "forge-std/Script.sol";

// Scripts
import { BaseDeployIO } from "scripts/deploy/BaseDeployIO.sol";
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";

// Interfaces
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import {
    IStandardValidatorBase,
    IStandardValidatorV180,
    IStandardValidatorV200,
    IStandardValidatorV300
} from "interfaces/L1/IStandardValidator.sol";

/// @title DeployStandardValidatorInput
contract DeployStandardValidatorInput is BaseDeployIO {
    // Release field to determine which validator to deploy
    string internal _release;

    // Required inputs
    ISuperchainConfig internal _superchainConfig;
    address internal _l1PAOMultisig;
    address internal _mips;
    address internal _challenger;
    uint256 internal _withdrawalDelaySeconds;

    // Implementation addresses
    address internal _superchainConfigImpl;
    address internal _protocolVersionsImpl;
    address internal _l1ERC721BridgeImpl;
    address internal _AIHIPortalImpl;
    address internal _systemConfigImpl;
    address internal _AIHIMintableERC20FactoryImpl;
    address internal _l1CrossDomainMessengerImpl;
    address internal _l1StandardBridgeImpl;
    address internal _disputeGameFactoryImpl;
    address internal _anchorStateRegistryImpl;
    address internal _delayedWETHImpl;
    address internal _mipsImpl;

    function set(bytes4 _sel, address _value) public {
        if (_sel == this.superchainConfig.selector) {
            require(_value != address(0), "DeployStandardValidator: superchainConfig cannot be empty");
            _superchainConfig = ISuperchainConfig(_value);
        } else if (_sel == this.l1PAOMultisig.selector) {
            require(_value != address(0), "DeployStandardValidator: l1PAOMultisig cannot be empty");
            _l1PAOMultisig = _value;
        } else if (_sel == this.challenger.selector) {
            require(_value != address(0), "DeployStandardValidator: challenger cannot be empty");
            _challenger = _value;
        } else if (_sel == this.superchainConfigImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: superchainConfigImpl cannot be empty");
            _superchainConfigImpl = _value;
        } else if (_sel == this.protocolVersionsImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: protocolVersionsImpl cannot be empty");
            _protocolVersionsImpl = _value;
        } else if (_sel == this.l1ERC721BridgeImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: l1ERC721BridgeImpl cannot be empty");
            _l1ERC721BridgeImpl = _value;
        } else if (_sel == this.AIHIPortalImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: AIHIPortalImpl cannot be empty");
            _AIHIPortalImpl = _value;
        } else if (_sel == this.systemConfigImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: systemConfigImpl cannot be empty");
            _systemConfigImpl = _value;
        } else if (_sel == this.AIHIMintableERC20FactoryImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: AIHIMintableERC20FactoryImpl cannot be empty");
            _AIHIMintableERC20FactoryImpl = _value;
        } else if (_sel == this.l1CrossDomainMessengerImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: l1CrossDomainMessengerImpl cannot be empty");
            _l1CrossDomainMessengerImpl = _value;
        } else if (_sel == this.l1StandardBridgeImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: l1StandardBridgeImpl cannot be empty");
            _l1StandardBridgeImpl = _value;
        } else if (_sel == this.disputeGameFactoryImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: disputeGameFactoryImpl cannot be empty");
            _disputeGameFactoryImpl = _value;
        } else if (_sel == this.anchorStateRegistryImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: anchorStateRegistryImpl cannot be empty");
            _anchorStateRegistryImpl = _value;
        } else if (_sel == this.delayedWETHImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: delayedWETHImpl cannot be empty");
            _delayedWETHImpl = _value;
        } else if (_sel == this.mipsImpl.selector) {
            require(_value != address(0), "DeployStandardValidator: mipsImpl cannot be empty");
            _mipsImpl = _value;
        } else {
            revert("DeployStandardValidator: unknown selector");
        }
    }

    function set(bytes4 _sel, string memory _value) public {
        if (_sel == this.release.selector) {
            _release = _value;
        } else {
            revert("DeployStandardValidator: unknown selector");
        }
    }

    function set(bytes4 _sel, uint256 _value) public {
        if (_sel == this.withdrawalDelaySeconds.selector) {
            require(_value > 0, "DeployStandardValidator: withdrawalDelaySeconds must be greater than 0");
            _withdrawalDelaySeconds = _value;
        } else {
            revert("DeployStandardValidator: unknown selector");
        }
    }

    function release() public view returns (string memory) {
        require(bytes(_release).length > 0, "DeployStandardValidator: release version not set");
        return _release;
    }

    function superchainConfig() public view returns (ISuperchainConfig) {
        require(address(_superchainConfig) != address(0), "DeployStandardValidator: superchainConfig not set");
        return _superchainConfig;
    }

    function l1PAOMultisig() public view returns (address) {
        require(_l1PAOMultisig != address(0), "DeployStandardValidator: l1PAOMultisig not set");
        return _l1PAOMultisig;
    }

    function challenger() public view returns (address) {
        require(_challenger != address(0), "DeployStandardValidator: challenger not set");
        return _challenger;
    }

    function superchainConfigImpl() public view returns (address) {
        require(_superchainConfigImpl != address(0), "DeployStandardValidator: superchainConfigImpl not set");
        return _superchainConfigImpl;
    }

    function protocolVersionsImpl() public view returns (address) {
        require(_protocolVersionsImpl != address(0), "DeployStandardValidator: protocolVersionsImpl not set");
        return _protocolVersionsImpl;
    }

    function l1ERC721BridgeImpl() public view returns (address) {
        require(_l1ERC721BridgeImpl != address(0), "DeployStandardValidator: l1ERC721BridgeImpl not set");
        return _l1ERC721BridgeImpl;
    }

    function AIHIPortalImpl() public view returns (address) {
        require(_AIHIPortalImpl != address(0), "DeployStandardValidator: AIHIPortalImpl not set");
        return _AIHIPortalImpl;
    }

    function systemConfigImpl() public view returns (address) {
        require(_systemConfigImpl != address(0), "DeployStandardValidator: systemConfigImpl not set");
        return _systemConfigImpl;
    }

    function AIHIMintableERC20FactoryImpl() public view returns (address) {
        require(
            _AIHIMintableERC20FactoryImpl != address(0),
            "DeployStandardValidator: AIHIMintableERC20FactoryImpl not set"
        );
        return _AIHIMintableERC20FactoryImpl;
    }

    function l1CrossDomainMessengerImpl() public view returns (address) {
        require(
            _l1CrossDomainMessengerImpl != address(0), "DeployStandardValidator: l1CrossDomainMessengerImpl not set"
        );
        return _l1CrossDomainMessengerImpl;
    }

    function l1StandardBridgeImpl() public view returns (address) {
        require(_l1StandardBridgeImpl != address(0), "DeployStandardValidator: l1StandardBridgeImpl not set");
        return _l1StandardBridgeImpl;
    }

    function disputeGameFactoryImpl() public view returns (address) {
        require(_disputeGameFactoryImpl != address(0), "DeployStandardValidator: disputeGameFactoryImpl not set");
        return _disputeGameFactoryImpl;
    }

    function anchorStateRegistryImpl() public view returns (address) {
        require(_anchorStateRegistryImpl != address(0), "DeployStandardValidator: anchorStateRegistryImpl not set");
        return _anchorStateRegistryImpl;
    }

    function delayedWETHImpl() public view returns (address) {
        require(_delayedWETHImpl != address(0), "DeployStandardValidator: delayedWETHImpl not set");
        return _delayedWETHImpl;
    }

    function mipsImpl() public view returns (address) {
        require(_mipsImpl != address(0), "DeployStandardValidator: mipsImpl not set");
        return _mipsImpl;
    }

    function withdrawalDelaySeconds() public view returns (uint256) {
        require(_withdrawalDelaySeconds > 0, "DeployStandardValidator: withdrawalDelaySeconds not set");
        return _withdrawalDelaySeconds;
    }
}

/// @title DeployStandardValidatorOutput
contract DeployStandardValidatorOutput is BaseDeployIO {
    address internal _validator;

    function set(bytes4 _sel, address _value) public {
        if (_sel == this.validator.selector) {
            require(_value != address(0), "DeployStandardValidator: validator cannot be zero address");
            _validator = _value;
        } else {
            revert("DeployStandardValidator: unknown selector");
        }
    }

    function validator() public view returns (address) {
        DeployUtils.assertValidContractAddress(_validator);
        return _validator;
    }
}

/// @title DeployStandardValidator
contract DeployStandardValidator is Script {
    function run(DeployStandardValidatorInput _si, DeployStandardValidatorOutput _so) public {
        deployValidator(_si, _so);
        assertValidDeploy(_si, _so);
    }

    function getImplementations(DeployStandardValidatorInput _si)
        public
        view
        returns (IStandardValidatorBase.ImplementationsBase memory)
    {
        return IStandardValidatorBase.ImplementationsBase({
            l1ERC721BridgeImpl: _si.l1ERC721BridgeImpl(),
            AIHIPortalImpl: _si.AIHIPortalImpl(),
            systemConfigImpl: _si.systemConfigImpl(),
            AIHIMintableERC20FactoryImpl: _si.AIHIMintableERC20FactoryImpl(),
            l1CrossDomainMessengerImpl: _si.l1CrossDomainMessengerImpl(),
            l1StandardBridgeImpl: _si.l1StandardBridgeImpl(),
            disputeGameFactoryImpl: _si.disputeGameFactoryImpl(),
            anchorStateRegistryImpl: _si.anchorStateRegistryImpl(),
            delayedWETHImpl: _si.delayedWETHImpl(),
            mipsImpl: _si.mipsImpl()
        });
    }

    function deployValidator(DeployStandardValidatorInput _si, DeployStandardValidatorOutput _so) internal {
        address validator;
        if (keccak256(bytes(_si.release())) == keccak256(bytes("v1.8.0"))) {
            validator = deployValidatorV180(_si);
        } else if (keccak256(bytes(_si.release())) == keccak256(bytes("v2.0.0"))) {
            validator = deployValidatorV200(_si);
        } else if (keccak256(bytes(_si.release())) == keccak256(bytes("v3.0.0"))) {
            validator = deployValidatorV300(_si);
        } else {
            revert("DeployStandardValidator: invalid release version");
        }

        _so.set(_so.validator.selector, validator);
    }

    function deployValidatorV180(DeployStandardValidatorInput _si) internal returns (address) {
        address validator = DeployUtils.createDeterministic({
            _name: "StandardValidator.sol:StandardValidatorV180",
            _args: DeployUtils.encodeConstructor(
                abi.encodeCall(
                    IStandardValidatorV180.__constructor__,
                    (
                        getImplementations(_si),
                        _si.superchainConfig(),
                        _si.l1PAOMultisig(),
                        _si.challenger(),
                        _si.withdrawalDelaySeconds()
                    )
                )
            ),
            _salt: DeployUtils.DEFAULT_SALT
        });

        vm.label(validator, "StandardValidatorV180");
        return validator;
    }

    function deployValidatorV200(DeployStandardValidatorInput _si) internal returns (address) {
        address validator = DeployUtils.createDeterministic({
            _name: "StandardValidator.sol:StandardValidatorV200",
            _args: DeployUtils.encodeConstructor(
                abi.encodeCall(
                    IStandardValidatorV200.__constructor__,
                    (
                        getImplementations(_si),
                        _si.superchainConfig(),
                        _si.l1PAOMultisig(),
                        _si.challenger(),
                        _si.withdrawalDelaySeconds()
                    )
                )
            ),
            _salt: DeployUtils.DEFAULT_SALT
        });

        vm.label(validator, "StandardValidatorV200");
        return validator;
    }

    function deployValidatorV300(DeployStandardValidatorInput _si) internal returns (address) {
        address validator = DeployUtils.createDeterministic({
            _name: "StandardValidator.sol:StandardValidatorV300",
            _args: DeployUtils.encodeConstructor(
                abi.encodeCall(
                    IStandardValidatorV300.__constructor__,
                    (
                        getImplementations(_si),
                        _si.superchainConfig(),
                        _si.l1PAOMultisig(),
                        _si.challenger(),
                        _si.withdrawalDelaySeconds()
                    )
                )
            ),
            _salt: DeployUtils.DEFAULT_SALT
        });

        vm.label(validator, "StandardValidatorV300");
        return validator;
    }

    function assertValidDeploy(DeployStandardValidatorInput _si, DeployStandardValidatorOutput _so) public view {
        DeployUtils.assertValidContractAddress(_so.validator());
        assertValidValidator(_si, _so);
    }

    function assertValidValidator(DeployStandardValidatorInput _si, DeployStandardValidatorOutput _so) internal view {
        address validator = _so.validator();

        if (keccak256(bytes(_si.release())) == keccak256(bytes("v1.8.0"))) {
            assertValidValidatorV180(_si, validator);
        } else if (keccak256(bytes(_si.release())) == keccak256(bytes("v2.0.0"))) {
            assertValidValidatorV200(_si, validator);
        }
    }

    function assertValidValidatorV180(DeployStandardValidatorInput _si, address _validator) internal view {
        IStandardValidatorV180 v180 = IStandardValidatorV180(_validator);
        require(address(v180.superchainConfig()) == address(_si.superchainConfig()), "SV180-10");
        require(v180.l1PAOMultisig() == _si.l1PAOMultisig(), "SV180-20");
        require(v180.challenger() == _si.challenger(), "SV180-40");
        require(v180.withdrawalDelaySeconds() == _si.withdrawalDelaySeconds(), "SV180-50");
    }

    function assertValidValidatorV200(DeployStandardValidatorInput _si, address _validator) internal view {
        IStandardValidatorV200 v200 = IStandardValidatorV200(_validator);
        require(address(v200.superchainConfig()) == address(_si.superchainConfig()), "SV200-10");
        require(v200.l1PAOMultisig() == _si.l1PAOMultisig(), "SV200-20");
        require(v200.challenger() == _si.challenger(), "SV200-40");
        require(v200.withdrawalDelaySeconds() == _si.withdrawalDelaySeconds(), "SV200-50");
    }
}
