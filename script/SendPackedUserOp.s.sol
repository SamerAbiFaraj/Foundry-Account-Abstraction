//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOps is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOperations(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // 1. Generate the unsigned data
        uint256 nonce = vm.getNonce(minimalAccount) - 1; // cheatcode to get the nonce from the senders wallet
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        // 2. Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;

        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        // 3. Sign it and return it
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest); //private key
        } else {
            (v, r, s) = vm.sign(config.account, digest); //private key
        }
        userOp.signature = abi.encodePacked(r, s, v); // order is important
        return userOp;
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        public
        pure
        returns (PackedUserOperation memory)
    {
        //Will be the struct without the signature.. hence the unsiged in the name
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = 16777216;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender, // our Minimal account
            nonce: nonce, // number only used once
            initCode: hex"", // ignore  (but like constructor)
            callData: callData, // this is where we put  "the good stuff",  Our minmal account approve USDC transfer. This is the meat of the fucntion
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit), // gas limits
            preVerificationGas: verificationGasLimit, // gas verfication
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas), // Additional gas fees
            paymasterAndData: hex"", // Funds to pay the Alt-mompool
            signature: hex"" // signature
        });
    }
}
