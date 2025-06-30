# VaultCore: Bitcoin-Collateralized Stablecoin System

## Overview

VaultCore is a decentralized finance (DeFi) protocol that enables users to generate USD-pegged stablecoins by locking Bitcoin as collateral. Built on the Stacks blockchain using Clarity smart contracts, VaultCore provides a secure and transparent way to access liquidity while maintaining Bitcoin exposure.

## Key Features

### 🏦 Collateralized Debt Positions (CDPs)
- Lock Bitcoin as collateral to mint stablecoins
- Minimum 150% overcollateralization requirement
- Dynamic fee accrual system with 0.5% annual rate

### ⚡ Risk Management
- Real-time price oracle integration
- Automatic liquidation at 120% collateral ratio
- Minimum vault size requirements for security

### 💰 User Benefits
- Generate liquidity without selling Bitcoin
- Maintain Bitcoin price exposure
- Flexible collateral management
- Transparent fee structure

## Technical Specifications

### Collateralization Requirements
- **Minimum Collateral Ratio**: 150%
- **Liquidation Threshold**: 120%
- **Minimum Vault Size**: 100,000 satoshis
- **Annual Borrowing Fee**: 0.5%

### Core Functions

#### Vault Management
- `initialize-vault`: Create a new collateralized vault
- `generate-stablecoin`: Mint stablecoins against collateral
- `burn-stablecoin`: Repay stablecoins to reduce debt
- `extract-btc-collateral`: Withdraw excess collateral

#### Fee Management
- `settle-borrowing-fees`: Pay accumulated borrowing fees
- Automatic fee accrual based on time elapsed

#### Liquidation System
- `liquidate-undercollateralized-vault`: Liquidate unsafe positions
- Protects protocol from bad debt

## Getting Started

### Prerequisites
- Stacks wallet (Leather, Xverse, etc.)
- Bitcoin for collateral
- Basic understanding of DeFi concepts

### Deployment
1. Deploy the contract to Stacks mainnet/testnet
2. Initialize price oracle with current BTC/USD rate
3. Set appropriate protocol parameters

### Usage Example

```clarity
;; Create a vault with 1 BTC collateral
(contract-call? .vaultcore initialize-vault u100000000)

;; Mint 30,000 stablecoins (assuming $50k BTC price)
(contract-call? .vaultcore generate-stablecoin u30000000000)

;; Check vault status
(contract-call? .vaultcore fetch-vault-info tx-sender)
```

## Security Features

### Oracle Protection
- Price bounds checking (max $10,000 per satoshi)
- Admin-only oracle updates
- Input validation on all price feeds

### Vault Safety
- Overcollateralization requirements
- Liquidation mechanisms
- Minimum vault sizes

### Access Control
- Admin functions restricted to contract owner
- User-specific vault management
- Protected liquidation triggers

## Protocol Parameters

| Parameter | Value | Description |
|-----------|--------|-------------|
| Overcollateral Threshold | 150% | Minimum collateral ratio |
| Danger Zone Threshold | 120% | Liquidation trigger |
| Annual Borrow Fee | 0.5% | Yearly fee on outstanding debt |
| Min Vault Size | 100k sats | Minimum collateral requirement |

## Fee Structure

### Borrowing Fees
- **Rate**: 0.5% annually on outstanding stablecoin debt
- **Accrual**: Calculated per block based on time elapsed
- **Payment**: Can be paid separately or during vault operations

### No Additional Fees
- No minting fees
- No withdrawal fees
- No liquidation penalties for vault owners

## Risk Considerations

### Price Volatility
- Bitcoin price fluctuations affect collateral value
- Users must monitor collateral ratios
- Liquidation risk during market downturns

### Smart Contract Risk
- Code has been thoroughly tested but remains experimental
- Users should understand smart contract limitations
- Always verify contract addresses

## Development

### Testing
```bash
clarinet test
```

### Local Deployment
```bash
clarinet deploy --network testnet
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with comprehensive tests
4. Follow Clarity coding standards

## Audit Status

**Status**: Pending Professional Audit
**Recommendation**: Use with caution on mainnet until audit completion

---

*VaultCore: Unlocking Bitcoin's potential while preserving its value*