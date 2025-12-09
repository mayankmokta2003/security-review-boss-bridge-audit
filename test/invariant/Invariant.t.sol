// SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "../../lib/forge-std/src/StdInvariant.sol";
import { L1BossBridge } from "../../src/L1BossBridge.sol";
import { L1Token } from "../../src/L1Token.sol";
import { L1Vault } from "../../src/L1Vault.sol";
import { TokenFactory } from "../../src/TokenFactory.sol";
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import { Handler } from "./Handler.t.sol";

contract Invariant is StdInvariant, Test{

    L1Token token;
    L1BossBridge bridge;
    L1Vault vault;
    // TokenFactory factory;
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address userInL2 = makeAddr("userInL2");
    Handler handler;

    function setUp() external {

        token = new L1Token();
        token.transfer(owner,1000e18);
        bridge = new L1BossBridge(IERC20(token));
        // vault = new L1Vault(IERC20(token));
        vault = bridge.vault();

        handler = new Handler(token,bridge,vault);
        address addr = address(handler);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.deposit.selector;
        targetSelector(FuzzSelector({addr: addr,selectors: selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz_DepositAmountShouldGetAddedInVault() public view{

        uint256 vaultBalance = token.balanceOf(address(vault));
        assert(vaultBalance <= bridge.DEPOSIT_LIMIT());
    }
    

}