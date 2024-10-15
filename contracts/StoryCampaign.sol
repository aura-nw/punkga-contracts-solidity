// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;
pragma experimental ABIEncoderV2;

import { IAccessController } from "@story-protocol/protocol-core/contracts/interfaces/access/IAccessController.sol";
import { IIPAssetRegistry } from "@story-protocol/protocol-core/contracts/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@story-protocol/protocol-core/contracts/interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "@story-protocol/protocol-core/contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { ICoreMetadataViewModule } from "@story-protocol/protocol-core/contracts/interfaces/modules/metadata/ICoreMetadataViewModule.sol";
import { IPILicenseTemplate, PILTerms } from "@story-protocol/protocol-core/contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicenseTemplate } from "@story-protocol/protocol-core/contracts/interfaces/modules/licensing/ILicenseTemplate.sol";
import { IRoyaltyModule } from "@story-protocol/protocol-core/contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IIPAccount } from "@story-protocol/protocol-core/contracts/interfaces/IIPAccount.sol";

import { IStoryProtocolGateway, MakeDerivative, IPMetadata } from "./IStoryProtocolGateway.sol";

// import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
// import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { LaunchpadNFT } from "./PunkgaContestNFT.sol";

contract StoryCampaign is AccessControl, IERC721Receiver {
    using SafeERC20 for IERC20;

    address public ipAssetRegistry = 0x1a9d0d28a0422F26D31Be72Edc6f13ea4371E11B;
    address public licensingModule = 0xd81fd78f557b457b4350cB95D20b547bFEb4D857;
    address public licenseToken = 0xc7A302E03cd7A304394B401192bfED872af501BE;
    address public licenseTemplate = 0x0752f61E59fD2D39193a74610F1bd9a6Ade2E3f9;
    address public coreMetadataView = 0x48ecAa9F197135A4614d1c7A5Db5641ffd8ad2b9;
    address public licenseRegistry = 0xedf8e338F05f7B1b857C3a8d3a0aBB4bc2c41723;
    address public royaltyModule = 0x3C27b2D7d30131D4b58C3584FD7c86e3358744de;

    address public collectionAddress;

    uint256 private maxParents = 5;
    uint256 private maxIpasset = 30;

    address public SPG_ADDRESS;

    //creator address -> count
    mapping(address => uint256) public userMintCount;

    constructor(address _owner, address _storyProtocolGateway) public AccessControl(_owner) {
        SPG_ADDRESS = _storyProtocolGateway;
    }

    event CollectionCreated(address indexed nftContract);
    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // function _owns(address _licensorIpid) internal view returns (bool) {
    //     return (ICoreMetadataViewModule(coreMetadataView).getOwner(_licensorIpid) == msg.sender);
    // }

    function setStoryProtocolGateway(address _addr) public onlyOwner {
        SPG_ADDRESS = _addr;
    }

    function setIpAssetRegistry(address _addr) public onlyOwner {
        ipAssetRegistry = _addr;
    }

    function setLicensingModule(address _addr) public onlyOwner {
        licensingModule = _addr;
    }

    function setMaxParents(uint256 _maxParents) public onlyOwner {
        maxParents = _maxParents;
    }

    function setMaxIpasset(uint256 _maxIpasset) public onlyOwner {
        maxParents = _maxIpasset;
    }

    function setLicenseToken(address _addr) public onlyOwner {
        licenseToken = _addr;
    }

    function setCoreMetadataView(address _addr) public onlyOwner {
        coreMetadataView = _addr;
    }

    function setLicenseRegistry(address _addr) public onlyOwner {
        licenseRegistry = _addr;
    }

    function setCollectionAddress(address _addr) public onlyOwner {
        collectionAddress = _addr;
    }

    function setLicenseTemplate(address _addr) public onlyOwner {
        licenseTemplate = _addr;
    }

    function setRoyaltyModule(address _addr) public onlyOwner {
        royaltyModule = _addr;
    }

    function transferHelper(address token, address payable add, uint256 amount) private {
        if (token == address(0)) {
            add.transfer(amount);
        } else {
            IERC20(token).transfer(add, amount);
        }
    }

    function createCollection(string memory colectionName, string memory colectionSymbol) public onlyOperator {
        collectionAddress = address(new LaunchpadNFT(msg.sender, colectionName, colectionSymbol));
        emit CollectionCreated(address(collectionAddress));
    }

    function mintAndRegisterIpAndAttach(
        address recipient,
        IPMetadata calldata ipMetadata,
        PILTerms calldata terms
    ) public onlyOperator returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        require(userMintCount[recipient] + 1 <= maxIpasset, "StoryCampaign: AboveMintLimit");

        userMintCount[recipient] += 1;

        IStoryProtocolGateway(SPG_ADDRESS).mintAndRegisterIpAndAttachPILTerms(
            collectionAddress,
            recipient,
            ipMetadata,
            terms
        );
    }

    function _registerPILTermsAndAttach(
        address ipId,
        PILTerms calldata terms
    ) internal returns (uint256 licenseTermsId) {
        licenseTermsId = IPILicenseTemplate(licenseTemplate).registerLicenseTerms(terms);
        // Returns if license terms are already attached.
        if (ILicenseRegistry(licenseRegistry).hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId))
            return licenseTermsId;

        ILicensingModule(licensingModule).attachLicenseTerms(ipId, licenseTemplate, licenseTermsId);
    }

    function mintAndRegisterIpAndMakeDerivative(
        MakeDerivative calldata derivData,
        IPMetadata calldata ipMetadata,
        address recipient
    ) external onlyOperator returns (address ipId, uint256 tokenId) {
        require(derivData.parentIpIds.length <= maxParents, "StoryCampaign: Parent Limit Reached");

        (ipId, tokenId) = IStoryProtocolGateway(SPG_ADDRESS).mintAndRegisterIpAndMakeDerivative(
            collectionAddress,
            derivData,
            ipMetadata,
            recipient
        );
        return (ipId, tokenId);
    }

    /// @dev Aggregate license mint fees for all parent IPs.
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    /// @return totalMintFee The sum of license mint fees across all parent IPs.
    function _aggregateMintFees(
        address payerAddress,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal view returns (uint256 totalMintFee) {
        uint256 mintFee;

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            (, mintFee) = ILicensingModule(licensingModule).predictMintingLicenseFee({
                licensorIpId: parentIpIds[i],
                licenseTemplate: licenseTemplate,
                licenseTermsId: licenseTermsIds[i],
                amount: 1,
                receiver: payerAddress,
                royaltyContext: ""
            });
            totalMintFee += mintFee;
        }
    }

    /// @dev Collect mint fees for all parent IPs from the payer and set approval for Royalty Module to spend mint fees.
    /// @param payerAddress The address of the payer for the license mint fees.
    /// @param parentIpIds The IDs of all the parent IPs.
    /// @param licenseTermsIds The IDs of the license terms for each corresponding parent IP.
    function _collectMintFeesAndSetApproval(
        address payerAddress,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds
    ) internal {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        (address royaltyPolicy, , , address mintFeeCurrencyToken) = lct.getRoyaltyPolicy(licenseTermsIds[0]);

        if (royaltyPolicy != address(0)) {
            // Get total mint fee for all parent IPs
            uint256 totalMintFee = _aggregateMintFees({
                payerAddress: payerAddress,
                parentIpIds: parentIpIds,
                licenseTermsIds: licenseTermsIds
            });

            if (totalMintFee != 0) {
                // Transfer mint fee from payer to this contract
                IERC20(mintFeeCurrencyToken).safeTransferFrom(payerAddress, address(this), totalMintFee);

                // Approve Royalty Policy to spend mint fee
                IERC20(mintFeeCurrencyToken).forceApprove(royaltyModule, totalMintFee);
            }
        }
    }
}
