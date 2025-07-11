// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title IAIHIMintableERC20
/// @notice This interface is available on the AIHIMintableERC20 contract.
///         We declare it as a separate interface so that it can be used in
///         custom implementations of AIHIMintableERC20.
interface IAIHIMintableERC20 is IERC165 {
    function remoteToken() external view returns (address);

    function bridge() external returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;
}
