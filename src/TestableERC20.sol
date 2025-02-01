// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {BridgeContract} from "./BridgeContract.sol";

contract TestableERC20 is ERC20 {
    bool public failTransfers;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function setFailTransfers(bool _fail) external {
        failTransfers = _fail;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (failTransfers)
            revert BridgeContract.BridgeContract__Transaction_Failed();
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (failTransfers)
            revert BridgeContract.BridgeContract__Transaction_Failed();
        return super.transferFrom(from, to, amount);
    }
}
