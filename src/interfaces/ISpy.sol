import { IERC721 } from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

interface ISpy is IERC721 {
  function gooBalance(address user) external view returns (uint256);
}