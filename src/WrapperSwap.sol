// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Interfaces/IStableSwap.sol";
import "./Interfaces/ICRVDepositor.sol";
import "./Interfaces/IUniswapRouter.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract WrapperSwap {
    uint256 public constant DENOMINATOR = 10000;

    address public constant WETH =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

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
    address[] public yveCRVtoCRVPath = [YVECRV, WETH, CRV];

    // governance
    address public owner;

    constructor() {
        owner = msg.sender;
        IERC20(CRV).approve(CRV_Depositor, type(uint256).max);
        IERC20(CVXCRV).approve(cvxCRVCRVPool, type(uint256).max);
        IERC20(YVECRV).approve(SUSHIROUTER, type(uint256).max);
    }

    /// @notice Swap cvxCRV into sdCRV
    /// @param _token Token to swap into crv (only cvxCRV or yveCRV)
    /// @param _amount Amount of xxxCRV to convert
    /// @param _slippage Max slippage (100 -> 1%)
    /// @param _lock If user want to lock all waiting CRV on locker
    /// @param _stake If user want to stake sdCRV into the gauge
    /// @return _crvSwapped Amount of CRV obtain from xxxCRV swap
    function sdCRVSwap(
        address _token,
        uint256 _amount,
        uint256 _slippage,
        bool _lock,
        bool _stake
    ) external returns (uint256 _crvSwapped) {
        require(_token == CVXCRV || _token == YVECRV, "only cvxCRV or yveCRV!");

        // get xxxCRV from user
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        uint256 _crvAmount;

        // Swap on Curve or on Sushi
        if (_token == CVXCRV) {
            _crvAmount = _swapOnCurve(_amount, _slippage);
        }
        if (_token == YVECRV) {
            _crvAmount = _swapOnSushi(_amount, _slippage);
        }

        // Use depositor
        ICRVDepositor(CRV_Depositor).deposit(
            _crvAmount,
            _lock,
            _stake,
            msg.sender
        );

        emit SEND_DEPOSITOR(_token, CRV, CRV_Depositor, _amount);
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

        return outputs[yveCRVtoCRVPath.length - 1];
    }

    // ---- Only Governance ---- //

    function setOwner(address _owner) external {
        require(msg.sender == owner, "only owner");
        owner = _owner;
    }

    /// @notice Set new address for Stake DAO CRV Depositor
    /// @param _depositor New depositor address
    function setCRVDepositor(address _depositor) external {
        require(msg.sender == owner, "only owner");
        require(_depositor != address(0), "!address(0)");
        CRV_Depositor = _depositor;
    }

    /// @notice Set new address for cvxCRV/CRV pool on Curve
    /// @param _pool New pool address
    function setcvxCRVCRVPool(address _pool) external {
        require(msg.sender == owner, "only onwer");
        require(_pool != address(0), "!address(0)");
        cvxCRVCRVPool = _pool;
    }

    /// @notice Set new path for yveCRV/CRV swap on Sushiswap
    /// @param _path New path
    function setYveCRVtoCRVPath(address[] memory _path) external {
        require(msg.sender == owner, "only onwer");
        require(_path.length >= 2, "path too short");
        yveCRVtoCRVPath = _path;
    }

    /// @notice Rescue ERC20 lost on this contract
    /// @param _token Address of the ERC20 token to rescue
    /// @param _to Address to send the rescued ERC20
    function rescueERC20(address _token, address _to) external {
        require(msg.sender == owner, "only onwer");
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, bal);
        emit RESCUE_ERC20(_token, _to);
    }

    // ---- Events ---- //
    event SEND_DEPOSITOR(
        address _fromToken,
        address _token,
        address _depositor,
        uint256 _amount
    );
    event RESCUE_ERC20(address _token, address _to);

    // --------- Only Test ---------- //
    /// @notice This function is only for testing, because _swapOnCurve is internal
    function swapOnCurve(uint256 _amount, uint256 _slippage)
        external
        returns (uint256 _output)
    {
        require(msg.sender == address(this));
        uint256 output = _swapOnCurve(_amount, _slippage);
        return (output);
    }

    /// @notice This function is only for testing, because _swapOnSushi is internal
    function swapOnSushi(uint256 _amount, uint256 _slippage)
        external
        returns (uint256 _output)
    {
        require(msg.sender == address(this));
        uint256 output = _swapOnSushi(_amount, _slippage);
        return (output);
    }
}
