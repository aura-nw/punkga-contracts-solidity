// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";


interface ILaunchpadNFT is IERC721Metadata, IERC721Enumerable {

    struct LaunchpadTokenMetadata {
        address licensorIpId;
        address licenseTemplate;
        uint256 licenseTermsId;
        bool transferable;
    }

    event LaunchpadNFTMinted(address indexed minter, address indexed receiver, uint256 indexed tokenId);

    function mintTokens(address _receiver,
                        uint256 _amount // mint amount
                        ) external;
}
