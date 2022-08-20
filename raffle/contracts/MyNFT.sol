// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract MyNFT is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721 ("MyNFT", "MINE") {
    console.log("NFT CONTRACT MyNFT DEPLOYED");
  }

  function mintNFT() public {
    uint256 newItemId = _tokenIds.current();
    _safeMint(msg.sender, newItemId);
    _setTokenURI(newItemId, "https://jsonkeeper.com/b/RUUS");
    _tokenIds.increment();
    console.log("An NFT w/ ID %s has been minted to %s", newItemId, msg.sender);
  }
}