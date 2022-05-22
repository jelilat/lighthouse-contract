// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721 {

    uint256 public tokenCounter;
    mapping (uint256 => string) private _tokenURIs;
    string[] gameAssets;


    constructor() ERC721("Lighthouse Game", "LTG") {
        tokenCounter = 0;
        gameAssets = ["sword", "spear", "gun", "grenade", "shield"];
    }

    function mint() public {
        _safeMint(msg.sender, tokenCounter);
        string memory baseUri = "https://gateway.pinata.cloud/ipfs/QmatRrRhyAv72ymAoA55Ym5tHmba3HMJuC7icjziZuDCMU";
        bytes memory tokenUri = abi.encodePacked(baseUri, "/", gameAssets[tokenCounter], ".json");
        _setTokenURI(tokenCounter, string(tokenUri));

        tokenCounter++;

    }

    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal virtual {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI set of nonexistent token"
        );  
        _tokenURIs[_tokenId] = _tokenURI;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns(string memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI set of nonexistent token"
        );
        return _tokenURIs[_tokenId];
    }
}
