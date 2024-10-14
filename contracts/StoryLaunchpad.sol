// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;
pragma experimental ABIEncoderV2;

import { LicenseToken } from "@story-protocol/protocol-core/contracts/LicenseToken.sol";
import { LicensingModule } from "@story-protocol/protocol-core/contracts/modules/licensing/LicensingModule.sol";
import { CoreMetadataViewModule } from "@story-protocol/protocol-core/contracts/modules/metadata/CoreMetadataViewModule.sol";
import { IPAssetRegistry } from "@story-protocol/protocol-core/contracts/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@story-protocol/protocol-core/contracts/registries/LicenseRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./AccessControl.sol";
import "./LaunchpadNFT.sol";

contract StoryLaunchpad is AccessControl, IERC721Receiver {
    using SafeERC20 for IERC20;

    mapping(address => bool) public acceptPayTokens;
    //sender address -> creatorAddress -> licensorIpid -> launchpad phase -> count
    mapping(address => mapping(address => mapping(address => mapping(uint256 => uint256)))) public userBuyCount;
    //creatorAddress -> licensorIpid -> launchpad phase -> count
    mapping(address => mapping(address => mapping(uint256 => uint256))) public numberOfNftSold;

    address public ipAssetRegistryAddr = 0xd43fE0d865cb5C26b1351d3eAf2E3064BE3276F6;
    address public licensingModuleAddr = 0xe89b0EaA8a0949738efA80bB531a165FB3456CBe;
    address public licenseTokenAddr = 0x1333c78A821c9a576209B01a16dDCEF881cAb6f2;
    address public licenseTemplateAddr = 0x260B6CB6284c89dbE660c0004233f7bB99B5edE7;
    address public coreMetadataViewAddr = 0x17aD427cd467A85c256acDF57848Ec6383D70dF5;

    struct StoryLaunchpad {
        address payable creatorAddress;
        address licensorIpid;
        string colectionName;
        uint256 startTime;
        uint256 endTime;
        uint256 totalQuantity;
        uint256 maxBuy;
    }

    struct LaunchpadInfor {
        address nftAddress;
        address payToken;
        uint256 price;
        string uriLaunchpad;
        string uriNFT;
        uint256 royaltyPercentage;
        address royaltyAddress;
    }

    // Map from creator address > licensorIpid > NFTSales.
    mapping(address => mapping(address => mapping(uint256 => StoryLaunchpad))) public StoryLaunchpads;
    mapping(address => mapping(address => mapping(uint256 => LaunchpadInfor))) public LaunchpadInfors;
    mapping(address => mapping(address => uint256)) public licensorLaunchpadCount;

    event StoryLaunchpadCreated(
        address indexed _creatorAddress,
        address indexed _licensorIpid,
        StoryLaunchpad storyLaunchpad
    );

    event MintNFTSuccessful(address indexed _minter, address indexed _licensorIpid, uint256 _quantity);

    constructor(address _owner) AccessControl(_owner) {}

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier isOpening(address _creatorAddress, address _licensorIpid) {
        uint256 licensorLaunchpadCount = getCurrentLaunchpadCount(_creatorAddress, _licensorIpid);
        StoryLaunchpad memory launchpad = StoryLaunchpads[_creatorAddress][_licensorIpid][licensorLaunchpadCount];
        require(
            launchpad.startTime <= block.timestamp && block.timestamp < launchpad.endTime,
            "StoryLaunchpad: Launchpad should be open"
        );
        _;
    }

    modifier isNotLaunchpadRunning(address _creatorAddress, address _licensorIpid) {
        uint256 licensorLaunchpadCount = getCurrentLaunchpadCount(_creatorAddress, _licensorIpid);
        StoryLaunchpad memory launchpad = StoryLaunchpads[_creatorAddress][_licensorIpid][licensorLaunchpadCount];
        require(launchpad.endTime < block.timestamp, "StoryLaunchpad: last Launchpad should be end");
        _;
    }

    modifier notOpen(address _creatorAddress, address _licensorIpid) {
        uint256 licensorLaunchpadCount = getCurrentLaunchpadCount(_creatorAddress, _licensorIpid);
        StoryLaunchpad memory launchpad = StoryLaunchpads[_creatorAddress][_licensorIpid][licensorLaunchpadCount];
        require(block.timestamp < launchpad.startTime, "StoryLaunchpad: Launchpad should not open");
        _;
    }

    modifier existLaunchpad(address _creatorAddress, address _licensorIpid) {
        uint256 licensorLaunchpadCount = getCurrentLaunchpadCount(_creatorAddress, _licensorIpid);
        StoryLaunchpad memory launchpad = StoryLaunchpads[_creatorAddress][_licensorIpid][licensorLaunchpadCount];
        require(launchpad.startTime > 0, "StoryLaunchpad: Launchpad should exist");
        _;
    }

    modifier notExistLaunchpad(address _creatorAddress, address _licensorIpid) {
        uint256 licensorLaunchpadCount = getCurrentLaunchpadCount(_creatorAddress, _licensorIpid);
        if (licensorLaunchpadCount > 0) {
            require(
                StoryLaunchpads[_creatorAddress][_licensorIpid][licensorLaunchpadCount].licensorIpid == address(0x0),
                "StoryLaunchpad: Launchpad should not exist"
            );
            _;
        }
    }

    function _owns(address _licensorIpid) internal view returns (bool) {
        CoreMetadataViewModule _coreMetadataViewContract = CoreMetadataViewModule(coreMetadataViewAddr);
        return (_coreMetadataViewContract.getOwner(_licensorIpid) == msg.sender);
    }

    function setAcceptPayToken(address _payToken, bool _accept) public onlyOwner {
        acceptPayTokens[_payToken] = _accept;
    }

    function setIpAssetRegistryAddr(address _addr) public onlyOwner {
        ipAssetRegistryAddr = _addr;
    }

    function setLicensingModuleAddr(address _addr) public onlyOwner {
        licensingModuleAddr = _addr;
    }

    function setLicenseTokenAddr(address _addr) public onlyOwner {
        licenseTokenAddr = _addr;
    }

    function setCoreMetadataViewAddr(address _addr) public onlyOwner {
        coreMetadataViewAddr = _addr;
    }

    function getCurrentLaunchpadCount(address _creatorAddress, address _licensorIpid) public view returns (uint256) {
        return licensorLaunchpadCount[_creatorAddress][_licensorIpid];
    }

    function getLicenseIdByLicensor(address _licensorIpid) public view returns (uint256) {
        LicenseToken licenseTokenContract = LicenseToken(licenseTokenAddr);
        uint256 balanceOf = licenseTokenContract.balanceOf(address(this));

        for (uint256 i = 0; i < balanceOf; i++) {
            uint256 licenseId = licenseTokenContract.tokenOfOwnerByIndex(address(this), i);
            address licensorIpId = licenseTokenContract.getLicensorIpId(licenseId);

            if (licensorIpId == _licensorIpid) {
                return licenseId;
            }
        }
    }

    function transferHelper(address token, address payable add, uint256 amount) private {
        if (token == address(0)) {
            add.transfer(amount);
        } else {
            IERC20(token).transfer(add, amount);
        }
    }

    function createLaunchpad(
        StoryLaunchpad memory _launchpad,
        LaunchpadInfor memory _launchpadInfor
    ) public isNotLaunchpadRunning(_launchpad.creatorAddress, _launchpad.licensorIpid) {
        require(_launchpad.creatorAddress != address(0), "creatorAddress is wrong");
        require(_owns(_launchpad.licensorIpid), "StoryLaunchpad: You are not owner licensorIpid");
        require(acceptPayTokens[_launchpadInfor.payToken], "StoryLaunchpad: wrong pay token");
        require(_launchpad.maxBuy > 0, "INVALID maxBuy");
        require(_launchpad.licensorIpid != address(0), "licensorIpid is wrong");
        require(_launchpadInfor.price >= 0, "INVALID price");
        require(_launchpad.totalQuantity >= _launchpad.maxBuy, "INVALID totalQuantity");
        require(_launchpad.startTime > block.timestamp, "INVALID startTime");
        require(_launchpad.endTime > _launchpad.startTime, "INVALID endTime");
        require(
            _launchpadInfor.royaltyPercentage >= 0 && _launchpadInfor.royaltyPercentage <= 100,
            "INVALID royaltyPercentage"
        );

        LaunchpadNFT launchpadNFT = new LaunchpadNFT(msg.sender, _launchpad.colectionName, "STORYAURANFT");

        LaunchpadInfor memory launchpadInfor;
        launchpadInfor = _launchpadInfor;
        launchpadInfor.nftAddress = address(launchpadNFT);

        uint256 currentPhase = getCurrentLaunchpadCount(_launchpad.creatorAddress, _launchpad.licensorIpid);
        currentPhase += 1;
        StoryLaunchpads[_launchpad.creatorAddress][_launchpad.licensorIpid][currentPhase] = _launchpad;
        licensorLaunchpadCount[_launchpad.creatorAddress][_launchpad.licensorIpid] += 1; // cumulative

        LaunchpadInfors[_launchpad.creatorAddress][_launchpad.licensorIpid][currentPhase] = _launchpadInfor;

        emit StoryLaunchpadCreated(_launchpad.creatorAddress, _launchpad.licensorIpid, _launchpad);
    }

    function updateInfo(
        StoryLaunchpad memory _launchpad,
        LaunchpadInfor memory _launchpadInfor
    )
        public
        onlyOwner
        existLaunchpad(_launchpad.creatorAddress, _launchpad.licensorIpid)
        notOpen(_launchpad.creatorAddress, _launchpad.licensorIpid)
    {
        require(_launchpad.creatorAddress != address(0), "creatorAddress is wrong");
        require(acceptPayTokens[_launchpadInfor.payToken], "StoryLaunchpad: wrong pay token");
        require(_launchpad.maxBuy > 0, "INVALID maxBuy");
        require(_launchpad.licensorIpid != address(0), "licensorIpid is wrong");
        require(_launchpadInfor.price >= 0, "INVALID price");
        require(_launchpad.totalQuantity >= _launchpad.maxBuy, "INVALID totalQuantity");
        require(_launchpad.startTime > block.timestamp, "INVALID startTime");
        require(_launchpad.endTime > _launchpad.startTime, "INVALID endTime");
        require(
            _launchpadInfor.royaltyPercentage >= 0 && _launchpadInfor.royaltyPercentage <= 100,
            "INVALID royaltyPercentage"
        );

        uint256 currentPhase = getCurrentLaunchpadCount(_launchpad.creatorAddress, _launchpad.licensorIpid);
        StoryLaunchpad storage storyLaunchpad = StoryLaunchpads[_launchpad.creatorAddress][_launchpad.licensorIpid][
            currentPhase
        ];
        LaunchpadInfor storage launchpadInfor = LaunchpadInfors[_launchpad.creatorAddress][_launchpad.licensorIpid][
            currentPhase
        ];

        storyLaunchpad.startTime = _launchpad.startTime;
        storyLaunchpad.endTime = _launchpad.endTime;
        storyLaunchpad.totalQuantity = _launchpad.totalQuantity;
        storyLaunchpad.maxBuy = _launchpad.maxBuy;
        storyLaunchpad.colectionName = _launchpad.colectionName;

        launchpadInfor.price = _launchpadInfor.price;
        launchpadInfor.uriLaunchpad = _launchpadInfor.uriLaunchpad;
        launchpadInfor.uriNFT = _launchpadInfor.uriNFT;
        launchpadInfor.royaltyPercentage = _launchpadInfor.royaltyPercentage;
        launchpadInfor.royaltyAddress = _launchpadInfor.royaltyAddress;
    }

    function mintNFT(
        address _creatorAddress,
        address _licensorIpid,
        uint256 _quantity,
        address _payToken,
        uint256 _payAmount
    ) public payable existLaunchpad(_creatorAddress, _licensorIpid) isOpening(_creatorAddress, _licensorIpid) {
        require(acceptPayTokens[_payToken], "StoryLaunchpad: wrong pay token");
        uint256 amount = 0;
        if (_payToken == address(0)) {
            amount = msg.value;
        } else {
            require(msg.value == 0, "StoryLaunchpad: Invalid msg.value");
            amount = _payAmount;
        }

        _mintNFT(_creatorAddress, _licensorIpid, _quantity, _payToken, amount);

        emit MintNFTSuccessful(msg.sender, _licensorIpid, _quantity);
    }

    function _mintNFT(
        address _creatorAddress,
        address _licensorIpid,
        uint256 _quantity,
        address _payToken,
        uint256 _payAmount
    ) internal {
        require(_creatorAddress != address(0), "StoryLaunchpad: creatorAddress is wrong");
        // Get a reference to the sale struct
        uint256 licensorLaunchpadCount = getCurrentLaunchpadCount(_creatorAddress, _licensorIpid);
        StoryLaunchpad storage storyLaunchpad = StoryLaunchpads[_creatorAddress][_licensorIpid][licensorLaunchpadCount];
        LaunchpadInfor storage launchpadInfor = LaunchpadInfors[_creatorAddress][_licensorIpid][licensorLaunchpadCount];

        require(_licensorIpid == storyLaunchpad.licensorIpid, "StoryLaunchpad: Invalid _licensorIpid");
        require(_quantity > 0, "StoryLaunchpad: Invalid quantity");
        require(_quantity <= storyLaunchpad.maxBuy, "StoryLaunchpad: Invalid quantity");
        require(
            _quantity <=
                storyLaunchpad.totalQuantity -
                    (numberOfNftSold[_creatorAddress][_licensorIpid][licensorLaunchpadCount]),
            "StoryLaunchpad: NFT sold out"
        );
        require(
            userBuyCount[msg.sender][_creatorAddress][_licensorIpid][licensorLaunchpadCount] + _quantity <=
                storyLaunchpad.maxBuy,
            "StoryLaunchpad: You buy too much"
        );

        require(_payAmount >= launchpadInfor.price * _quantity, "StoryLaunchpad: not enough fund");

        numberOfNftSold[_creatorAddress][_licensorIpid][licensorLaunchpadCount] += _quantity;
        userBuyCount[msg.sender][_creatorAddress][_licensorIpid][licensorLaunchpadCount] += _quantity;

        if (_payToken == address(0)) {
            require(msg.value >= launchpadInfor.price * _quantity, "INVALID MSG.VALUE");
        } else {
            require(msg.value == 0, "MSG.VALUE SHOULD BE ZERO");
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                storyLaunchpad.creatorAddress,
                launchpadInfor.price * _quantity
            );
        }

        if (msg.value > launchpadInfor.price * _quantity) {
            payable(msg.sender).transfer(msg.value - (launchpadInfor.price * _quantity));
        }

        LaunchpadNFT _nftContract = LaunchpadNFT(launchpadInfor.nftAddress);
        for (uint256 i = 0; i < _quantity; i++) {
            //Mint NFT
            uint256 tokenId = _nftContract.mintTokens(address(this), launchpadInfor.uriNFT);
            require(tokenId > 0);

            //Regigter a childIpId for NFT
            address childIpId = IPAssetRegistry(ipAssetRegistryAddr).register(
                block.chainid,
                launchpadInfor.nftAddress,
                tokenId
            );

            //Register Derivative for NFT with licenseId
            uint256[] memory licenseTokenIds = new uint256[](1);
            licenseTokenIds[0] = getLicenseIdByLicensor(_licensorIpid);
            require(licenseTokenIds[0] > 0, "StoryLaunchpad: License token not avaiable for mint");

            LicensingModule(licensingModuleAddr).registerDerivativeWithLicenseTokens({
                childIpId: childIpId,
                licenseTokenIds: licenseTokenIds,
                royaltyContext: "0x0" // empty for PIL
            });

            _nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
        }
    }
}
