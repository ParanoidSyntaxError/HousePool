# House Pool

A decentralized gaming and betting house liquidity pool.

## Liquidity providers

Liquidity providers can add any token to the houses liquidity and are intitled to the house’s earnings in proportion to the size of their contribution.

## Players

Players can play betting games with a very low house edge, and with any ERC20 standard token.

## Developers

Developers can use the houses liquidity to build their own games, if they have a funded Chainlink VRF V2 subscription, and the odds give the house an edge of at least 1%. 

The difference between the bet’s true odds, and payout odds, minus the houses mandatory edge, is credited to the requesting address, regardless of the bet’s outcome.

### Example:

In a regular spin of roulette roulette, the odds of winning on a straight up bet are 1/37. However, a winning player is only payed 35/1 odds. This gives the house a 2.7% edge.

Using this example with House Pool, the roulette provider would be payed 1.7% of the players wager, regardless if the player wins or loses.
