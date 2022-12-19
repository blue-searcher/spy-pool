// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC721 } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721Holder } from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { toDaysWadUnsafe } from "solmate/utils/SignedWadMath.sol";

import { LibGOO } from "goo-issuance/LibGOO.sol";

import { IKnifeGame } from "./interfaces/IKnifeGame.sol";
import { ISpy } from "./interfaces/ISpy.sol";

import "forge-std/console.sol";

contract SpyPool is ERC721Holder {
    using FixedPointMathLib for uint256;

    address public owner;
    uint256 public stopped;

    ISpy public immutable SPY_NFT;
    IERC721 public immutable KNIFE_NFT;
    IKnifeGame public immutable KNIFE_GAME;

    mapping(address => ISpy.UserData) public getUserData;

    mapping(address => uint256) internal spyBalances;
    mapping(uint256 => address) public spyOwners;

    mapping(uint256 => address) public knifeOwners;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyIfActive() {
        require(stopped == 0);
        _;
    }

    //TODO Everyone can use the whole moo balance in multiple txs, fix it
    //TODO Check everywhere if spy has been killed, spyBalances and spyOwners non updated in this case

    constructor(
        address _owner, 
        address _spyAddress,
        address _knifeAddress,
        address _knifeGameAddress
    ) {
        owner = _owner; //TODO Review owner abilities, will probably pass a multisig

        SPY_NFT = ISpy(_spyAddress);
        KNIFE_NFT = IERC721(_knifeAddress);
        KNIFE_GAME = IKnifeGame(_knifeGameAddress);
    }



    /* EVENTS */

    event DepositSpy(address indexed user, uint256 indexed tokenId);
    event DepositKnife(address indexed user, uint256 indexed tokenId);

    event WithdrawSpy(address indexed user, uint256 indexed tokenId);
    event WithdrawKnife(address indexed user, uint256 indexed tokenId);



    /* ADMIN FUNCTIONS */

    //TODO Add migratePool() ... just in case
    //TODO Add distributeReward() NOTE: Based on score points not on spies count

    function stop() external onlyOwner {
        stopped = 1;
    }

    function activate() external onlyOwner {
        stopped = 0;
    }


    /* DEPOSITS */

    //require approve() first
    //TODO array of uint256 param?
    function depositSpy(uint256 _tokenId) external onlyIfActive {
        SPY_NFT.transferFrom(msg.sender, address(this), _tokenId);

        try this.mooBalance(msg.sender) returns (uint256 existingMooBal) {
            getUserData[msg.sender].lastBalance = uint128(existingMooBal);
        } catch {}
        getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);
        
        spyBalances[msg.sender] += 1;
        spyOwners[_tokenId] = msg.sender;

        emit DepositSpy(msg.sender, _tokenId);
    }

    //require approve() first
    //TODO array of uint256 param?
    function depositKnife(uint256 _tokenId) external onlyIfActive {
        KNIFE_NFT.transferFrom(msg.sender, address(this), _tokenId);

        getUserData[msg.sender].lastBalance = uint128(mooBalance(msg.sender));
        getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);

        knifeOwners[_tokenId] = msg.sender;

        emit DepositKnife(msg.sender, _tokenId);
    }


    /* VIEW FUNCTIONS */

    function spyBalanceOf(address _user) public view returns (uint256 balance) {
        //TODO Manage killed spies here, maybe not a view method
        balance = spyBalances[_user];
    }

    function mooBalance(address _user) public view returns (uint256) {
        return LibGOO.computeGOOBalance(
            SPY_NFT.EMISSION_MULTIPLE() * spyBalanceOf(_user),
            getUserData[_user].lastBalance,
            uint256(toDaysWadUnsafe(block.timestamp - getUserData[_user].lastTimestamp))
        );
    }


    /* INTERNAL FUNCTIONS */

    function updateUserMooBalance(address user, uint256 gooAmount, ISpy.GooBalanceUpdateType updateType) internal {
        uint256 updatedBalance = updateType == ISpy.GooBalanceUpdateType.INCREASE 
                                ? mooBalance(user) + gooAmount 
                                : mooBalance(user) - gooAmount;

        getUserData[user].lastBalance = uint128(updatedBalance);
        getUserData[user].lastTimestamp = uint64(block.timestamp);
    }



    /* MINT / PURCHASE FUNCTIONS */

    function mintSpyFromMoolah(uint256 _maxPrice) external onlyIfActive returns (uint256 spyId) {
        updateUserMooBalance(
            msg.sender,
            KNIFE_GAME.spyPrice(),
            ISpy.GooBalanceUpdateType.DECREASE
        );

        //TODO Review checks here, very important
        if (mooBalance(msg.sender) < _maxPrice) revert NotEnoughtMooBalance();

        spyId = KNIFE_GAME.mintSpyFromMoolah(_maxPrice);

        spyBalances[msg.sender] += 1;
        spyOwners[spyId] = msg.sender;
    }

    function mintKnifeFromMoolah(uint256 _maxPrice) public onlyIfActive returns (uint256 knifeId) {
        updateUserMooBalance(
            msg.sender,
            KNIFE_GAME.knifePrice(),
            ISpy.GooBalanceUpdateType.DECREASE
        );

        //TODO Review checks here, very important
        if (mooBalance(msg.sender) < _maxPrice) revert NotEnoughtMooBalance();

        knifeId = KNIFE_GAME.mintKnifeFromMoolah(_maxPrice);

        knifeOwners[knifeId] = msg.sender;
    }

    function purchaseSpy() external payable onlyIfActive returns (uint256 spyId) {
        spyId = KNIFE_GAME.purchaseSpy{value: msg.value}(msg.sender);

        spyBalances[msg.sender] += 1;
        spyOwners[spyId] = msg.sender;

        getUserData[msg.sender].lastBalance = uint128(mooBalance(msg.sender));
        getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);
    }



    /* ATTACK FUNCTION */

    //NOTE: It reverts if _spyId is owned by the pool itself
    function killSpy(uint256 _knifeId, uint256 _spyId) public onlyIfActive {
        if (knifeOwners[_knifeId] != msg.sender) revert NotOwner();

        KNIFE_GAME.killSpy(_knifeId, _spyId);

        knifeOwners[_knifeId] = address(0);

        //TODO Not sure if needed
        getUserData[msg.sender].lastBalance = uint128(mooBalance(msg.sender));
        getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);
    }



    /* WITHDRAW FUNCTIONS */

    function withdrawSpy(uint256 _tokenId) external onlyIfActive {
        //TODO Review checks here, very important
        if (spyOwners[_tokenId] != msg.sender) revert NotOwner();

        SPY_NFT.transferFrom(address(this), msg.sender, _tokenId);

        spyBalances[msg.sender] -= 1;
        spyOwners[_tokenId] = address(0);

        getUserData[msg.sender].lastBalance = uint128(mooBalance(msg.sender));
        getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);

        emit WithdrawSpy(msg.sender, _tokenId);
    }

    function withdrawKnife(uint256 _tokenId) external onlyIfActive {
        //TODO Review checks here, very important
        if (knifeOwners[_tokenId] != msg.sender) revert NotOwner();

        KNIFE_NFT.transferFrom(address(this), msg.sender, _tokenId);

        knifeOwners[_tokenId] = address(0);

        getUserData[msg.sender].lastBalance = uint128(mooBalance(msg.sender));
        getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);

        emit WithdrawKnife(msg.sender, _tokenId);
    }



    /* UTILS FUNCTIONS */

    //avoid double tx
    function mintKnifeAndKillSpy(uint256 _maxPrice, uint256 _spyId) external onlyIfActive returns (uint256 knifeId) {
        knifeId = mintKnifeFromMoolah(_maxPrice);
        killSpy(knifeId, _spyId);
    }

    //TODO Add multiMintSpyFromMoolah
    //TODO Add multiMintKnifeAndKillSpy
    //TODO Add multiDepositSpy
    //TODO Add multiDepositKnife
    //TODO Add multiWithdrawSpy
    //TODO Add multiWithdrawKnife

    /* ERRORS */

    error NotEnoughtMooBalance();
    error NotOwner();
}