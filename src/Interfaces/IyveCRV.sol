// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IyveCRV {
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}
