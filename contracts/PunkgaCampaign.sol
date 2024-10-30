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

import { WorkflowStructs } from "./lib/WorkflowStructs.sol";
import { ILicenseAttachmentWorkflows } from "./ILicenseAttachmentWorkflows.sol";
import { IDerivativeWorkflows } from "./IDerivativeWorkflows.sol";
import { IRegistrationWorkflows } from "./IRegistrationWorkflows.sol";
import { ISPGNFT } from "./interfaces/ISPGNFT.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { AccessControl } from "./AccessControl.sol";
import { LaunchpadNFT } from "./PunkgaContestNFT.sol";

contract PunkgaCampaign is AccessControl, IERC721Receiver {
    using SafeERC20 for IERC20;

    address public ipAssetRegistry = 0x28E59E91C0467e89fd0f0438D47Ca839cDfEc095;
    address public licensingModule = 0x5a7D9Fa17DE09350F481A53B470D798c1c1aabae;
    address public licenseToken = 0xB138aEd64814F2845554f9DBB116491a077eEB2D;
    address public licenseTemplate = 0x58E2c909D557Cd23EF90D14f8fd21667A5Ae7a93;
    address public coreMetadataView = 0x6839De4A647eE2311bd765f615E09f7bd930ed25;
    address public licenseRegistry = 0xBda3992c49E98392e75E78d82B934F3598bA495f;
    address public royaltyModule = 0xEa6eD700b11DfF703665CCAF55887ca56134Ae3B;

    address public derivativeWorkflows = 0xa8815CEB96857FFb8f5F8ce920b1Ae6D70254C7B;
    address public licenseAttachmentWorkflows = 0x44Bad1E4035a44eAC1606B222873E4a85E8b7D9c;
    address public registrationWorkflows = 0xde13Be395E1cd753471447Cf6A656979ef87881c;

    address[] public collectionAddress;
    uint8 private numberCollection = 0;

    uint256 private maxParents = 10;
    uint256 private maxIpasset = 90;

    //creator address -> count
    mapping(address => uint256) public userMintCount;

    constructor(address _owner) AccessControl(_owner) {
        collectionAddress = new address[](10);
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
        collectionAddress[numberCollection] = _addr;
        numberCollection++;
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
        ISPGNFT.InitParams memory newCollectionInfo = ISPGNFT.InitParams({
            name: colectionName,
            symbol: colectionSymbol,
            baseURI: "",
            contractURI: "",
            maxSupply: 5000,
            mintFee: 0,
            mintFeeToken: address(0),
            mintFeeRecipient: address(0),
            owner: msg.sender,
            mintOpen: true,
            isPublicMinting: false
        });

        address newCollectionAddress = IRegistrationWorkflows(registrationWorkflows).createCollection(
            newCollectionInfo
        );
        collectionAddress[numberCollection] = newCollectionAddress;
        numberCollection++;
        emit CollectionCreated(newCollectionAddress);
    }

    function mintAndRegisterIpAndAttach(
        address recipient,
        address _collectionAddress,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        PILTerms calldata terms
    ) public onlyOperator returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        require(userMintCount[recipient] + 1 <= maxIpasset, "PunkgaCampaign: AboveMintLimit");

        bool allowedCollection = false;
        for (uint8 i = 0; i < numberCollection; i++) {
            if (collectionAddress[i] == _collectionAddress) {
                allowedCollection = true;
                break;
            }
        }
        require(allowedCollection, "PunkgaCampaign: CollectionNotAllowed");

        userMintCount[recipient] += 1;

        (ipId, tokenId, licenseTermsId) = ILicenseAttachmentWorkflows(licenseAttachmentWorkflows)
            .mintAndRegisterIpAndAttachPILTerms(_collectionAddress, recipient, ipMetadata, terms);
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
        WorkflowStructs.MakeDerivative calldata derivData,
        WorkflowStructs.IPMetadata calldata ipMetadata,
        address recipient,
        address _collectionAddress
    ) external onlyOperator returns (address ipId, uint256 tokenId) {
        require(derivData.parentIpIds.length <= maxParents, "PunkgaCampaign: Parent Limit Reached");

        bool allowedCollection = false;
        for (uint8 i = 0; i < numberCollection; i++) {
            if (collectionAddress[i] == _collectionAddress) {
                allowedCollection = true;
                break;
            }
        }
        require(allowedCollection, "PunkgaCampaign: CollectionNotAllowed");

        (ipId, tokenId) = IDerivativeWorkflows(derivativeWorkflows).mintAndRegisterIpAndMakeDerivative(
            _collectionAddress,
            derivData,
            ipMetadata,
            recipient
        );
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
