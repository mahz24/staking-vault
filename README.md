# Staking Vault (ERC4626)

An ERC4626-compliant tokenized staking vault built with Foundry — deposit an ERC-20 token, receive proportional shares, and earn yield injected by the vault owner. Built to practice production-grade DeFi patterns: standard compliance, share-price manipulation attacks, and access-controlled yield distribution.

**Live on Sepolia**:
- `MockERC20` (test token): [`0xB7f59bD85A5d518a57D2459D672F2041Ab527bCd`](https://sepolia.etherscan.io/address/0xb7f59bd85a5d518a57d2459d672f2041ab527bcd) (verified)
- `StakingVault`: [`0x2F72fd550C7F5861D971c91d31af7e3112075199`](https://sepolia.etherscan.io/address/0x2f72fd550c7f5861d971c91d31af7e3112075199) (verified)

## Overview

Rather than implementing share-price accounting from scratch, this vault extends OpenZeppelin's audited `ERC4626` implementation — the standard interface for tokenized vaults. The focus of this project isn't reinventing vault math; it's understanding how to integrate, configure, and **security-test** a real DeFi standard, including finding and fixing a live vulnerability during development.

## How It Works

- Users deposit an underlying ERC-20 token and receive vault shares (`svTOKEN`) proportional to their share of the pool.
- The vault owner can inject yield via `depositYield(uint256 amount)` — pulling real tokens from their own wallet into the vault (`onlyOwner`, using `SafeERC20.safeTransferFrom`). This grows the vault's total assets, which increases the value of every share proportionally, without any per-user bookkeeping.
- Users redeem shares for their proportional share of the vault's assets at any time.

## Security Finding: Inflation Attack

While testing the classic ERC4626 first-depositor inflation attack (a malicious first depositor donating tokens directly to the vault to manipulate the share price), the **default** OpenZeppelin mitigation (`_decimalsOffset() = 0`) was found to be insufficient in this project's attack test: a victim depositing a reasonable amount after a large donation still received `0` shares.

**Fix**: overrode `_decimalsOffset()` to return `3`, exponentially raising the cost of the attack. Re-running the same test confirms the victim now receives a fair share. Full writeup, including the exact numbers from the failing and passing test runs, is in [`DESIGN.md`](./DESIGN.md#2-inflation-attack-mitigation).

## Tech Stack

- **Solidity** ^0.8.18
- **Foundry** (Forge)
- **OpenZeppelin Contracts** — `ERC4626`, `ERC20`, `Ownable`, `SafeERC20`

## Testing

```bash
forge test
forge coverage
```

- **Unit tests** — setup verification, exact-amount deposit/withdraw, yield distribution across share holders (with documented 1-wei rounding behavior), and access control on `depositYield`.
- **Attack test** — reproduces the first-depositor inflation attack end-to-end; confirms the victim receives a fair, non-zero share after the `_decimalsOffset` fix.
- **Fuzz test** (256 runs) — confirms the vault never allows a withdrawal to exceed its actual token balance, across randomized deposit and yield amounts.

## Getting Started

```bash
git clone https://github.com/mahz24/staking-vault.git
cd staking-vault
forge install
forge build
forge test
```

## Deployment

Deploys both `MockERC20` and `StakingVault` in a single script (the vault's constructor requires the token's address):

```bash
forge script script/DeployVault.s.sol:DeployVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

Requires a `.env` file with `SEPOLIA_RPC_URL`, `PRIVATE_KEY`, and `ETHERSCAN_API_KEY`.

## Known Limitations

- **`MockERC20.mint()` is unrestricted** — anyone can mint unlimited test tokens. Intentional for a testing mock; would be a critical vulnerability in a real token.
- **1 wei rounding** on withdrawals, always in the vault's favor — an intentional side effect of OpenZeppelin's inflation-attack mitigation math, not a bug. See `DESIGN.md` section 6.
- **No withdrawal limits or cooldowns** — open scope decision, not yet implemented.

## Design Decisions

All architectural decisions — vault standard choice, the inflation attack finding and fix, yield mechanism, deployment order, and rounding behavior — are documented in [`DESIGN.md`](./DESIGN.md).

## Author

**Marco Zuñiga** — Full Stack Engineer transitioning into blockchain development, with a background in fintech backend systems (credit flows, payment processing).

[GitHub](https://github.com/mahz24) · [LinkedIn](https://www.linkedin.com/in/marco-zu%C3%B1iga-29b938200)