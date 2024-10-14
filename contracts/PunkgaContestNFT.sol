// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./AccessControl.sol";
import "./ILaunchpadNFT.sol";

contract LaunchpadNFT is  ERC721Enumerable, AccessControl {

    uint private _counter;

    string public baseURI = "";
    string public contractURIPrefix = "";
    bool public paused = false;    

    mapping(address => bool) public minters;
    mapping(uint256 => string) private uris;

    event minted(
        uint256 indexed _tokenId,
        address indexed _owner
    );

    constructor(address _owner, string memory _name, string memory _symbol) ERC721(_name, _symbol) AccessControl(_owner) {
        _counter = 0;
        minters[msg.sender] = true;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    function setMinter(address _minter, bool _v) external onlyOwner {
        minters[_minter] = _v;
        emit SetOperator(_minter, _v);
    }     

    modifier onlyMinter() {
        require(minters[msg.sender]);
        _;
    }    

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function contractURI() external view returns (string memory) {
        return contractURIPrefix;
    }    

    function togglePause() external onlyOwner {
        paused = !paused;
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }

    function setContractURI(string memory _uri) external onlyOwner {
        contractURIPrefix = _uri;
    }    

    function mintTokens(address _receiver,
                        string memory _uri) external onlyMinter returns (uint256 tokenId) {

        uint256 tokenId = _counter + 1;
        _counter += 1;
        uris[tokenId] = _uri;
        
        _safeMint(_receiver, tokenId);
        
        emit minted(tokenId, _receiver);
        return tokenId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireOwned(tokenId);
        return uris[tokenId];
    }    
}
