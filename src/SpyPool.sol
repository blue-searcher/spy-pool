// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC721 } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721Holder } from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IKnifeGame } from "./interfaces/IKnifeGame.sol";
import { ISpy } from "./interfaces/ISpy.sol";


contract SpyPool is ERC721Holder {
    using FixedPointMathLib for uint256;

    address public owner;
    uint256 public stopped;

    ISpy public immutable SPY_NFT;
    IERC721 public immutable KNIFE_NFT;
    IKnifeGame public immutable KNIFE_GAME;

    mapping(address => uint256) public spyBalances;
    mapping(uint256 => address) public spyOwners;

    mapping(uint256 => address) public knifeOwners;

    mapping(address => uint256) public mooSpent;

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



    /* DEPOSITS */

    //require approve() first
    //TODO array of uint256 param?
    function depositSpy(uint256 _tokenId) external onlyIfActive {
        SPY_NFT.transferFrom(msg.sender, address(this), _tokenId);

        spyBalances[msg.sender] += 1;
        spyOwners[_tokenId] = msg.sender;

        emit DepositSpy(msg.sender, _tokenId);
    }

    //require approve() first
    //TODO array of uint256 param?
    function depositKnife(uint256 _tokenId) external onlyIfActive {
        KNIFE_NFT.transferFrom(msg.sender, address(this), _tokenId);

        knifeOwners[_tokenId] = msg.sender;

        emit DepositKnife(msg.sender, _tokenId);
    }



    /* VIEW FUNCTIONS */

    function mooBalance(address _user) public view returns (uint256 _mooBalance) {
        uint256 totalMooBalance = SPY_NFT.gooBalance(address(this));
        uint256 totalSpies = SPY_NFT.balanceOf(address(this));

        _mooBalance = totalMooBalance * spyBalances[_user] / totalSpies;

        if (mooSpent[_user] > _mooBalance) {
            _mooBalance = 0;   
        }
    }



    /* MINT / PURCHASE FUNCTIONS */

    function mintSpyFromMoolah(uint256 _maxPrice) external onlyIfActive returns (uint256 spyId) {
        //TODO Review checks here, very important
        if (mooBalance(msg.sender) < _maxPrice) revert NotEnoughtMooBalance();

        mooSpent[msg.sender] += KNIFE_GAME.spyPrice();

        spyId = KNIFE_GAME.mintSpyFromMoolah(_maxPrice);

        spyBalances[msg.sender] += 1;
        spyOwners[spyId] = msg.sender;
    }

    function mintKnifeFromMoolah(uint256 _maxPrice) public onlyIfActive returns (uint256 knifeId) {
        //TODO Review checks here, very important
        if (mooBalance(msg.sender) < _maxPrice) revert NotEnoughtMooBalance();

        mooSpent[msg.sender] += KNIFE_GAME.knifePrice();

        knifeId = KNIFE_GAME.mintKnifeFromMoolah(_maxPrice);

        knifeOwners[knifeId] = msg.sender;
    }

    function purchaseSpy() external payable onlyIfActive returns (uint256 spyId) {
        spyId = KNIFE_GAME.purchaseSpy{value: msg.value}(msg.sender);

        spyBalances[msg.sender] += 1;
        spyOwners[spyId] = msg.sender;
    }



    /* ATTACK FUNCTION */

    //NOTE: It reverts if _spyId is owned by the pool itself
    function killSpy(uint256 _knifeId, uint256 _spyId) public onlyIfActive {
        if (knifeOwners[_knifeId] != msg.sender) revert NotOwner();

        KNIFE_GAME.killSpy(_knifeId, _spyId);

        knifeOwners[_knifeId] = address(0);
    }



    /* WITHDRAW FUNCTIONS */

    function withdrawSpy(uint256 _tokenId) external onlyIfActive {
        //TODO Review checks here, very important
        if (spyOwners[_tokenId] != msg.sender) revert NotOwner();

        SPY_NFT.transferFrom(address(this), msg.sender, _tokenId);

        spyBalances[msg.sender] -= 1;
        spyOwners[_tokenId] = address(0);

        emit WithdrawSpy(msg.sender, _tokenId);
    }

    function withdrawKnife(uint256 _tokenId) external onlyIfActive {
        //TODO Review checks here, very important
        if (knifeOwners[_tokenId] != msg.sender) revert NotOwner();

        KNIFE_NFT.transferFrom(address(this), msg.sender, _tokenId);

        knifeOwners[_tokenId] = address(0);

        emit WithdrawKnife(msg.sender, _tokenId);
    }



    /* UTILS FUNCTIONS */

    //avoid double tx
    function mintKnifeAndKillSpy(uint256 _maxPrice, uint256 _spyId) external onlyIfActive returns (uint256 knifeId) {
        knifeId = mintKnifeFromMoolah(_maxPrice);
        killSpy(knifeId, _spyId);
    }


    /* ERRORS */

    error NotEnoughtMooBalance();
    error NotOwner();
}
