//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/Ethereum/MinimalAccount.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;

    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address randomuser = makeAddr("randomuser");
    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        //vm.prank(address(this));
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
    }
    //Steps:
    //  1. USDC Mint
    //  2. msg.sender --> Will be owner of Minimal Account
    //  3. approve some amount
    //  4. USDC contract
    //  5. come from the entryPoint

    function testOwnerCanExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNotOwnerCannotExecuteCommands() public {
        // Debug logging
        console.log("Random user address:", randomuser);
        console.log("Contract owner:", minimalAccount.owner());
        console.log("EntryPoint address:", minimalAccount.getEntryPoint());

        // Verify our assumptions
        assertNotEq(randomuser, minimalAccount.owner(), "Random user should not be owner");
        assertNotEq(randomuser, minimalAccount.getEntryPoint(), "Random user should not be entryPoint");

        // Log the modifiers condition
        bool isOwner = randomuser == minimalAccount.owner();
        bool isEntryPoint = randomuser == minimalAccount.getEntryPoint();
        console.log("Is randomuser the owner?", isOwner);
        console.log("Is randomuser the entryPoint?", isEntryPoint);

        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        //Act
        vm.prank(randomuser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }
}
