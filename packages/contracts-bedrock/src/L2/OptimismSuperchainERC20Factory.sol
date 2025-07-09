// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BeaconProxy } from "@openzeppelin/contracts-v5/proxy/beacon/BeaconProxy.sol";
import { AIHISuperchainERC20 } from "src/L2/AIHISuperchainERC20.sol";

// Libraries
import { CREATE3 } from "@rari-capital/solmate/src/utils/CREATE3.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";

/// @custom:proxied
/// @custom:predeployed 0x4200000000000000000000000000000000000026
/// @title AIHISuperchainERC20Factory
/// @notice AIHISuperchainERC20Factory is a factory contract that deploys AIHISuperchainERC20 Beacon Proxies
///         using CREATE3.
contract AIHISuperchainERC20Factory is ISemver {
    /// @notice Emitted when an AIHISuperchainERC20 is deployed.
    /// @param superchainToken  Address of the AIHISuperchainERC20 deployment.
    /// @param remoteToken      Address of the corresponding token on the remote chain.
    /// @param deployer         Address of the account that deployed the token.
    event AIHISuperchainERC20Created(
        address indexed superchainToken, address indexed remoteToken, address deployer
    );

    /// @notice Semantic version.
    /// @custom:semver 1.0.1
    string public constant version = "1.0.1";

    /// @notice Mapping of the deployed AIHISuperchainERC20 to the remote token address.
    ///         This is used to keep track of the token deployments.
    mapping(address _localToken => address remoteToken_) public deployments;

    /// @notice Deploys a AIHISuperchainERC20 Beacon Proxy using CREATE3.
    /// @param _remoteToken      Address of the remote token.
    /// @param _name             Name of the AIHISuperchainERC20.
    /// @param _symbol           Symbol of the AIHISuperchainERC20.
    /// @param _decimals         Decimals of the AIHISuperchainERC20.
    /// @return superchainERC20_ Address of the AIHISuperchainERC20 deployment.
    function deploy(
        address _remoteToken,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        external
        returns (address superchainERC20_)
    {
        bytes memory initCallData =
            abi.encodeCall(AIHISuperchainERC20.initialize, (_remoteToken, _name, _symbol, _decimals));

        bytes memory creationCode = bytes.concat(
            type(BeaconProxy).creationCode, abi.encode(Predeploys.AIHI_SUPERCHAIN_ERC20_BEACON, initCallData)
        );

        bytes32 salt = keccak256(abi.encode(_remoteToken, _name, _symbol, _decimals));
        superchainERC20_ = CREATE3.deploy({ salt: salt, creationCode: creationCode, value: 0 });

        deployments[superchainERC20_] = _remoteToken;

        emit AIHISuperchainERC20Created(superchainERC20_, _remoteToken, msg.sender);
    }
}
