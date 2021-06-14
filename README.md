## DCA Vaults

## Problem
Let's say you want to Dollar-Cost-Average into a coin, you could do this by manually buying it every day but this has some problems:
- If you want to farm with your coins, every time you want to sell you'll need to withdraw some coins from a farm, swap them and deposit the other ones onto another farm, which makes the whole operation quite gas-intensive
- You have to perfom this operation every day, which requires time, attention and it's easy to forget. You could also set up a bot to do this for you but then you need to give this bot access to your coins, which is quite insecure

These are the problems I was facing, so the logical conclusion was to delegate this to some protocol to do it for me. However, the only protocol with DCA functionality at the moment seems to be Inverse, but they don't have the specific vault I want (ETH -> stablecoin) and it's not possible to set an individual DCA rate.

Because of this I decided to build my own vault, which initially was meant be just for me, it's main purpose being to limit the trust on my bot. However later I decided to open it to more people since we can socialize gas costs this way.

The advantages of this vault are:
- Money always stays in yearn's yield bearing vaults
- Each user can set their own DCA rate
- All gas costs are constant irrespective of the number of depositors of the vault. These will all be initially paid by me (maybe in version 2 of the vault I'll look into socializing these costs but the current contract doesn't allow for any loss from the depositors)
- You don't have to do anything, everything is automated

Furthermore, eventually I want to deploy an algorithm that tries to improve a little on when to make the swap (it only needs to be better against the baseline of "buy at 12AM every day"). This is something that wouldn't make sense if it was only me but if we can socialize this it starts being worth it.

## Risks
### Front-running the swap
Everything is trustless and the contracts are unruggable (non-upgradeable, all money flows are fixed, there's no privileged party...).

However, the sell operation is restricted to once per day and can only be performed by a set of addresses authorized by me. The addresses authorized (or anyone in case this had no access restrictions) could abuse this to sandwich the swap and extract money from it. This attack has some limitations:
- It will only be profitable if the size of the swap is higher than 0.3% of total pool size. With today's values the swap would need to be for more than 700k$ for this to be profitable, and this would only be a daily DCA, meaning that the total pool would need to be quite big.
- We limit the maximum possible price manipulation by checking the price of the pool against a TWAP from UNIv3 and rejecting the tx if the price difference is higher than 1%.

These two limitations mean that it's very unlikely that this will be profitable (maybe even impossible, I haven't done the math), and even if it is, the maximum loss will always be limited to 1%. Furthemore, this can only happen if our bots get hacked or we turn malicious, which we are incentivized against.

### No swap transaction is made
In the scenario where nobody executes the daily swap transaction within a day it's not clear what we should do. Making it possible to execute the swaps later would give us a lot of power and defeat the purpose of DCA, so instead we halt the vault and forbid any future swaps. Once the vault enters this state, new deposits will be forbidden and users will just be able to withdraw the tokens they had at the time it was halted.

In other words, we have the power to halt the vault at any time.

### Yearn withdraw slippage
When withdrawing from a yearn vault it's possible that a loss is realized. This is something we do when executing the swap so we limit this loss to 1%. One consequence of this is that if the losses we could incur stay higher than 1% for a period of time longer than a day it will be impossible to execute the daily swap and the vault will be halted, thus stopping any new swaps.

### Risks inherited from the protocols we use
- Yearn yDAI and yWETH vaults
- Sushiswap DAI-ETH pair
- Uniswap v3 DAI-ETH as an on-chain oracle

## Code
```
  npx hardhat accounts
  npx hardhat compile
  npx hardhat test
  npx hardhat node
  node scripts/sample-script.js
  npx hardhat help
  
  npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS
```