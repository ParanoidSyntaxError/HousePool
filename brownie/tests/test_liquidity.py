from scripts.deploy import deploy
import random
from brownie import HP20

def test_addLiquidity():
    (deployer, housePool) = deploy.setup_housePool()
    (tokenOwner, token) = deploy.setup_token()

    provider = deploy.new_account()
    addAmount = random.randint(1, 1000)

    token.mint(provider, addAmount, {"from": tokenOwner})
    token.approve(housePool, addAmount, {"from": provider})

    txn = housePool.addLiquidity(provider, token, addAmount, {"from": provider})
    liqudityTokenAmount = txn.return_value

    liquidityToken = HP20.at(housePool.liquidityToken(token))

    assert token.balanceOf(housePool) == addAmount

    assert token.balanceOf(provider) == 0
    assert liquidityToken.balanceOf(provider) == liqudityTokenAmount

    return (housePool, provider, token, liquidityToken, addAmount, liqudityTokenAmount)

def test_removeLiquidity():
    (housePool, provider, token, liquidityToken, addAmount, liqudityTokenAmount) = test_addLiquidity()

    txn = housePool.removeLiquidity(provider, token, liqudityTokenAmount, {"from": provider})
    returnedAmount = txn.return_value

    assert token.balanceOf(housePool) == 0

    assert returnedAmount == addAmount
    assert token.balanceOf(provider) == returnedAmount
    assert liquidityToken.balanceOf(provider) == 0