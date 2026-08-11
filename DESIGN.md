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
offset in its share/asset conversion math (`_decimalsOffset()`).
**Finding**: The default offset (`0`) was insufficient — a dedicated attack
test (`testInflationAttackDoesNotStealVictimFunds`) confirmed a victim could
still receive `0` shares when the attacker's donation was large relative to
the victim's deposit (e.g. a 10,000-token donation against a 5,000-token
legitimate deposit). OpenZeppelin's own documentation confirms the default
offset makes the attack *unprofitable* for the attacker, but does not
guarantee a fair share price for every victim in every scenario.
**Resolution**: Overrode `_decimalsOffset()` to return `3`, exponentially
raising the donation required to manipulate share price. Re-running the
attack test with this change confirms the victim now receives a fair,
non-zero share of the vault.
**Verification**: `test/unit/StakingVaultTest.t.sol::testInflationAttackDoesNotStealVictimFunds`

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

## 5. Yield Mechanism
**Decision**: Owner-only `depositYield(uint256 amount)` function that pulls
real tokens from the owner's wallet into the vault via `safeTransferFrom`
(requiring prior `approve()` from the owner), rather than mathematically
simulating yield without backing tokens.
**Why**: `ERC4626.totalAssets()` reflects the vault's real token balance. A
purely mathematical/time-based yield formula would create a promise the
contract can't keep — accounting for "yield" that has no real tokens behind
it, causing withdrawals to fail once someone tries to redeem more than the
vault actually holds.
**Why owner-only**: Unrestricted yield injection would functionally be the
same attack surface as the inflation attack (section 2) — anyone manipulating
the vault's asset balance outside of controlled, auditable logic. Routing it
through an explicit, event-emitting, access-controlled function keeps yield
injection traceable and intentional.
**Flow**: owner calls `token.approve(vaultAddress, amount)` on the underlying
asset, then `vault.depositYield(amount)` — a standard two-step ERC-20
authorization pattern.

## Open / Upcoming Decisions
- [ ] Withdrawal limits or cooldowns, if any
- [ ] Reentrancy protection strategy for any custom logic added on top of ERC4626