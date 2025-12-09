// SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { L1BossBridge } from "../../src/L1BossBridge.sol";
import { L1Token } from "../../src/L1Token.sol";
import { L1Vault } from "../../src/L1Vault.sol";
import { TokenFactory } from "../../src/TokenFactory.sol";
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Handler is Test {

    L1BossBridge bridge;
    L1Token token;
    L1Vault vault;
    uint256 public value;
    // TokenFactory factory;

    constructor(L1Token _token, L1BossBridge _bridge, L1Vault _vault) {
        token = _token;
        bridge = _bridge;
        vault = _vault;
        // factory = _factory;
    }

    function deposit(address from, address to,uint256 amount) public{
        vm.assume(from != address(0));
        vm.assume(to != address(0));

        uint256 v = bridge.DEPOSIT_LIMIT();
        amount = bound(amount, 1, 1e18);
        value = amount;
        deal(address(token),from,amount);
        vm.startPrank(from);
        token.approve(address(bridge), type(uint256).max);
        bridge.depositTokensToL2(from, to, amount);
        vm.stopPrank();
    }

}