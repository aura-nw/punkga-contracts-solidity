# punkga-contracts-solidity

This project includes smart contracts of Punkga using on Story Protocol network.

## Building

Before building, users must install dependencies. Run the following command:

```bash
yarn
```

### Compile the contracts

```bash
force build
```

### Testing

To run the tests, use the following command:

```bash
force test
```

### Deployment

To deploy the contracts, you can use Foundry's `forge` tool. Before deploying, you must change the constructor's arguments of contract in `args` file (by rename `args_example`).

```bash
forge create --rpc-url https://testnet.storyrpc.io --private-key <YOUR_PRIVATE_KEY> contracts/<YOUR_CONTRACT>.sol:<YOUR_CONTRACT> --constructor-args-path args
```

Replace `<YOUR_PRIVATE_KEY>` with your private key, and `<YOUR_CONTRACT>` with the name of the contract you want to deploy.

## Contracts

The repository contains the following smart contracts:

-   `AccessControl.sol`: Implements access control mechanisms.
-   `ERC721Mock.sol`: A mock implementation of the ERC721 standard.
-   `ILaunchpadNFT.sol`: Interface for the Launchpad NFT contract.
-   `ISPGNFT.sol`: Interface for the SPG NFT contract.
-   `IStoryProtocolGateway.sol`: Interface for the Story Protocol Gateway contract.
-   `LaunchpadNFT.sol`: Implementation of the Launchpad NFT contract.
-   `MockERC20.sol`: A mock implementation of the ERC20 standard.
-   `multicall.sol`: Implements multicall functionality.
-   `PunkgaContestNFT.sol`: Implementation of the Punkga Contest NFT contract.
-   `StoryCampaign.sol`: Implementation of the Story Campaign contract.
-   `StoryLaunchpad.sol`: Implementation of the Story Launchpad contract.

### License

This project is licensed under the MIT License. See the LICENSE file for details.
