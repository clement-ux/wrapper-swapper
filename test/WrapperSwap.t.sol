// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./helper/Constant.sol";
import "./helper/Utils.sol";
import "../src/WrapperSwap.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/Interfaces/IveCRV.sol";
import "../src/Interfaces/ILV4.sol";
import "../src/Interfaces/IyveCRV.sol";

contract cvxCRVsdCRVSwap is UtilsTest {
    // Onwn contract
    WrapperSwap public wrapperSwap;

    // Existing contract
    ICRVDepositor depositor = ICRVDepositor(MainnetAddresses.CRV_DEPOSITOR);
    IStableSwap cvxCRVCRVPool = IStableSwap(MainnetAddresses.CVXCRVCRV_POOL);
    IveCRV veCRV = IveCRV(MainnetAddresses.VECRV);
    ILV4 gaugeSDCRV = ILV4(MainnetAddresses.SDCRV_GAUGE);
    IyveCRV yveCRV = IyveCRV(MainnetAddresses.YVECRV);
    IUniswapRouter sushiRouter = IUniswapRouter(MainnetAddresses.SUSHIROUTER);

    // ERC20
    ERC20 cvxCRV = ERC20(MainnetAddresses.CVXCRV);
    ERC20 crv = ERC20(MainnetAddresses.CRV);
    ERC20 sdcrv = ERC20(MainnetAddresses.SDCRV);

    // Contructor Arguments
    address[] yveCRVtoCRVPath = [
        MainnetAddresses.YVECRV,
        MainnetAddresses.WETH,
        MainnetAddresses.CRV
    ];

    // Global Variables
    uint256 amount_1B = 1_000_000_000 * (10e18);
    uint256 amount_1M = 1_000_000 * (10e18);
    uint256 amount_1k = 1_000 * (10e18);
    uint256 amount_1 = 1 * (10e18);
    uint256 slippage = 100;

    // ######################### Start Testing ######################### //
    /// @notice Setup the process
    function setUp() external {
        wrapperSwap = new WrapperSwap(yveCRVtoCRVPath);
    }

    // ---------------------------- Convex ---------------------------- //
    /// @notice Swap cvxCRV into sdCRV without locking without stacking
    function test01_cvxCRVsdCRV_SwapNoLockNoStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Give user1 1M cvxCRV
        //uint256 _amount = amount_1M;
        deal(address(cvxCRV), user1, _amount);

        // Impersonate account
        vm.startPrank(user1);

        // States Variables Before
        uint256 crvDepositorBalanceBefore = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedBefore = wrapperSwap.total_cvxCRVsdCRV();

        // Start process
        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, _amount);
        cvxCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.cvxCRVsdCRVSwap(
            _amount,
            100,
            false,
            false
        );

        // States Variables After
        uint256 balance_sdcrv = sdcrv.balanceOf(user1);
        uint256 crvDepositorBalanceAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedAfter = wrapperSwap.total_cvxCRVsdCRV();

        // Verification
        uint256 realCRVAmount = crvSwapped -
            ((crvSwapped * depositor.lockIncentive()) /
                depositor.FEE_DENOMINATOR());

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t", realCRVAmount);
        //console.log("balance_sdcrv\t", balance_sdcrv);

        assert(balance_sdcrv > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrv);
        assert(balance_sdcrv < crvSwapped);
        assert(
            (crvDepositorBalanceAfter - crvDepositorBalanceBefore) == crvSwapped
        );
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    /// @notice Swap cvxCRV into sdCRV without locking with stacking
    function test02_cvxCRVsdCRV_SwapNoLockStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Give user1 1M cvxCRV
        deal(address(cvxCRV), user1, _amount);

        // Impersonate account
        vm.startPrank(user1);

        // States Variables Before
        uint256 crvDepositorBalanceBefore = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedBefore = wrapperSwap.total_cvxCRVsdCRV();

        // Start process
        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, _amount);
        cvxCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.cvxCRVsdCRVSwap(
            _amount,
            100,
            false,
            true
        );

        // States Variables After
        uint256 balance_sdcrvGauge = gaugeSDCRV.balanceOf(user1); //sdcrv.balanceOf(user1);
        uint256 crvDepositorBalanceAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedAfter = wrapperSwap.total_cvxCRVsdCRV();

        // Verification
        uint256 realCRVAmount = crvSwapped -
            ((crvSwapped * depositor.lockIncentive()) /
                depositor.FEE_DENOMINATOR());

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t\t", realCRVAmount);
        //console.log("balance_sdcrvGauge\t", balance_sdcrvGauge);

        assert(balance_sdcrvGauge > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrvGauge);
        assert(balance_sdcrvGauge < crvSwapped);
        assert(
            (crvDepositorBalanceAfter - crvDepositorBalanceBefore) == crvSwapped
        );
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    /// @notice Swap cvxCRV into sdCRV with locking without stacking
    function test03_cvxCRVsdCRV_SwapLockNoStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Simulate user1 swap no Lock
        deal(address(cvxCRV), user1, _amount);
        vm.startPrank(user1);
        cvxCRV.approve(address(wrapperSwap), _amount);
        wrapperSwap.cvxCRVsdCRVSwap(_amount, 100, false, false);
        vm.stopPrank();

        // Give user1 1M cvxCRV
        deal(address(cvxCRV), user2, _amount);

        // Impersonate account
        vm.startPrank(user2);

        // State Variable Before
        uint256 totalSwappedBefore = wrapperSwap.total_cvxCRVsdCRV();

        // Start process
        uint256 incentive = depositor.incentiveToken();
        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, _amount);
        cvxCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.cvxCRVsdCRVSwap(
            _amount,
            100,
            true,
            false
        );

        // State Variables After
        uint256 crvDepositorAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 crvLockerAfter = crv.balanceOf(MainnetAddresses.CRV_LOCKER);
        uint256 totalSwappedAfter = wrapperSwap.total_cvxCRVsdCRV();

        // Verification
        uint256 balance_sdcrv = sdcrv.balanceOf(user2);

        uint256 realCRVAmount = crvSwapped + incentive;

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t", realCRVAmount);
        //console.log("balance_sdcrv\t", balance_sdcrv);

        assert(incentive > 0);
        assert(balance_sdcrv > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrv);
        assert(balance_sdcrv > crvSwapped);
        assert(crvDepositorAfter == 0);
        assert(crvLockerAfter == 0);
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    /// @notice Swap cvxCRV into sdCRV with locking without stacking
    function test04_cvxCRVsdCRV_SwapLockStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Simulate user1 swap no Lock
        deal(address(cvxCRV), user1, _amount);
        vm.startPrank(user1);
        cvxCRV.approve(address(wrapperSwap), _amount);
        wrapperSwap.cvxCRVsdCRVSwap(_amount, 100, false, false);
        vm.stopPrank();

        // Give user1 1M cvxCRV
        deal(address(cvxCRV), user2, _amount);

        // Impersonate account
        vm.startPrank(user2);

        // State Variable Before
        uint256 totalSwappedBefore = wrapperSwap.total_cvxCRVsdCRV();

        // Start process
        uint256 incentive = depositor.incentiveToken();
        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, _amount);
        cvxCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.cvxCRVsdCRVSwap(
            _amount,
            100,
            true,
            true
        );

        // State Variables After
        uint256 crvDepositorAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 crvLockerAfter = crv.balanceOf(MainnetAddresses.CRV_LOCKER);
        uint256 totalSwappedAfter = wrapperSwap.total_cvxCRVsdCRV();

        // Verification
        uint256 balance_sdcrvGauge = gaugeSDCRV.balanceOf(user2);
        uint256 realCRVAmount = crvSwapped + incentive;

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t", realCRVAmount);
        //console.log("balance_sdcrvGauge\t", balance_sdcrvGauge);

        assert(incentive > 0);
        assert(balance_sdcrvGauge > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrvGauge);
        assert(balance_sdcrvGauge > crvSwapped);
        assert(crvDepositorAfter == 0);
        assert(crvLockerAfter == 0);
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    // ---------------------------- Yearn ---------------------------- //
    /// @notice Swap yveCRV into sdCRV without locking without stacking
    function test05_yveCRVsdCRV_SwapNoLockNoStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Give user1 1M cvxCRV
        deal(address(yveCRV), user1, _amount);
        vm.startPrank(user1);

        // States Variables Before
        uint256 crvDepositorBalanceBefore = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedBefore = wrapperSwap.total_yveCRVsdCRV();

        // Process
        uint256 crvEstimated = (
            sushiRouter.getAmountsOut(_amount, yveCRVtoCRVPath)
        )[yveCRVtoCRVPath.length - 1];
        yveCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.yveCRVsdCRVSwap(
            _amount,
            slippage,
            false,
            false
        );

        // States Variables After
        uint256 balance_sdcrv = sdcrv.balanceOf(user1);
        uint256 crvDepositorBalanceAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedAfter = wrapperSwap.total_yveCRVsdCRV();

        // Verification
        uint256 realCRVAmount = crvSwapped -
            ((crvSwapped * depositor.lockIncentive()) /
                depositor.FEE_DENOMINATOR());

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t", realCRVAmount);
        //console.log("balance_sdcrv\t", balance_sdcrv);

        assert(balance_sdcrv > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrv);
        assert(balance_sdcrv < crvSwapped);
        assert(
            (crvDepositorBalanceAfter - crvDepositorBalanceBefore) == crvSwapped
        );
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    /// @notice Swap yveCRV into sdCRV without locking with stacking
    function test06_yveCRVsdCRV_SwapNoLockStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Give user1 1M cvxCRV
        deal(address(yveCRV), user1, _amount);

        // Impersonate account
        vm.startPrank(user1);

        // States Variables Before
        uint256 crvDepositorBalanceBefore = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedBefore = wrapperSwap.total_yveCRVsdCRV();

        // Start process
        uint256 crvEstimated = (
            sushiRouter.getAmountsOut(_amount, yveCRVtoCRVPath)
        )[yveCRVtoCRVPath.length - 1];
        yveCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.yveCRVsdCRVSwap(
            _amount,
            slippage,
            false,
            true
        );

        // States Variables After
        uint256 balance_sdcrvGauge = gaugeSDCRV.balanceOf(user1); //sdcrv.balanceOf(user1);
        uint256 crvDepositorBalanceAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 totalSwappedAfter = wrapperSwap.total_yveCRVsdCRV();

        // Verification
        uint256 realCRVAmount = crvSwapped -
            ((crvSwapped * depositor.lockIncentive()) /
                depositor.FEE_DENOMINATOR());

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t\t", realCRVAmount);
        //console.log("balance_sdcrvGauge\t", balance_sdcrvGauge);

        assert(balance_sdcrvGauge > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrvGauge);
        assert(balance_sdcrvGauge < crvSwapped);
        assert(
            (crvDepositorBalanceAfter - crvDepositorBalanceBefore) == crvSwapped
        );
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    /// @notice Swap cvxCRV into sdCRV with locking without stacking
    function test07_yveCRVsdCRV_SwapLockNoStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Simulate user1 swap no Lock
        deal(address(cvxCRV), user1, _amount);
        vm.startPrank(user1);
        cvxCRV.approve(address(wrapperSwap), _amount);
        wrapperSwap.cvxCRVsdCRVSwap(_amount, 100, false, false);
        vm.stopPrank();

        // Give user1 1M cvxCRV
        deal(address(yveCRV), user2, _amount);

        // Impersonate account
        vm.startPrank(user2);

        // State Variable Before
        uint256 totalSwappedBefore = wrapperSwap.total_yveCRVsdCRV();

        // Start process
        uint256 incentive = depositor.incentiveToken();
        uint256 crvEstimated = (
            sushiRouter.getAmountsOut(_amount, yveCRVtoCRVPath)
        )[yveCRVtoCRVPath.length - 1];
        yveCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.yveCRVsdCRVSwap(
            _amount,
            slippage,
            true,
            false
        );

        // State Variables After
        uint256 crvDepositorAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 crvLockerAfter = crv.balanceOf(MainnetAddresses.CRV_LOCKER);
        uint256 totalSwappedAfter = wrapperSwap.total_yveCRVsdCRV();

        // Verification
        uint256 balance_sdcrv = sdcrv.balanceOf(user2);

        uint256 realCRVAmount = crvSwapped + incentive;

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t", realCRVAmount);
        //console.log("balance_sdcrv\t", balance_sdcrv);

        assert(incentive > 0);
        assert(balance_sdcrv > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrv);
        assert(balance_sdcrv > crvSwapped);
        assert(crvDepositorAfter == 0);
        assert(crvLockerAfter == 0);
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }

    /// @notice Swap cvxCRV into sdCRV with locking with stacking
    function test08_yveCRVsdCRV_SwapLockStack(uint256 _amount) external {
        // Fuzz Test
        vm.assume(_amount > amount_1);
        vm.assume(_amount < amount_1M);
        //_amount = amount_1M;

        // Simulate user1 swap no Lock
        deal(address(cvxCRV), user1, _amount);
        vm.startPrank(user1);
        cvxCRV.approve(address(wrapperSwap), _amount);
        wrapperSwap.cvxCRVsdCRVSwap(_amount, 100, false, false);
        vm.stopPrank();

        // Give user1 1M cvxCRV
        deal(address(yveCRV), user2, _amount);

        // Impersonate account
        vm.startPrank(user2);

        // State Variable Before
        uint256 totalSwappedBefore = wrapperSwap.total_yveCRVsdCRV();

        // Start process
        uint256 incentive = depositor.incentiveToken();
        uint256 crvEstimated = (
            sushiRouter.getAmountsOut(_amount, yveCRVtoCRVPath)
        )[yveCRVtoCRVPath.length - 1];
        yveCRV.approve(address(wrapperSwap), _amount);
        uint256 crvSwapped = wrapperSwap.yveCRVsdCRVSwap(
            _amount,
            slippage,
            true,
            true
        );

        // State Variables After
        uint256 crvDepositorAfter = crv.balanceOf(
            MainnetAddresses.CRV_DEPOSITOR
        );
        uint256 crvLockerAfter = crv.balanceOf(MainnetAddresses.CRV_LOCKER);
        uint256 totalSwappedAfter = wrapperSwap.total_yveCRVsdCRV();

        // Verification
        uint256 balance_sdcrvGauge = gaugeSDCRV.balanceOf(user2);

        uint256 realCRVAmount = crvSwapped + incentive;

        //console.log("crvSwapped\t", crvSwapped);
        //console.log("realCRVAmount\t", realCRVAmount);
        //console.log("balance_sdcrvGauge\t", balance_sdcrvGauge);

        assert(incentive > 0);
        assert(balance_sdcrvGauge > 0);
        assert(crvSwapped >= crvEstimated);
        assert(realCRVAmount == balance_sdcrvGauge);
        assert(balance_sdcrvGauge > crvSwapped);
        assert(crvDepositorAfter == 0);
        assert(crvLockerAfter == 0);
        assert((totalSwappedAfter - totalSwappedBefore) == crvSwapped);
    }
}
