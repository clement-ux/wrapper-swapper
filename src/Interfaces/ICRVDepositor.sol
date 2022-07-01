// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ICRVDepositor {
    function lockIncentive() external view returns (uint256);

    function incentiveToken() external view returns(uint256);

    function FEE_DENOMINATOR() external view returns (uint256);

    function deposit(
        uint256 _amount,
        bool _lock,
        bool _stake,
        address _user
    ) external;
}
