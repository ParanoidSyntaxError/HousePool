from scripts.deploy import deploy
import random

def test_mintOperator():
    (deployer, housePool) = deploy.setup_housePool()

    minter = deploy.new_account()
    receiver = deploy.new_account()

    txn = housePool.mintOperator(receiver, {"from": minter})
    tokenId = txn.return_value
    
    assert housePool.ownerOf(tokenId) == receiver

def test_totalOperators():
    (deployer, housePool) = deploy.setup_housePool()

    minter = deploy.new_account()
    totalOperators =  random.randint(1, 50)

    for i in range(totalOperators):
        housePool.mintOperator(minter, {"from": minter})

    assert housePool.totalOperators() == totalOperators

