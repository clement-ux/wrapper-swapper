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
    ILV4 gaugeSDCRV = ILV4(MainnetAddresses.SDCRV_GAUGE);
    IyveCRV yveCRV = IyveCRV(MainnetAddresses.YVECRV);
    IUniswapRouter sushiRouter = IUniswapRouter(MainnetAddresses.SUSHIROUTER);

    // ERC20
    ERC20 cvxCRV = ERC20(MainnetAddresses.CVXCRV);
    ERC20 crv = ERC20(MainnetAddresses.CRV);
    ERC20 sdCRV = ERC20(MainnetAddresses.SDCRV);

    // Global Variables
    uint256 amount_1B = 1_000_000_000e18;
    uint256 amount_1M = 1_000_000e18;
    uint256 amount_1k = 1_000e18;
    uint256 amount_1 = 1e18;
    uint256 slippage = 100;

    address[] yveCRVtoCRVPath = [
        MainnetAddresses.YVECRV,
        MainnetAddresses.WETH,
        MainnetAddresses.CRV
    ];

    // ######################### Start Testing ######################### //
    /// @notice Setup the process
    function setUp() external {
        vm.prank(deployer);
        wrapperSwap = new WrapperSwap();
    }

    function test01_swapOnCurve() external {
        deal(address(cvxCRV), address(wrapperSwap), amount_1M);
        vm.startPrank(address(wrapperSwap));

        uint256 crvBefore = crv.balanceOf(address(wrapperSwap));

        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, amount_1M);
        wrapperSwap.swapOnCurve(amount_1M, slippage);

        uint256 crvAfter = crv.balanceOf(address(wrapperSwap));

        assertEq(crvAfter, crvBefore + crvEstimated);
    }

    function test02_swapOnSushi() external {
        deal(address(yveCRV), address(wrapperSwap), amount_1k);
        vm.startPrank(address(wrapperSwap));

        uint256 crvBefore = crv.balanceOf(address(wrapperSwap));
        uint256 crvEstimated = (
            sushiRouter.getAmountsOut(amount_1k, yveCRVtoCRVPath)
        )[yveCRVtoCRVPath.length - 1];

        wrapperSwap.swapOnSushi(amount_1k, slippage);

        uint256 crvAfter = crv.balanceOf(address(wrapperSwap));

        assertEq(crvAfter, crvBefore + crvEstimated);
    }

    function test11_sdCRVSwap() external {
        deal(address(cvxCRV), user1, amount_1M);
        vm.startPrank(user1);

        //Before Swap
        uint256 sdCRVBefore = sdCRV.balanceOf(user1);
        uint256 crvDepBefore = crv.balanceOf(MainnetAddresses.CRV_DEPOSITOR);

        //Swap
        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, amount_1M);
        cvxCRV.approve(address(wrapperSwap), amount_1M);
        uint256 crvSwapped = wrapperSwap.sdCRVSwap(
            address(cvxCRV),
            amount_1M,
            slippage,
            false,
            false
        );

        //After swap
        uint256 sdCRVAfter = sdCRV.balanceOf(user1);
        uint256 crvDepAfter = crv.balanceOf(MainnetAddresses.CRV_DEPOSITOR);
        uint256 realCRVAmount = crvSwapped -
            ((crvSwapped * depositor.lockIncentive()) /
                depositor.FEE_DENOMINATOR());

        //Assert
        assertEq(crvSwapped, crvEstimated);
        assertGt(crvSwapped, sdCRVBefore + sdCRVAfter); // due to depositor fees
        assertEq(sdCRVBefore + realCRVAmount, sdCRVAfter);
        assertEq(crvSwapped, crvDepBefore + crvDepAfter);
    }

    function test12_sdCRVSwapStake() external {
        deal(address(cvxCRV), user1, amount_1M);
        vm.startPrank(user1);

        //Before Swap
        uint256 sdCRVBefore = gaugeSDCRV.balanceOf(user1);
        uint256 crvDepBefore = crv.balanceOf(MainnetAddresses.CRV_DEPOSITOR);

        //Swap
        uint256 crvEstimated = cvxCRVCRVPool.get_dy(1, 0, amount_1M);
        cvxCRV.approve(address(wrapperSwap), amount_1M);
        uint256 crvSwapped = wrapperSwap.sdCRVSwap(
            address(cvxCRV),
            amount_1M,
            slippage,
            false,
            true
        );

        //After swap
        uint256 sdCRVAfter = gaugeSDCRV.balanceOf(user1);
        uint256 crvDepAfter = crv.balanceOf(MainnetAddresses.CRV_DEPOSITOR);
        uint256 realCRVAmount = crvSwapped -
            ((crvSwapped * depositor.lockIncentive()) /
                depositor.FEE_DENOMINATOR());

        //Assert
        assertEq(crvSwapped, crvEstimated);
        assertGt(crvSwapped, sdCRVBefore + sdCRVAfter); // due to depositor fees
        assertEq(sdCRVBefore + realCRVAmount, sdCRVAfter);
        assertEq(crvSwapped, crvDepBefore + crvDepAfter);
    }

    function test13_sdCRVSwapLock() external {
        // Simulate user1 swap no Lock
        deal(address(cvxCRV), user2, amount_1M);
        vm.startPrank(user2);
        cvxCRV.approve(address(wrapperSwap), amount_1M);
        wrapperSwap.sdCRVSwap(address(cvxCRV), amount_1k, 100, false, false);
        vm.stopPrank();

        deal(address(yveCRV), user1, amount_1M);
        vm.startPrank(user1);

        //Before Swap
        uint256 sdCRVBefore = sdCRV.balanceOf(user1);
        uint256 crvDepBefore = crv.balanceOf(MainnetAddresses.CRV_DEPOSITOR);
        uint256 incentive = depositor.incentiveToken();

        //Swap
        uint256 crvEstimated = (
            sushiRouter.getAmountsOut(amount_1k, yveCRVtoCRVPath)
        )[yveCRVtoCRVPath.length - 1];
        yveCRV.approve(address(wrapperSwap), amount_1k);
        uint256 crvSwapped = wrapperSwap.sdCRVSwap(
            address(yveCRV),
            amount_1k,
            slippage,
            true,
            false
        );

        //After swap
        uint256 sdCRVAfter = sdCRV.balanceOf(user1);
        uint256 crvDepAfter = crv.balanceOf(MainnetAddresses.CRV_DEPOSITOR);
        uint256 crvLockerAfter = crv.balanceOf(MainnetAddresses.CRV_LOCKER);
        uint256 realCRVAmount = crvSwapped + incentive;

        //Assert
        assertGt(incentive, 0);
        assertGt(crvDepBefore, 0);
        assertEq(crvDepAfter, 0);
        assertEq(crvLockerAfter, 0);
        assertEq(crvSwapped, crvEstimated);
        assertLt(crvSwapped, sdCRVBefore + sdCRVAfter);
        assertEq(sdCRVBefore + realCRVAmount, sdCRVAfter);
    }

    function test21_rescueERC20() external {
        deal(address(crv), address(wrapperSwap), amount_1k);
        vm.startPrank(deployer);

        uint256 crvBefore = crv.balanceOf(deployer);
        wrapperSwap.rescueERC20(address(crv), deployer);
        uint256 crvAfter = crv.balanceOf(deployer);

        assertEq(crvAfter, crvBefore + 1_000e18);
    }

    function test22_setCRVDepositor() external {
        vm.prank(user1);
        vm.expectRevert("only owner");
        wrapperSwap.setCRVDepositor(address(0));

        vm.startPrank(deployer);
        vm.expectRevert("!address(0)");
        wrapperSwap.setCRVDepositor(address(0));

        wrapperSwap.setCRVDepositor(fake1);
        address newDep = wrapperSwap.CRV_Depositor();

        assertEq(newDep, fake1);
    }

    function test23_setOwner() external {
        vm.prank(user1);
        vm.expectRevert("only owner");
        wrapperSwap.setOwner(user2);

        vm.prank(deployer);
        wrapperSwap.setOwner(user2);

        address newOwner = wrapperSwap.owner();
        assertEq(newOwner, user2);
    }

    function test24_setYveCRVtoCRVPath() external {
        address[] memory path = new address[](1);
        path[0] = address(crv);

        vm.startPrank(deployer);
        vm.expectRevert("path too short");
        wrapperSwap.setYveCRVtoCRVPath(path);

        path = new address[](2);
        path[0] = address(crv);
        path[1] = address(sdCRV);
        wrapperSwap.setYveCRVtoCRVPath(path);

        address newPath0 = wrapperSwap.yveCRVtoCRVPath(0);
        address newPath1 = wrapperSwap.yveCRVtoCRVPath(1);

        assertEq(newPath0, address(crv));
        assertEq(newPath1, address(sdCRV));
    }

    function test25_setcvxCRVCRVPool() external {
        vm.startPrank(deployer);
        vm.expectRevert("!address(0)");
        wrapperSwap.setcvxCRVCRVPool(address(0));

        wrapperSwap.setcvxCRVCRVPool(fake1);

        address newPool = wrapperSwap.cvxCRVCRVPool();

        assertEq(newPool, fake1);
    }
}
