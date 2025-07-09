// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAIHIMintableERC20Factory {
    event Initialized(uint8 version);
    event AIHIMintableERC20Created(address indexed localToken, address indexed remoteToken, address deployer);
    event StandardL2TokenCreated(address indexed remoteToken, address indexed localToken);

    function BRIDGE() external view returns (address);
    function bridge() external view returns (address);
    function createAIHIMintableERC20(
        address _remoteToken,
        string memory _name,
        string memory _symbol
    )
        external
        returns (address);
    function createAIHIMintableERC20WithDecimals(
        address _remoteToken,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        external
        returns (address);
    function createStandardL2Token(
        address _remoteToken,
        string memory _name,
        string memory _symbol
    )
        external
        returns (address);
    function deployments(address) external view returns (address);
    function initialize(address _bridge) external;
    function version() external view returns (string memory);

    function __constructor__() external;
}
