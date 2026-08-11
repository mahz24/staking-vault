# Design Decisions — Staking Vault

## 1. Vault Standard: ERC4626 vs Custom Implementation
**Decision**: Extend OpenZeppelin's `ERC4626` rather than implement share
accounting from scratch.
**Why**: ERC4626 is the standard interface for tokenized vaults, enabling
interoperability with the broader DeFi ecosystem. OpenZeppelin's
implementation is audited and includes built-in mitigation for the
first-depositor inflation attack (see section 2), which is non-trivial to
get right when implemented manually.
**Trade-off accepted**: less hands-on practice writing share-price math from
scratch, in exchange for building on a battle-tested standard — the same
trade-off any production engineering decision would make.

## 2. Inflation Attack Mitigation
**Issue**: A malicious first depositor can donate assets directly to the
vault's balance (bypassing `deposit()`) to inflate the assets-per-share ratio,
causing later depositors' shares to round down to zero and effectively
donating their deposit to the attacker.
**Mitigation**: OpenZeppelin's ERC4626 implementation uses a virtual
offset in its share/asset conversion math, making the attack economically
unviable without requiring special-casing the first deposit manually.
**Verification plan**: a dedicated test will simulate a donation attack
(direct token transfer to the vault before any real deposit) to confirm a
subsequent legitimate depositor still receives a fair share of assets.

## 3. Underlying Asset: Mock ERC-20
**Decision**: Deploy a custom `MockERC20` with a public, unrestricted `mint()`
function, rather than using an existing testnet token.
**Why**: Full control over token supply for testing, no dependency on
third-party faucets or their rate limits.
**Known limitation (intentional, test-only)**: `mint()` has no access
control — anyone can mint unlimited tokens. This is acceptable and by design
for a mock testing token; it would be a critical vulnerability in a
production ERC-20.

## 4. Deployment Order
**Decision**: Deploy `MockERC20` first, then `StakingVault`, in a single
script — the vault's constructor requires the token's address.
**Why**: Real dependency, not an arbitrary ordering choice — `ERC4626`'s
constructor takes `IERC20 asset_`, which must already exist on-chain.

## Open / Upcoming Decisions
- [ ] Yield generation mechanism (how does the vault's asset balance grow over time?)
- [ ] Withdrawal limits or cooldowns, if any
- [ ] Reentrancy protection strategy for any custom logic added on top of ERC4626