from scripts.env import env
from brownie import HousePoolDebug, HousePoolMath, HousePoolToken, accounts

class deploy:
    accountNonce = 0

    def new_account():
        deploy.accountNonce += 1
        return accounts[deploy.accountNonce]        

    def setup_housePool():
        deployer = deploy.new_account()
        housePoolMath = HousePoolMath.deploy({"from": deployer})
        housePool = HousePoolDebug.deploy({"from": deployer})
        return (deployer, housePool)
    
    def setup_token():
        tokenOwner = deploy.new_account()
        token = HousePoolToken.deploy(1000000000000000000000000000, {"from": tokenOwner})
        return (tokenOwner, token)

    def setup_operator(housePool):
        operator = deploy.new_account()
        txn = housePool.mintOperator(operator, {"from": operator})
        tokenId = txn.return_value
        return (tokenId, operator)

    def setup_liquidity(housePool):
        (tokenOwner, token) = deploy.setup_token()

        provider = deploy.new_account()
        addAmount = 1000 * (10**18)

        token.mint(provider, addAmount, {"from": tokenOwner})
        token.approve(housePool, addAmount, {"from": provider})

        housePool.addLiquidity(provider, token, addAmount, {"from": provider})

        return(provider, tokenOwner, token)
    
    def new_request(housePool, operator, requestParams):
        txn = housePool.request(requestParams, {"from": operator})
        requestId = txn.return_value

        return (requestId)
    
    def fulfill_request(housePool, requestId, values):
        account = deploy.new_account()
        housePool.fulfillRandomWords(requestId, values, {"from": account})