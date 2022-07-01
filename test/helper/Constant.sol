// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

library MainnetAddresses {
    // COMMONS
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // STAKE DAO
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant SDT_HOLDER_1 =
        0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant STAKE_DAO_DEPLOYER =
        0xb36a0671B3D49587236d7833B01E79798175875f;
    address public constant STAKE_DAO_MULTISIG =
        0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;
    address public constant SDT_DISTRIBUTOR =
        0x8Dc551B4f5203b51b5366578F42060666D42AB5E;

    address public constant SD_FRAX_3CRV =
        0x5af15DA84A4a6EDf2d9FA6720De921E1026E37b7;
    address public constant STAKE_DAO_FRAX_GAUGE =
        0xEB81b86248d3C2b618CcB071ADB122109DA96Da2;

    // Wrapper
    address public constant SDCRV = 0xD1b5651E55D4CeeD36251c61c50C889B36F6abB5;
    address public constant CRV_DEPOSITOR =
        0xc1e3Ca8A3921719bE0aE3690A0e036feB4f69191;
    address public constant SDCRV_GAUGE =
        0x7f50786A0b15723D741727882ee99a0BF34e3466;

    // Curve
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public constant VECRV = 0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2;

    // Curve Locker
    address public constant CRV_LOCKER =
        0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;

    // Convex
    address public constant CVXCRV = 0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7;
    address public constant CVXCRVCRV_POOL =
        0x9D0464996170c6B9e75eED71c68B99dDEDf279e8;

    // Yearn
    address public constant YVECRV = 0xc5bDdf9843308380375a611c18B50Fb9341f502A;

    // Sushi
    address public constant SUSHIROUTER =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
}
