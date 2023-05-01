// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IPolygonBridgeContract {
    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes calldata metadata
    ) external payable;

    function claimMessage(
        //@notice for testing reduced size
        bytes32[32] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external;
}

interface ICrossChainNFTContract {
    function onBridgedNFTReceived(uint _nftId, address _newOwner) external;
}

// Abstract contract, add appropriate functionality later
abstract contract WrappedNFT {
    function claimBridged(
        uint256 srcChainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    ) public virtual returns (bool, address, address, uint);

    function addSisterContract(
        address _newSisterContractOnOtherChain
    ) public virtual;
}

// Contract for open access NFT bridge
contract openAccessNFTBridge is Ownable, IERC721Receiver {
    using Counters for Counters.Counter;

    IPolygonBridgeContract polygonBridge;

    // Use different starting points for each chain to prevent overlap
    Counters.Counter private _tokenIdCounter;

    // Define bridge and chain contracts and IDs
    address public polygonzkEVMBridgeContractL1 =
        address(0xF6BEEeBB578e214CA9E23B0e9683454Ff88Ed2A7); // MessageService PolygonzkEVM

    address public polygonzkEVMBridgeContractL2 =
        address(0xF6BEEeBB578e214CA9E23B0e9683454Ff88Ed2A7); // MessageService PolygonzkEVM

    uint32 public goerliChainId = 5; //ChainID Sepolia

    uint32 public polygonChainIdZK = 1442; //ChainID polygon zkEVM  Testnet

    uint public currentChainType = 1; // 1 for L1, 2 for L2

    address public currentBridgeSignalContract;

    // The bridge contract on the other side. Actually useless atm.
    address public currentSisterContract;

    bool sisterBridgeSetup = false;

    uint32 public currentChainId;

    uint32 public currentSisterChainId;

    event bridgeRequestSent(
        address owner,
        address indexednftContract,
        uint indexed nftId
    );

    event bridgeSucess(
        address owner,
        address indexednftContract,
        uint indexed nftId
    );

    // Constructor function for the contract
    constructor(uint _chainType) {
        currentChainType = _chainType;

        if (_chainType == 1) {
            currentBridgeSignalContract = polygonzkEVMBridgeContractL1;

            currentChainId = goerliChainId;
            currentSisterChainId = polygonChainIdZK;
        }

        if (_chainType == 2) {
            currentBridgeSignalContract = polygonzkEVMBridgeContractL2;

            currentChainId = polygonChainIdZK;
            currentSisterChainId = goerliChainId;
        }
    }

    // Mapping to store NFTs being held
    // contract => nftId => status
    mapping(address => mapping(uint => bool)) heldNFT;

    mapping(address => address) public sisterContract;

    // Add a new sister contract
    function addSisterContract(address _newSisterContract) external {
        sisterContract[msg.sender] = _newSisterContract;
    }

    // Add a sister contract via signature
    function addSisterContractViaSignature(
        address _newSisterContract,
        bytes memory _signature
    ) external {
        // TODO
        // for non-upgradable NFT Contracts to be L2 Bridge compliant
    }

    function addSisterBridgeContract(
        address _SisterContractInit
    ) external onlyOwner {
        //sister bridge contract can only be set up once, otherwise reverts
        require(!sisterBridgeSetup, "A contract is a contract is a contract!");
        sisterBridgeSetup = true;
        currentSisterContract = _SisterContractInit;
    }

    //@notice this is for claiming previously bridged over NFTS back.
    //@notice this is for claiming already minted NFTS that have been held by the bridge until this point.
    //@notice For the other case ( wrappedNFT or custom Mint of the NFT after the bridging), see onMessageReceived.
    //@notice example NFT Contract implementation is also in the repo.

    function claimBridged(
        bytes32 _dataPayload,
        bytes32[32] calldata _smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot
    ) external {
        //exampleData

        //@notice we could do it via the encoded bytes call instead for less gasUsage / cleaner code I guess? Does increase complexity

        //@notice the bridge does call onMessageReceived to communicate with the receiver contract. reverts if it doesnt meet the expectations.
        polygonBridge.claimMessage(
            _smtProof,
            index,
            mainnetExitRoot,
            rollupExitRoot,
            currentSisterChainId,
            currentSisterContract,
            2, // Destination network
            address(this),
            0,
            abi.encodePacked(_dataPayload)
        );

        (
            address _addrOwner,
            address _addrOriginNftContract,
            uint256 _nftId
        ) = decodeMessagePayload(_dataPayload);

        processNftTransfer(_addrOwner, _addrOriginNftContract, _nftId);
    }

    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable {
        require(originAddress == currentSisterContract);
        require(msg.sender == polygonzkEVMBridgeContractL1);

        /*
        address caller = originAddress;
        caller = address(0);
        (bool success, ) = address(this).call(data);
        if (!success) {
            revert("metadata execution failed");
        }
        */
    }

    function processNftTransfer(
        address _addrOwner,
        address _addrOriginNftContract,
        uint256 _nftId
    ) internal {
        if (heldNFT[_addrOriginNftContract][_nftId]) {
            IERC721(sisterContract[_addrOriginNftContract]).safeTransferFrom(
                sisterContract[_addrOriginNftContract],
                _addrOwner,
                _nftId
            );

            delete heldNFT[_addrOriginNftContract][_nftId];
        } else {
            //@TODO message NFT Contract to mint new one via interface.
            //if no sisterContract is specified, we can either deploy wrappedContracts or revert it.

            require(
                sisterContract[_addrOriginNftContract] != address(0),
                "no sister contract specified!"
            );

            ICrossChainNFTContract sisterContract = ICrossChainNFTContract(
                sisterContract[_addrOriginNftContract]
            );

            sisterContract.onBridgedNFTReceived(_nftId, _addrOwner);
        }
    }

    function getHeldNFT(
        address _addrOriginNftContract,
        uint256 _nftId
    ) public view returns (bool) {
        return heldNFT[_addrOriginNftContract][_nftId];
    }

    //requestId => storageSlot;
    mapping(uint => bytes32) public storageSlotsBridgeRequest;

    mapping(uint => address) public bridgeRequestInitiatorUser;

    mapping(uint => address) public bridgeRequestInitiatorSender;

    mapping(uint => bytes32) public sentPayload;
    uint public totalRequestsSent;

    //sending the message to the bridge with encoded data payload.
    function sendMessageToL2(address _to, bytes memory _calldata) internal {
        IPolygonBridgeContract bridge = IPolygonBridgeContract(
            polygonzkEVMBridgeContractL1
        );

        uint32 destinationNetwork = uint32(currentChainType);
        bool forceUpdateGlobalExitRoot = true;
        bridge.bridgeMessage{value: msg.value}(
            destinationNetwork,
            _to,
            forceUpdateGlobalExitRoot,
            _calldata
        );
    }

    event bridgeData(address indexed sender, bytes32 indexed dataPayload);

    function testMessaging(address _to, bytes memory _calldata) external {
        sendMessageToL2(_to, _calldata);
    }

    // Bridge NFT to sister chain
    // @notice requires safeTransfer, normal transfer does not trigger onERC721 received
    //
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public override returns (bytes4) {
        address nftContractAddr = msg.sender;

        bytes32 encodedData = encodeMessagePayload(
            nftContractAddr,
            from,
            tokenId
        );

        sentPayload[totalRequestsSent] = encodedData;
        bridgeRequestInitiatorUser[totalRequestsSent] = from;
        bridgeRequestInitiatorSender[totalRequestsSent] = msg.sender;

        emit bridgeData(msg.sender, encodedData);

        totalRequestsSent++;
        heldNFT[nftContractAddr][tokenId] = true;

        emit bridgeRequestSent(from, msg.sender, tokenId);

        sendMessageToL2(currentSisterContract, abi.encodePacked(encodedData));

        return this.onERC721Received.selector;
    }

    // Encode data payload to bytes32 for cross-chain messaging
    function encodeMessagePayload(
        address _addrOwner,
        address _addrOriginNftContract,
        uint256 _nftId
    ) public pure returns (bytes32) {
        bytes32 encoded = bytes32(
            (uint256(uint160(_addrOwner)) << 96) |
                (uint256(uint160(_addrOriginNftContract)) << 32) |
                _nftId
        );
        return encoded;
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
}
