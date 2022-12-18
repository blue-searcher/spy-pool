// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SpyPool.sol";
import "forge-std/console.sol";

import { IERC721 } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import { IKnifeGame } from "../src/interfaces/IKnifeGame.sol";
import { ISpy } from "../src/interfaces/ISpy.sol";

contract SpyPoolTest is Test {
    SpyPool public pool;

    ISpy public constant SPY_NFT = ISpy(0x265f4EbCB310bB98e76436569D014D3D55087Aa8);
    IERC721 public constant KNIFE_NFT = IERC721(0x0434Ba7f2F795C083bF1f8692acd36721cD34799);
    IKnifeGame public constant KNIFE_GAME = IKnifeGame(0x0434Ba7f2F795C083bF1f8692acd36721cD34799);

    function setUp() public {
        pool = new SpyPool(
            address(this),
            address(SPY_NFT),
            address(KNIFE_NFT),
            address(KNIFE_GAME)
        );
    }

    function testUnauthorizedStop() public {
        SpyPool another_pool = new SpyPool(
            address(0),
            address(SPY_NFT),
            address(KNIFE_NFT),
            address(KNIFE_GAME)
        );

        vm.expectRevert();
        another_pool.stop();
    }

    function testActive() public {
        assertEq(pool.stopped(), 0);
    }

    function testStopped() public {
        pool.stop();

        assertEq(pool.stopped(), 1);
    }

    function testDepositSpy() public {
        //It reverts
        vm.deal(address(this), 1e18);

        KNIFE_GAME.purchaseSpy{value: 100000000000000000}(address(this)); //0.1 eth

        assertEq(SPY_NFT.balanceOf(address(this)), 1);

        //...
    }
}
