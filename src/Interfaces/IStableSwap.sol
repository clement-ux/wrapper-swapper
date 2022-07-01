// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IStableSwap {
    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function get_dy(int128 i,int128 j,uint256 dx) external view returns(uint256);
}
