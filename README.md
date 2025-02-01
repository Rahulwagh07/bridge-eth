# Bridge Contract

A secure ERC20 token bridge contract for cross-chain transfers.

## Installation

1. Install dependencies:
```bash
forge install
```

2. Build the project:
```bash
forge build
```

## Testing

Run the tests:
```bash
forge test
```

For detailed test output:
```bash
forge test -vvv
```

## Contract

### BridgeContract.sol

The main contract handling the bridge operations:

- `bridge(IERC20 _tokenAddress, uint256 _amount)`: Locks tokens in the bridge
- `redeem(IERC20 _tokenAddress, address _to, uint256 _amount, uint256 _nonce)`: Releases tokens to recipients
 

## Events

- `TokensBridged(IERC20, uint256, address)`: Emitted when tokens are locked in the bridge
- `TokensRedeemed(IERC20, address, uint256)`: Emitted when tokens are released to recipients
 
