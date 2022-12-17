//https://gist.github.com/knifegame/cdb09ba73d6cfe34ecc94c7c8a74a46e
interface IKnifeGame {
  function BURN_ADDRESS () external view returns ( address );
  function INITIAL_PURCHASE_SPY_ETH_PRICE () external view returns ( uint256 );
  function MULTISIG () external view returns ( address );
  function SHOUTS_FUNDS_RECIPIENT () external view returns ( address );
  function claimFreeMoo () external;
  function gameStart () external view returns ( uint256 );
  function hasUserClaimedFreeMooTokens (address) external view returns ( bool );
  function hasUserPrepurchased (address) external view returns ( bool );
  function killSpy (uint256 _knifeId, uint256 _spyId) external;
  function knifeLVRGDA () external view returns ( address );
  function knifeNFT () external view returns ( address );
  function knifePrice () external view returns ( uint256 );
  function knivesMintedFromMoo () external view returns ( uint128 );
  function mintKnifeFromMoolah (uint256 _maxPrice) external returns ( uint256 knifeId );
  function mintSpyFromMoolah (uint256 _maxPrice) external returns ( uint256 spyId );
  function purchaseSpy (address user) external payable returns ( uint256 spyId );
  function shout (string calldata message) external;
  function spiesMintedFromMoo () external view returns ( uint128 );
  function spyLVRGDA () external view returns ( address );
  function spyNFT () external view returns ( address );
  function spyPrice () external view returns ( uint256 );
  function spyPriceETH (address _user) external view returns ( uint256 );
  function userPurchasesOnDay ( address, uint256 ) external view returns ( uint256 );
}