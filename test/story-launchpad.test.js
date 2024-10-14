const { expectRevert, time } = require('@openzeppelin/test-helpers')
const MockERC20 = artifacts.require('MockERC20')
const MockERC721 = artifacts.require('MockERC721')
const NftToMint = artifacts.require('LaunchpadToken')
const StoryLaunchpadNFT721 = artifacts.require('StoryLaunchpadNFT721')
const truffleAssert = require('truffle-assertions');
const BN = require('bignumber.js')

contract('StoryLaunchpadNFT721', ([Owner, Creator, alice, carol, bob, minter, vic]) => {
    let launchPadNft;
    let payToken;
    let license;
    let NFT721;
    let tokenId = 0;
  
    before(async () => {
        license = await MockERC721.new("SALENFT", { from: Owner });
        NFT721 = await NftToMint.new(Owner, "SALENFT", "SALENFT", { from: Owner });
        payToken = await MockERC20.new('PAYTOKEN', 'PAYTOKEN', '100000000', { from: Owner });
        launchPadNft = await StoryLaunchpadNFT721.new(Owner, { from: Owner });
        await NFT721.setMinter(launchPadNft.address, true, { from: Owner });        
    });

    var blockTime = Date.now() / 1000 | 0

    it('should set correct state variables', async () => {
        blockTime = BN(await time.latest()).toNumber();
        tokenId += 1;

        await payToken.mint(alice, 100000000, { from: Owner })
        await payToken.mint(vic, 100000000, { from: Owner })
        await license.mintId(Creator, tokenId, { from: Owner })
        await license.mintId(carol, tokenId+1, { from: Owner })
        await launchPadNft.setAcceptPayToken(payToken.address, true, { from: Owner })

        assert.equal((await payToken.balanceOf(alice)).valueOf(), '100000000');
        assert.equal(await license.ownerOf(tokenId), Creator);
        const owner = await launchPadNft.owner()
        assert.equal(owner.valueOf(), Owner)
        assert.equal(await NFT721.minters(launchPadNft.address), true);
    })

    it('should fail to create launchpad', async () => {
        //should faile when input invalid parameter
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                      NFT721.address,
                                      license.address,                                       
                                      tokenId,
                                      "NFTSALE",
                                      blockTime + 30*60, //start time
                                      blockTime + 1*60*60, // end time                                  
                                      vic, //payToken
                                      100,  //total quantity
                                      5,    // max mint per user
                                      1000, // price
                                      "URI", 
                                      "URI",
                                      0,    // _royaltyPercentage
                                      bob,  // _royaltyAddress
                                      { from: Creator}),
                truffleAssert.ErrorType.revert,
                "StoryLaunchpad: wrong pay token"
        )

        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                        NFT721.address, 
                                        license.address,
                                        tokenId+1,
                                        "NFTSALE",
                                        blockTime + 30*60, //start time
                                        blockTime + 1*60*60, // end time                                  
                                        payToken.address, //payToken
                                        100,  //total quantity
                                        5,    // max mint per user
                                        1000, // price
                                        "URI", 
                                        "URI",
                                        0,    // _royaltyPercentage
                                        bob,  // _royaltyAddress
                                        { from: Creator}),
                truffleAssert.ErrorType.revert,
                "StoryLaunchpad: You are not owner license Token"
        )
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                        "0x0000000000000000000000000000000000000000", 
                                        license.address,
                                        tokenId,
                                        "NFTSALE",
                                        blockTime + 30*60, //start time
                                        blockTime + 1*60*60, // end time                                  
                                        payToken.address, //payToken
                                        100,  //total quantity
                                        5,    // max mint per user
                                        1000, // price
                                        "URI", 
                                        "URI",
                                        0,    // _royaltyPercentage
                                        bob,  // _royaltyAddress
                                        { from: Creator}),
                truffleAssert.ErrorType.revert,
                "nftAddress is wrong"
        )
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                        NFT721.address,
                                        license.address, 
                                        tokenId,
                                        "NFTSALE",
                                        blockTime + 30*60, //start time
                                        blockTime + 1*60*60, // end time                                  
                                        payToken.address, //payToken
                                        100,  //total quantity
                                        0,    // max mint per user
                                        1000, // price
                                        "URI", 
                                        "URI",
                                        0,    // _royaltyPercentage
                                        bob,  // _royaltyAddress
                                        { from: Creator}),
                truffleAssert.ErrorType.revert,
                "INVALID maxBuy"
        )
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                        NFT721.address, 
                                        license.address,
                                        tokenId,
                                        "NFTSALE",
                                        blockTime + 30*60, //start time
                                        blockTime + 1*60*60, // end time                                  
                                        payToken.address, //payToken
                                        0,  //total quantity
                                        5,    // max mint per user
                                        1000, // price
                                        "URI", 
                                        "URI",
                                        0,    // _royaltyPercentage
                                        bob,  // _royaltyAddress
                                        { from: Creator}),
                truffleAssert.ErrorType.revert,
                "INVALID totalQuantity"
        )
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                        NFT721.address, 
                                        license.address,
                                        tokenId,
                                        "NFTSALE",
                                        blockTime - 30*60, //start time
                                        blockTime + 1*60*60, // end time                                  
                                        payToken.address, //payToken
                                        100,  //total quantity
                                        5,    // max mint per user
                                        1000, // price
                                        "URI", 
                                        "URI",
                                        0,    // _royaltyPercentage
                                        bob,  // _royaltyAddress
                                        { from: Creator}),
                truffleAssert.ErrorType.revert,
                "INVALID startTime"
        )
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                                        NFT721.address, 
                                        license.address,
                                        tokenId,
                                        "NFTSALE",
                                        blockTime + 2*30*60, //start time
                                        blockTime + 1*60*60, // end time                                  
                                        payToken.address, //payToken
                                        100,  //total quantity
                                        5,    // max mint per user
                                        1000, // price
                                        "URI", 
                                        "URI",
                                        0,    // _royaltyPercentage
                                        bob,  // _royaltyAddress
                                        { from: Creator}),
                truffleAssert.ErrorType.revert,
                "INVALID endTime"
        )
    
    })

    it('should correct create launchpad', async () => {
        //should success when input valid parameter
        await launchPadNft.createNFTSale(Creator, 
                NFT721.address, 
                license.address,
                tokenId,
                "NFTSALE",
                blockTime + 30*60, //start time
                blockTime + 1*60*60, // end time                                  
                payToken.address, //payToken
                10,  //total quantity
                8,    // max mint per user
                100, // price
                "URI", 
                "URI",
                0,    // _royaltyPercentage
                bob,  // _royaltyAddress
                { from: Creator})
        
        let currentPhase = await launchPadNft.currentLaunchpadPhase(license.address, tokenId).valueOf()
        assert.equal(currentPhase, "1")
        const phase = await launchPadNft.NFTSales(license.address, tokenId, currentPhase)

        assert.equal( phase.creator, Creator)
        assert.equal( phase.nftAddress, NFT721.address)
        assert.equal( phase.payToken, payToken.address)
        assert.equal( phase.colectionName, "NFTSALE")
        assert.equal( phase.licenseTokenId, tokenId)
        assert.equal( phase.totalQuantity, 10)
        assert.equal( phase.maxBuy, 8)
        assert.equal( phase.price, 100)
        assert.equal( phase.startTime, blockTime + 30*60)
        assert.equal( phase.endTime, blockTime + 1*60*60)
        assert.equal( phase.royaltyPercentage, 0)
    })

    it('should fail to create launchpad when exist other', async () => {
        await truffleAssert.fails(
            launchPadNft.createNFTSale(Creator, 
                NFT721.address, 
                license.address,
                tokenId,
                "NFTSALE",
                blockTime + 30*60, //start time
                blockTime + 1*60*60, // end time                                  
                payToken.address, //payToken
                100,  //total quantity
                5,    // max mint per user
                1000, // price
                "URI", 
                "URI",
                0,    // _royaltyPercentage
                bob,  // _royaltyAddress
                { from: Creator}),
                truffleAssert.ErrorType.revert,
                "StoryLaunchpad: last nft sale should be end"
            )
    })    

    it('should fail to mint when incorrect parameter', async () => {
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address,
                tokenId + 10,
                1,                  //quantity
                payToken.address,   //payToken
                100,                //pay amount    
                "uri",                               
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: nft sale should not exist"
        )

        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                1,                  //quantity
                payToken.address,   //payToken
                100,                //pay amount         
                "uri",                          
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: nft sale should be open"
        )        

        await time.increaseTo(blockTime + 31*60); //advance to block time
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                1,                  //quantity
                vic,   //payToken
                100,                //pay amount    
                "uri",                              
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: wrong pay token"
        )        

        await time.increaseTo(blockTime + 2*31*60); //advance to block time
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                1,                  //quantity
                payToken.address,   //payToken
                100,                //pay amount   
                "uri",                                
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: nft sale should be open"
        )                  
    })       

    it('User mint NFT', async () => {
        blockTime = BN(await time.latest()).toNumber();
        await launchPadNft.createNFTSale(Creator, 
            NFT721.address,
            license.address, 
            tokenId,
            "NFTSALE",
            blockTime + 30*60, //start time
            blockTime + 1*60*60, // end time                                  
            payToken.address, //payToken
            10,  //total quantity
            8,    // max mint per user
            100, // price
            "URI", 
            "URI",
            0,    // _royaltyPercentage
            bob,  // _royaltyAddress
            { from: Creator})
        
        await time.increaseTo(blockTime + 31*60); //advance to block time
        await payToken.approve(launchPadNft.address, '1000000', { from: alice })
        await payToken.approve(launchPadNft.address, '1000000', { from: vic })
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                0,                  //quantity
                payToken.address,   //payToken
                100,                //pay amount   
                "uri",                                
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: Invalid quantity"
        )     
        
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                10,                  //quantity
                payToken.address,   //payToken
                100,                //pay amount     
                "uri",                              
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: Invalid quantity"
        )        
        
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                2,                  //quantity
                payToken.address,   //payToken
                100,                //pay amount     
                "uri",                              
                { from: alice}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: not enough fund"
        )  
        //alice mint 6 nft
        // await truffleAssert.passes(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                6,                  //quantity
                payToken.address,   //payToken
                600,              //pay amount   
                "uri",                               
                { from: alice}
            )
        // ) 

        // await truffleAssert.fails(
        //     launchPadNft.mintNFT(
        //         license.address, 
        //         tokenId,
        //         3,                  //quantity
        //         payToken.address,   //payToken
        //         300,                //pay amount           
        //         "uri",                        
        //         { from: alice}
        //     ),
        //     truffleAssert.ErrorType.revert,
        //     "StoryLaunchpad: You buy too much"
        // )    
        
        //vic mint 4 nft
        await truffleAssert.passes(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                3,                  //quantity
                payToken.address,   //payToken
                400,                //pay amount      
                "uri",                             
                { from: vic}
            )
        )  
        
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                3,                  //quantity
                payToken.address,   //payToken
                300,                //pay amount      
                "uri",                             
                { from: vic}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: NFT sold out"
        )      
        
        await time.increaseTo(blockTime + 1*61*60); //advance to block time
        await truffleAssert.fails(
            launchPadNft.mintNFT(
                license.address, 
                tokenId,
                1,                  //quantity
                payToken.address,   //payToken
                1,                //pay amount      
                "uri",                             
                { from: vic}
            ),
            truffleAssert.ErrorType.revert,
            "StoryLaunchpad: nft sale should be open"
        )                  
    })           

})