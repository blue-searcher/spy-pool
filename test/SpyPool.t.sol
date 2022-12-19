// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SpyPool.sol";

import { IERC721 } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721Holder } from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";

import { IKnifeGame } from "../src/interfaces/IKnifeGame.sol";
import { ISpy } from "../src/interfaces/ISpy.sol";

contract SpyPoolTest is Test, ERC721Holder {
    SpyPool public pool;

    //Random EOA
    address public constant USER_A = address(0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8);
    address public constant USER_B = address(0xDA9dfA130Df4dE4673b89022EE50ff26f6EA73Cf);
    address public constant USER_C = address(0x0716a17FBAeE714f1E6aB0f9d59edbC5f09815C0);

    ISpy public constant SPY_NFT = ISpy(0x265f4EbCB310bB98e76436569D014D3D55087Aa8);
    IERC721 public constant KNIFE_NFT = IERC721(0x0434Ba7f2F795C083bF1f8692acd36721cD34799);
    IKnifeGame public constant KNIFE_GAME = IKnifeGame(0x6488b54F9502e9A4B1D7BB90863012F682fe60c6);

    //TODO How to import from SpyPool.sol?
    event DepositSpy(address indexed USER_A, uint256 indexed tokenId);

    function setUp() public {
        pool = new SpyPool(
            address(this),
            address(SPY_NFT),
            address(KNIFE_NFT),
            address(KNIFE_GAME)
        );
    }

    function testUnauthorizedStop() public {
        vm.prank(USER_A);
        vm.expectRevert();
        pool.stop();
    }

    function testActive() public {
        assertEq(pool.stopped(), 0);
    }

    function testStopped() public {
        pool.stop();

        assertEq(pool.stopped(), 1);
    }

    function testReactivate() public {
        pool.stop();
        assertEq(pool.stopped(), 1);

        pool.activate();
        assertEq(pool.stopped(), 0);
    }

    function testUnauthorizedReactivate() public {
        pool.stop();
        assertEq(pool.stopped(), 1);

        vm.prank(USER_A);
        vm.expectRevert();
        pool.activate();
    }

    function testDepositSpy_NFTBalances() public {
        vm.deal(address(this), 1e18);

        uint256 spyId = KNIFE_GAME.purchaseSpy{value: 0.1e18}(address(this)); 

        uint256 preThisBalance = SPY_NFT.balanceOf(address(this)); 
        uint256 prePoolBalance = SPY_NFT.balanceOf(address(pool)); 
        uint256 preSpyThisBalance = pool.spyBalanceOf(address(this)); 

        SPY_NFT.approve(address(pool), spyId);

        vm.expectEmit(true, true, false, false);
        emit DepositSpy(address(this), spyId);
        pool.depositSpy(spyId);

        uint256 postThisBalance = SPY_NFT.balanceOf(address(this)); 
        uint256 postPoolBalance = SPY_NFT.balanceOf(address(pool)); 
        uint256 postSpyThisBalance = pool.spyBalanceOf(address(this));

        assertEq(postThisBalance, preThisBalance - 1);
        assertEq(postPoolBalance, prePoolBalance + 1);
        assertEq(postSpyThisBalance, preSpyThisBalance + 1);
    }

    function testDepositSpy_MooBalances() public {
        vm.deal(address(this), 1e18);
        vm.deal(USER_A, 1e18);

        uint256 mySpyId = KNIFE_GAME.purchaseSpy{value: 0.1e18}(address(this)); 
        vm.prank(USER_A);
        KNIFE_GAME.purchaseSpy{value: 0.1e18}(USER_A); 

        SPY_NFT.approve(address(pool), mySpyId);
        pool.depositSpy(mySpyId);

        uint256 myPoolMooBalance = pool.mooBalance(address(this));
        uint256 USER_AMooBalance = SPY_NFT.gooBalance(USER_A);

        assertEq(myPoolMooBalance, USER_AMooBalance);
    }

    function testMintSpyUsingMoo_NFTBalances() public {
        vm.deal(address(this), 1e18);

        uint256 mySpyId = KNIFE_GAME.purchaseSpy{value: 0.1e18}(address(this)); 

        SPY_NFT.approve(address(pool), mySpyId);
        pool.depositSpy(mySpyId);

        skip(60 * 60 * 24); //1 day

        uint256 preSpyThisBalance = pool.spyBalanceOf(address(this)); 

        uint256 maxSpyPrice = KNIFE_GAME.spyPrice() + 1;
        pool.mintSpyFromMoolah(maxSpyPrice);

        uint256 postSpyThisBalance = pool.spyBalanceOf(address(this)); 

        assertEq(postSpyThisBalance, preSpyThisBalance + 1);
    }

    function testMintSpy_MooBalances() public {
        vm.deal(address(this), 1e18);
        vm.deal(USER_A, 1e18);

        uint256 mySpyId = KNIFE_GAME.purchaseSpy{value: 0.1e18}(address(this)); 
        vm.prank(USER_A);
        KNIFE_GAME.purchaseSpy{value: 0.1e18}(USER_A); 

        SPY_NFT.approve(address(pool), mySpyId);
        pool.depositSpy(mySpyId);

        skip(60 * 60 * 24); //1 day

        uint256 maxSpyPrice = KNIFE_GAME.spyPrice() + 1;

        pool.mintSpyFromMoolah(maxSpyPrice);
        vm.prank(USER_A);
        KNIFE_GAME.mintSpyFromMoolah(maxSpyPrice);

        uint256 myPoolMooBalance = pool.mooBalance(address(this));
        uint256 USER_AMooBalance = SPY_NFT.gooBalance(USER_A);

        assertEq(myPoolMooBalance, USER_AMooBalance);
    }

    function _purchaseAndDeposit(address _user) internal {
        vm.deal(_user, 1e18);

        vm.startPrank(_user);

        uint256 spyId = KNIFE_GAME.purchaseSpy{value: 0.1e18}(_user); 
        SPY_NFT.approve(address(pool), spyId);
        pool.depositSpy(spyId);

        vm.stopPrank();
    }

    function _purchase(address _user) internal {
        vm.deal(_user, 1e18);

        vm.startPrank(_user);
        KNIFE_GAME.purchaseSpy{value: 0.1e18}(_user); 
        vm.stopPrank();
    }

    function testDepositSpy_MultipleUsers_MooBalances() public {
        _purchase(address(this));

        _purchaseAndDeposit(USER_A);
        _purchaseAndDeposit(USER_B);
        _purchaseAndDeposit(USER_C);

        skip(60 * 60 * 24); //1 day

        uint256 moo_this = SPY_NFT.gooBalance(address(this));

        uint256 moo_A = pool.mooBalance(USER_A);
        uint256 moo_B = pool.mooBalance(USER_B);
        uint256 moo_C = pool.mooBalance(USER_C);

        uint256 moo_pool = SPY_NFT.gooBalance(address(pool));

        uint256 totalUsersMoo = moo_A + moo_B + moo_C;

        console.log(moo_this);
        console.log(totalUsersMoo);
        console.log(moo_pool);
    }
}