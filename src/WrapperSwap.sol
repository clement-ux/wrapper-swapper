// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Interfaces/IStableSwap.sol";
import "./Interfaces/ICRVDepositor.sol";
import "./Interfaces/IUniswapRouter.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract WrapperSwap {
    uint256 public total_cvxCRVsdCRV;
    uint256 public total_yveCRVsdCRV;
    uint256 public constant DENOMINATOR = 10000;

    // CRV
    address public constant CRV =
        address(0xD533a949740bb3306d119CC777fa900bA034cd52); // Index 0
    address public CRV_Depositor =
        address(0xc1e3Ca8A3921719bE0aE3690A0e036feB4f69191);

    // Convex
    address public constant CVXCRV =
        address(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7); // Index 1
    address public cvxCRVCRVPool =
        address(0x9D0464996170c6B9e75eED71c68B99dDEDf279e8);

    // Yearn
    address public constant SUSHIROUTER =
        address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address public constant YVECRV =
        address(0xc5bDdf9843308380375a611c18B50Fb9341f502A);
    address[] public yveCRVtoCRVPath;

    // governance
    address public owner;

    constructor(address[] memory _yveCRVtoCRVPath) {
        owner = msg.sender;
        yveCRVtoCRVPath = _yveCRVtoCRVPath;
        IERC20(CRV).approve(CRV_Depositor, type(uint256).max);
        IERC20(CVXCRV).approve(cvxCRVCRVPool, type(uint256).max);
        IERC20(YVECRV).approve(SUSHIROUTER, type(uint256).max);
    }

    /// @notice Swap cvxCRV into sdCRV
    /// @param _amount Amount of cvxCRV to convert
    /// @param _slippage Max slippage (100 -> 1%)
    /// @param _lock If user want to lock all waiting CRV on locker
    /// @param _stake If user want to stake sdCRV into the gauge
    /// @return _crvSwapped Amount of CRV obtain from cvxCRV swap
    function cvxCRVsdCRVSwap(
        uint256 _amount,
        uint256 _slippage,
        bool _lock,
        bool _stake
    ) external returns (uint256 _crvSwapped) {
        // get cvxCRV from user
        bool success = IERC20(CVXCRV).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "transfer failed");

        // Swap
        uint256 _crvAmount = _swapOnCurve(_amount, _slippage);
        total_cvxCRVsdCRV += _crvAmount;

        // Use depositor
        ICRVDepositor(CRV_Depositor).deposit(
            _crvAmount,
            _lock,
            _stake,
            msg.sender
        );

        return (_crvAmount);
    }

    /// @notice Swap yveCRV into sdCRV
    /// @param _amount Amount of yveCRV to convert
    /// @param _slippage Max slippage (100 -> 1%)
    /// @param _lock If user want to lock all waiting CRV on locker
    /// @param _stake If user want to stake sdCRV into the gauge
    /// @return _crvSwapped Amount of CRV obtain from yveCRV swap
    function yveCRVsdCRVSwap(
        uint256 _amount,
        uint256 _slippage,
        bool _lock,
        bool _stake
    ) external returns (uint256) {
        // get yveCRV from user
        bool success = IERC20(YVECRV).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "transfer failed");

        // Swap
        uint256 _crvAmount = _swapOnSushi(_amount, _slippage);
        total_yveCRVsdCRV += _crvAmount;

        // Use depositor
        ICRVDepositor(CRV_Depositor).deposit(
            _crvAmount,
            _lock,
            _stake,
            msg.sender
        );

        return (_crvAmount);
    }

    /// @notice Swap cvxCRV for CRV on Curve
    /// @param _amount Amount of cvxCRV to swap
    /// @param _slippage Max slippage (100 -> 1%)
    /// @return _output Amount of CRV obtain from cvxCRV swap
    function _swapOnCurve(uint256 _amount, uint256 _slippage)
        internal
        returns (uint256 _output)
    {
        // calculate amount received
        uint256 amount = IStableSwap(cvxCRVCRVPool).get_dy(1, 0, _amount);
        // calculate minimum amount received
        uint256 minAmount = (amount * (DENOMINATOR - _slippage)) / DENOMINATOR;

        // swap cvxCRV for CRV
        uint256 output = IStableSwap(cvxCRVCRVPool).exchange(
            1,
            0,
            _amount,
            minAmount,
            address(this)
        );

        // event
        emit RECEIVED(CRV, address(this), output);

        return (output);
    }

    /// @notice Swap yveCRV for CRV on Sushiswap
    /// @param _amount Amount of yveCRV to swap
    /// @param _slippage Max slippage (100 -> 1%)
    /// @return _output Amount of CRV obtain from yveCRV swap
    function _swapOnSushi(uint256 _amount, uint256 _slippage)
        internal
        returns (uint256)
    {
        // calculate amount received
        uint256[] memory amounts = IUniswapRouter(SUSHIROUTER).getAmountsOut(
            _amount,
            yveCRVtoCRVPath
        );
        // calculate minimum amount received
        uint256 minAmount = (amounts[yveCRVtoCRVPath.length - 1] *
            (10000 - _slippage)) / (10000);

        // swap yveCRV fo CRV
        uint256[] memory outputs = IUniswapRouter(SUSHIROUTER)
            .swapExactTokensForTokens(
                _amount,
                minAmount,
                yveCRVtoCRVPath,
                address(this),
                block.timestamp + 1800
            );

        // event
        emit RECEIVED(CRV, address(this), outputs[yveCRVtoCRVPath.length - 1]);

        return outputs[yveCRVtoCRVPath.length - 1];
    }

    /// @notice Set new address for Stake DAO CRV Depositor
    /// @param _depositor New depositor address
    function setCRVDepositor(address _depositor) external {
        require(msg.sender == owner, "only onwer");
        require(_depositor != address(0));
        CRV_Depositor = _depositor;
    }

    /// @notice Set new address for cvxCRV/CRV pool on Curve
    /// @param _pool New pool address
    function setcvxCRVCRVPool(address _pool) external {
        require(msg.sender == owner, "only onwer");
        require(_pool != address(0));
        cvxCRVCRVPool = _pool;
    }

    /// @notice Set new path for yveCRV/CRV swap on Sushiswap
    /// @param _path New path
    function setYveCRVtoCRVPath(address[] memory _path) external {
        require(msg.sender == owner, "only onwer");
        yveCRVtoCRVPath = _path;
    }

    /// @notice Emit event when token is received
    /// @param _token Address of received token
    /// @param _receiver Address of the receiver
    /// @param _amount Amount of received token
    event RECEIVED(address _token, address _receiver, uint256 _amount);
}
