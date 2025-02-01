// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TestableERC20} from "../src/TestableERC20.sol";
import {BridgeContract} from "../src/BridgeContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeTest is Test {
    BridgeContract public bridge;
    TestableERC20 public token;

    address public owner;
    address public user;

    uint256 public constant INITIAL_BALANCE = 10000;
    uint256 public constant BRIDGE_AMOUNT = 100;

    event TokensBridged(IERC20 token, uint256 amount, address from);
    event TokensRedeemed(IERC20 token, address to, uint256 amount);

    function setUp() public {
        owner = msg.sender;
        user = makeAddr("user");
        vm.startPrank(owner);
        bridge = new BridgeContract();
        token = new TestableERC20("Test Token", "TEST");
        token.mint(user, INITIAL_BALANCE);
        token.setFailTransfers(false);
        vm.stopPrank();
    }

    function test_setUp() public {
        assertTrue(
            address(bridge) != address(0),
            "Bridge contract not deployed"
        );
        assertTrue(address(token) != address(0), "Token contract not deployed");
        assertEq(bridge.owner(), owner, "Bridge owner not set correctly");
        assertEq(
            token.balanceOf(user),
            INITIAL_BALANCE,
            "User initial balance incorrect"
        );
        assertEq(
            token.balanceOf(address(bridge)),
            0,
            "Bridge should start with 0 balance"
        );
        assertEq(token.name(), "Test Token", "Token name incorrect");
        assertEq(token.symbol(), "TEST", "Token symbol incorrect");

        token.setFailTransfers(false);
        assertFalse(token.failTransfers(), "Token transfers should be enabled");
    }

    function test_bridge_Success() public {
        token.setFailTransfers(false);
        vm.startPrank(user);
        token.approve(address(bridge), BRIDGE_AMOUNT);

        vm.expectEmit(false, false, false, true);
        emit TokensBridged(IERC20(address(token)), BRIDGE_AMOUNT, user);
        bridge.bridge(token, BRIDGE_AMOUNT);

        assertEq(token.balanceOf(user), INITIAL_BALANCE - BRIDGE_AMOUNT);
        assertEq(token.balanceOf(address(bridge)), BRIDGE_AMOUNT);

        vm.stopPrank();
    }

    function test_bridge_ZeroAmount() public {
        vm.startPrank(user);
        token.approve(address(bridge), 0);

        vm.expectRevert("Amount must be greater than 0");
        bridge.bridge(token, 0);

        vm.stopPrank();
    }

    function test_bridge_ExceedingBalance() public {
        uint256 excessAmount = INITIAL_BALANCE + 1;
        vm.startPrank(user);
        token.approve(address(bridge), excessAmount);

        vm.expectRevert();
        bridge.bridge(token, excessAmount);

        console.log("Bridge operation with excessive amount reverted");
        vm.stopPrank();
    }

    function test_bridge_InvalidToken() public {
        vm.startPrank(user);

        //deply contract but don't mint any tokens
        TestableERC20 newToken = new TestableERC20("Invalid", "INV");
        vm.expectRevert();
        bridge.bridge(newToken, BRIDGE_AMOUNT);

        console.log("Bridge operation with invalid token reverted");
        vm.stopPrank();
    }

    function test_bridge_InsufficientAllowance() public {
        vm.startPrank(user);
        vm.expectRevert(
            BridgeContract.BridgeContract__Insufficient_Allowance.selector
        );
        bridge.bridge(token, BRIDGE_AMOUNT);

        vm.stopPrank();
    }

    function test_bridge_FailedTransfer() public {
        vm.startPrank(user);
        token.approve(address(bridge), BRIDGE_AMOUNT);
        token.setFailTransfers(true);
        vm.expectRevert(
            BridgeContract.BridgeContract__Transaction_Failed.selector
        );
        bridge.bridge(token, BRIDGE_AMOUNT);
        vm.stopPrank();
    }

    function test_redeem_Success() public {
        token.setFailTransfers(false);

        //approve and bridge tokens
        uint256 amount = 10;
        vm.startPrank(user);
        token.approve(address(bridge), amount);
        bridge.bridge(token, amount);
        vm.stopPrank();

        address recipient = makeAddr("recipient");

        vm.startPrank(owner);
        assertEq(token.balanceOf(address(bridge)), amount);
        vm.expectEmit(false, false, false, true);

        //redeem tokens by owner
        emit TokensRedeemed(IERC20(address(token)), recipient, amount);
        bridge.redeem(token, recipient, amount, 0);

        // final states
        assertEq(
            token.balanceOf(recipient),
            amount,
            "Recipient should have received tokens"
        );
        assertEq(
            token.balanceOf(address(bridge)),
            0,
            "Bridge should have zero balance"
        );
        assertEq(
            token.balanceOf(user),
            INITIAL_BALANCE - amount,
            "User should have reduced balance"
        );
        vm.stopPrank();
    }

    function test_redeem_PartialAmount() public {
        token.setFailTransfers(false);

        vm.startPrank(user);
        token.approve(address(bridge), BRIDGE_AMOUNT);
        bridge.bridge(token, BRIDGE_AMOUNT);
        vm.stopPrank();

        uint256 partialAmount = BRIDGE_AMOUNT / 2;
        address recipient = makeAddr("recipient");

        vm.startPrank(owner);
        bridge.redeem(token, recipient, partialAmount, 0);

        assertEq(token.balanceOf(recipient), partialAmount);
        assertEq(
            token.balanceOf(address(bridge)),
            BRIDGE_AMOUNT - partialAmount
        );

        vm.stopPrank();
    }

    function test_redeem_NonOwnerAttempt() public {
        token.setFailTransfers(false);

        vm.startPrank(user);
        token.approve(address(bridge), BRIDGE_AMOUNT);
        bridge.bridge(token, BRIDGE_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );

        bridge.redeem(token, user, BRIDGE_AMOUNT, 1);
        console.log("Redeem attempt by non-owner reverted");
        vm.stopPrank();
    }

    function test_Nonce() public {
        token.setFailTransfers(false);

        //initial nonce
        assertEq(bridge.nonce(), 0, "Initial nonce should be 0");

        //bridge some tokens
        vm.startPrank(user);
        uint256 amount = 10;
        token.approve(address(bridge), amount);
        bridge.bridge(token, amount);
        vm.stopPrank();

        vm.startPrank(owner);

        bridge.redeem(token, user, amount, 0);
        assertEq(
            bridge.nonce(),
            1,
            "Nonce should increment after successful redeem"
        );

        //redeem with same nonce again
        vm.expectRevert("invalid nonce");
        bridge.redeem(token, user, amount, 0);

        //redeem with future nonce
        vm.expectRevert("invalid nonce");
        bridge.redeem(token, user, amount, 2);

        vm.stopPrank();
    }

    function test_redeem_FailedTransfer() public {
        token.setFailTransfers(false);

        vm.startPrank(user);
        token.approve(address(bridge), BRIDGE_AMOUNT);
        bridge.bridge(token, BRIDGE_AMOUNT);
        vm.stopPrank();

        //enable transfer failures for the redeem test
        token.setFailTransfers(true);

        vm.startPrank(owner);
        vm.expectRevert(
            BridgeContract.BridgeContract__Transaction_Failed.selector
        );
        bridge.redeem(token, user, BRIDGE_AMOUNT, 0);

        //verify bridge still has the tokens
        assertEq(
            token.balanceOf(address(bridge)),
            BRIDGE_AMOUNT,
            "Bridge should still have tokens"
        );
        vm.stopPrank();
    }

    function test_redeem_InsufficientBalance() public {
        vm.startPrank(owner);

        vm.expectRevert();
        bridge.redeem(token, user, BRIDGE_AMOUNT, 1);

        assertEq(
            token.balanceOf(address(bridge)),
            0,
            "Bridge balance should remain 0"
        );
        assertEq(
            token.balanceOf(user),
            INITIAL_BALANCE,
            "User balance should be unchanged"
        );

        vm.stopPrank();
        console.log("Redeem with insufficient balance failed as expected");
    }
}
