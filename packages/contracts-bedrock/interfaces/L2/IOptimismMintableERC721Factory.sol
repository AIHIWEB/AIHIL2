// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAIHIMintableERC721Factory {
    event AIHIMintableERC721Created(address indexed localToken, address indexed remoteToken, address deployer);

    function BRIDGE() external view returns (address);
    function REMOTE_CHAIN_ID() external view returns (uint256);
    function bridge() external view returns (address);
    function createAIHIMintableERC721(
        address _remoteToken,
        string memory _name,
        string memory _symbol
    )
        external
        returns (address);
    function isAIHIMintableERC721(address) external view returns (bool);
    function remoteChainID() external view returns (uint256);
    function version() external view returns (string memory);

    function __constructor__(address _bridge, uint256 _remoteChainId) external;
}
