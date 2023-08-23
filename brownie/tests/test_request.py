from scripts.deploy import deploy
import random

def test_request():
    (deployer, housePool) = deploy.setup_housePool()
    (tokenId, operator) = deploy.setup_operator(housePool)
    (provider, tokenOwner, token) = deploy.setup_liquidity(housePool)

    betAmount = random.randint(100, 1000)

    token.mint(operator, betAmount, {"from": tokenOwner})
    token.approve(housePool, betAmount, {"from": operator})

    requestParams = (
        tokenId,
        [[[betAmount, 35000, 1, 36]]],
        token.address,
        0,
        "",
        0,
        0
    )

    (requestId) = deploy.new_request(housePool, operator, requestParams)

    return (housePool, requestId, requestParams)

def test_getRequest():
    (housePool, requestId, requestParams) = test_request()

    requestParams = list(requestParams)
    requestParams.pop(6)
    requestParams.pop(5)
    requestParams.pop(4)
    requestParams.pop(3)
    requestParams.append(requestId)
    for v in range(len(requestParams[1])):
        for o in range(len(requestParams[1][v])):
            requestParams[1][v][o] = tuple(requestParams[1][v][o])
    requestParams[1] = tuple(map(tuple, requestParams[1]))
    requestParams = tuple(requestParams)

    assert housePool.getRequest(requestId) == requestParams

def test_totalRequests():
    (deployer, housePool) = deploy.setup_housePool()
    (tokenId, operator) = deploy.setup_operator(housePool)
    (provider, tokenOwner, token) = deploy.setup_liquidity(housePool)

    token.mint(operator, 100000, {"from": tokenOwner})
    token.approve(housePool, 100000, {"from": operator})

    requestParams = (
        tokenId,
        [[[10, 35000, 1, 36]]],
        token.address,
        0,
        "",
        0,
        0
    )

    requestCount = random.randint(1, 25)

    for i in range(requestCount):
        deploy.new_request(housePool, operator, requestParams)

    assert housePool.totalRequests() == requestCount