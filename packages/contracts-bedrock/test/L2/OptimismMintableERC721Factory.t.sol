// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { CommonTest } from "test/setup/CommonTest.sol";
import { AIHIMintableERC721 } from "src/L2/AIHIMintableERC721.sol";
import { AIHIMintableERC721Factory } from "src/L2/AIHIMintableERC721Factory.sol";

contract AIHIMintableERC721Factory_Test is CommonTest {
    event AIHIMintableERC721Created(address indexed localToken, address indexed remoteToken, address deployer);

    function test_constructor_succeeds() external view {
        assertEq(l2AIHIMintableERC721Factory.BRIDGE(), address(l2ERC721Bridge));
        assertEq(l2AIHIMintableERC721Factory.bridge(), address(l2ERC721Bridge));
        assertEq(l2AIHIMintableERC721Factory.REMOTE_CHAIN_ID(), deploy.cfg().l1ChainID());
        assertEq(l2AIHIMintableERC721Factory.remoteChainID(), deploy.cfg().l1ChainID());
    }

    function test_createAIHIMintableERC721_succeeds() external {
        address remote = address(1234);
        address local = calculateTokenAddress(address(1234), "L2Token", "L2T");

        // Expect a token creation event.
        vm.expectEmit(address(l2AIHIMintableERC721Factory));
        emit AIHIMintableERC721Created(local, remote, alice);

        // Create the token.
        vm.prank(alice);
        AIHIMintableERC721 created = AIHIMintableERC721(
            l2AIHIMintableERC721Factory.createAIHIMintableERC721(remote, "L2Token", "L2T")
        );

        // Token address should be correct.
        assertEq(address(created), local);

        // Should be marked as created by the factory.
        assertTrue(l2AIHIMintableERC721Factory.isAIHIMintableERC721(address(created)));

        // Token should've been constructed correctly.
        assertEq(created.name(), "L2Token");
        assertEq(created.symbol(), "L2T");
        assertEq(created.REMOTE_TOKEN(), remote);
        assertEq(created.BRIDGE(), address(l2ERC721Bridge));
        assertEq(created.REMOTE_CHAIN_ID(), deploy.cfg().l1ChainID());
    }

    function test_createAIHIMintableERC721_sameTwice_reverts() external {
        address remote = address(1234);

        vm.prank(alice);
        l2AIHIMintableERC721Factory.createAIHIMintableERC721(remote, "L2Token", "L2T");

        vm.expectRevert(bytes(""));

        vm.prank(alice);
        l2AIHIMintableERC721Factory.createAIHIMintableERC721(remote, "L2Token", "L2T");
    }

    function test_createAIHIMintableERC721_zeroRemoteToken_reverts() external {
        // Try to create a token with a zero remote token address.
        vm.expectRevert("AIHIMintableERC721Factory: L1 token address cannot be address(0)");
        l2AIHIMintableERC721Factory.createAIHIMintableERC721(address(0), "L2Token", "L2T");
    }

    function calculateTokenAddress(
        address _remote,
        string memory _name,
        string memory _symbol
    )
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs =
            abi.encode(address(l2ERC721Bridge), deploy.cfg().l1ChainID(), _remote, _name, _symbol);
        bytes memory bytecode = abi.encodePacked(type(AIHIMintableERC721).creationCode, constructorArgs);
        bytes32 salt = keccak256(abi.encode(_remote, _name, _symbol));
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(l2AIHIMintableERC721Factory), salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }
}
