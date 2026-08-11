// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    event YieldDeposited(address indexed owner, uint256 amount);

    constructor(IERC20 asset_)
        ERC20("Staking Vault Shares", "svTOKEN")
        ERC4626(asset_)
        Ownable(msg.sender)
    {}

    function depositYield(uint256 amount) external onlyOwner {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        emit YieldDeposited(msg.sender, amount);
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }
}