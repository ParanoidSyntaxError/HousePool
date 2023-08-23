from scripts.deploy import deploy
import random
import test_request

def test_getResponse():
    (housePool, requestId, requestParams) = test_request.test_request()

    randomValues = []
    for i in range(len(requestParams[1])):
        randomValues.append(random.randint(0, 2**256 - 1))

    deploy.fulfill_request(housePool, requestId, randomValues)

    assert housePool.getResponse(requestId) == randomValues