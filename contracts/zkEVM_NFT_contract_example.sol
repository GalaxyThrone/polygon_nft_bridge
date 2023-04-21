// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IBridgeMessageReceiver {
    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable;
}

contract GalaxyBridge is ERC721URIStorage, Ownable, IBridgeMessageReceiver {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => string) private _tokenURIs;
    address bridgeContractPolygon;
    address sisterContract;
    address bridgeContractGalaxyBridge;

    constructor(
        address _bridgeContractPolygon,
        address _sisterContract,
        address _bridgeContractGalaxyBridge
    ) ERC721("galaxyBridge", "BRIDGE") {
        bridgeContractPolygon = _bridgeContractPolygon;
        bridgeContractGalaxyBridge = _bridgeContractGalaxyBridge;
        sisterContract = _sisterContract;
    }

    function changeBridgeContract(
        address _bridgeContractPolygon,
        address _sisterContract,
        address _bridgeContractGalaxyBridge
    ) external onlyOwner {
        bridgeContractPolygon = _bridgeContractPolygon;
        bridgeContractGalaxyBridge = _bridgeContractGalaxyBridge;
        sisterContract = _sisterContract;
    }

    //@notice   this is being called from the polygon bridge after claiming the message via the galaxyBridge contract
    //          or by calling the polygon bridgeContract directly.
    //          the galaxy bridge natively supports ownership proofs & leaf indexes/proofs, so id suggest to stick with the galaxyBridge
    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable {
        require(
            msg.sender == bridgeContractPolygon,
            "only callable via cross chain messaging, public API  @galaxyBridge "
        );

        require(originAddress == bridgeContractGalaxyBridge, "message is not from the galaxyBridge!");

        (
            address _addrOwner,
            address _addrOriginNftContract,
            uint256 _nftId
        ) = decodeMessagePayload(castBytesToBytes32(data));

        require(_addrOriginNftContract == sisterContract, "message is not from the sisterContract!");

        //@notice this is where the custom logic has to be implemented

        
    }

    // Decode data payload from bytes32 for cross-chain messaging
    function decodeMessagePayload(
        bytes32 encodedMessageNFTBridge
    ) public pure returns (address, address, uint256) {
        address _addrOwner = address(
            uint160(uint256(encodedMessageNFTBridge) >> 96)
        );
        address _addrOriginNftContract = address(
            uint160((uint256(encodedMessageNFTBridge) << 160) >> 192)
        );
        uint256 _nftId = uint256(encodedMessageNFTBridge) & 0xFFFFFFFF;
        return (_addrOwner, _addrOriginNftContract, _nftId);
    }


    function castBytesToBytes32(bytes memory input) public pure returns (bytes32 output) {
        require(input.length == 32, "Input length must be 32 bytes");
        assembly {
            output := mload(add(input, 32))
        }
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // Store the JSON data directly in the token URI
    function _setTokenURI(
        uint256 tokenId,
        string memory uri
    ) internal virtual override {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = uri;
    }

    // Retrieve the token URI with on-chain JSON metadata
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        // Fixed JSON metadata with the same image URL for all tokens
        return
            string(
                abi.encodePacked(
                    '{"name": "NFT ',
                    Strings.toString(tokenId),
                    '", "description": "A GalaxyBridge NFT ", "image": "https://upload.wikimedia.org/wikipedia/en/5/5f/Original_Doge_meme.jpg"}'
                )
            );
    }
}
