//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/Ethereum/MinimalAccount.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOps, PackedUserOperation, IEntryPoint} from "../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOps sendPackedUserOps = new SendPackedUserOps();

    //address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
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

    function testRecoverSignedOp() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOps.generateSignedUserOperations(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        //Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        //Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    // 1. Sign user Ops
    // 2. Call validate userOPs
    // 3. Assert the return is correct
    function testValidionOfUserOps() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOps.generateSignedUserOperations(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        //Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

        //Assert
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteTheCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOps.generateSignedUserOperations(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        //bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        //Act
        vm.prank(randomuser);
        vm.deal(address(minimalAccount), 2e18);
        vm.deal(randomuser, 2e18);
        console.log("Balance of MinimalAccount: %s", usdc.balanceOf(address(minimalAccount)));
        console.log("Amount: %", AMOUNT);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomuser));

        //Assert
        console.log("Balance of MinimalAccount: %s", usdc.balanceOf(address(minimalAccount)));
        console.log("Amount: %", AMOUNT);
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testEntryPointCanExecuteTheCommands2() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        // Let's add some debug logs
        console.log("MinimalAccount address:", address(minimalAccount));
        console.log("Is account deployed?", address(minimalAccount).code.length > 0);

        PackedUserOperation memory packedUserOp = sendPackedUserOps.generateSignedUserOperations(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );

        // Let's verify the UserOp fields
        console.log("Sender:", packedUserOp.sender);
        console.log("Nonce:", packedUserOp.nonce);
        console.log("InitCode length:", packedUserOp.initCode.length);
        console.log("Signature length:", packedUserOp.signature.length);

        // Get and verify the userOpHash
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        console.log("UserOpHash:", vm.toString(userOperationHash));

        vm.deal(address(minimalAccount), 2e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        vm.prank(randomuser);
        vm.deal(randomuser, 2e18);

        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomuser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
