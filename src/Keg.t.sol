// Keg.t.sol

// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>

pragma solidity ^0.6.11;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "lib/dss-interfaces/src/Interfaces.sol";
import {DaiJoin} from "dss/join.sol";
import {Dai} from "dss/dai.sol";

import "./Keg.sol";
import "./Tap.sol";
import "./FlapTap.sol";

contract Wallet {
    constructor() public {}
}

contract KegTest is DSTest, DSMath {

    address me;
    KegAbstract keg;
    DaiAbstract dai;

    Wallet wallet1;
    Wallet wallet2;

    function setUp() public {
        me = address(this);

        dai = DaiAbstract(address(new Dai(0)));
        keg = KegAbstract(address(new Keg(address(dai))));

        wallet1 = new Wallet();
        wallet2 = new Wallet();
    }

    function test_keg_deploy() public {
        assertEq(keg.wards(me),  1);
    }

    function test_seat() public {
        address[] memory wallets = new address[](2);
        wallets[0] = address(wallet1);
        wallets[1] = address(wallet2);
        uint256[] memory amts = new uint256[](2);
        amts[0] = 0.25 ether;   // 25% split
        amts[1] = 0.75 ether;   // 75% split

        keg.seat(wallets, amts);
        (address mug1, uint256 share1) = keg.flight(0);
        (address mug2, uint256 share2) = keg.flight(1);
        assertEq(mug1, address(wallet1));
        assertEq(share1, 0.25 ether);
        assertEq(mug2, address(wallet2));
        assertEq(share2, 0.75 ether);
    }

    function testFail_seat_bad_shares() public {
        address[] memory wallets = new address[](2);
        wallets[0] = address(wallet1);
        wallets[1] = address(wallet2);
        uint256[] memory amts = new uint256[](2);
        amts[0] = 0.25 ether + 1;   // 25% split + 1 wei
        amts[1] = 0.75 ether;       // 75% split
        keg.seat(wallets, amts);
    }

    function testFail_seat_unequal_length() public {
        address[] memory wallets = new address[](2);
        wallets[0] = address(wallet1);
        wallets[1] = address(wallet2);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1 ether;

        keg.seat(wallets, amts);
    }

    function testFail_seat_zero_length() public {
        address[] memory wallets = new address[](0);
        uint256[] memory amts = new uint256[](0);
        keg.seat(wallets, amts);
    }

    function testFail_seat_zero_address() public {
        address[] memory wallets = new address[](2);
        wallets[0] = address(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1 ether;
        keg.seat(wallets, amts);
    }

    function test_pour_flight() public {
        address[] memory wallets = new address[](2);
        wallets[0] = address(wallet1);
        wallets[1] = address(wallet2);
        uint256[] memory amts = new uint256[](2);
        amts[0] = 0.3 ether;   // 30% split
        amts[1] = 0.7 ether;   // 70% split

        keg.seat(wallets, amts);
        dai.mint(address(keg), 10 * WAD);
        
        keg.pour();
        assertEq(dai.balanceOf(address(wallet1)), 3 * WAD);
        assertEq(dai.balanceOf(address(wallet2)), 7 * WAD);
    }

    function testFail_pour_flight_zero() public {
        address[] memory wallets = new address[](2);
        wallets[0] = address(wallet1);
        wallets[1] = address(wallet2);
        uint256[] memory amts = new uint256[](2);
        amts[0] = 0.25 ether;   // 25% split
        amts[1] = 0.75 ether;   // 75% split

        keg.seat(wallets, amts);
        keg.pour();
    }
}