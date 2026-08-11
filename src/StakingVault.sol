// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingVault is ERC4626 {
    constructor(IERC20 asset_)
        ERC20("Staking Vault Shares", "svTOKEN")
        ERC4626(asset_)
    {}
}