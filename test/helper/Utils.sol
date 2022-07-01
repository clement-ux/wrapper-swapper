// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/console.sol";


abstract contract UtilsTest is Test {
    address user = address(this);
    address user1 = address(0xCAFE);
    address user2 = address(0xBEEF);
    address user3 = address(0xCACA0);
}