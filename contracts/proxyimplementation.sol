// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/uniswapinterface.sol";
import "./interfaces/proxyinterface.sol";

contract ProxyFunctionsV2 is Context, IProxyContract, AccessControlEnumerable {
    bytes32 public constant MARKETING_WITHDRAW_ROLE =
        keccak256("MARKETING_WITHDRAW_ROLE");
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");

    bytes32 public constant JANITOR_ROLE = keccak256("JANITOR_ROLE");

    bytes32 public constant FEE_ROLE = keccak256("FEE_ROLE");

    mapping(address => uint256) public send_amount;
    mapping(address => uint256) public timer_start;

    //Modifiable values
    //Tokenomics
    uint256 public min_sell_amount = 1000000000000 * 10**9;
    uint256 public max_sell_amount = 10000000000000 * 10**9;

    //Fees to send to token
    //Fee going to holders
    uint256 public taxFee = 4;
    //Fee going to this contract
    uint256 public otherFee = liquidityfee + marketingfee;

    //Other fee distribution
    uint256 public liquidityfee = 4;
    uint256 public marketingfee = 3;

    //Total fee amounts for normal fee and whale fee
    uint256 public normalfee = taxFee + otherFee;
    uint256 public whalefee = 40;

    //Sell fee on release
    uint256 public releaseFee = 40;
    bool public releaseFeeEnabled = false;
    uint256 public releaseFeeStartTime = 0;
    uint256 public releaseFeeReduction = 5;
    uint256 public releaseFeeReductionTime = 24 hours;

    //Anti whale
    uint256 public time_limit = 12 hours;

    address private immutable _uniswapRouter;

    IERC20 private immutable _token;
    IERC20 private immutable _pairtoken;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    IUniswapV2Pair private immutable _uniswapV2Pair;

    event SwapAndLiquify(uint256, uint256);

    constructor(
        address token_address,
        address uniswap_router,
        address uniswap_pair,
        address pair_token
    ) {
        require(token_address != address(0x0));
        require(uniswap_router != address(0x0));
        require(uniswap_pair != address(0x0));
        require(pair_token != address(0x0));
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MARKETING_WITHDRAW_ROLE, _msgSender());
        _setupRole(JANITOR_ROLE, _msgSender());
        _setupRole(FEE_ROLE, _msgSender());
        _setupRole(TOKEN_ROLE, token_address);
        _uniswapRouter = uniswap_router;
        _token = IERC20(token_address);
        _pairtoken = IERC20(pair_token);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            uniswap_router
        );
        //Create a uniswap pair for this new token
        // address tmpuniswapV2Pair =
        //     IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
        //         tokenaddress,
        //         _uniswapV2Router.WETH()
        //     );
        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        _uniswapV2Pair = IUniswapV2Pair(uniswap_pair);
        uniswapV2Pair = uniswap_pair;
    }

    /**
     * @dev Function making pre transfer checks.
     * Anti whale system that sets fee t
     */
    function preTransfer(
        address sender,
        address receiver,
        uint256 amount,
        bool takefee
    )
        external
        override
        onlyRole(TOKEN_ROLE)
        returns (
            uint256 newTaxFee,
            uint256 newOtherFee,
            bool _takFee
        )
    {
        require(
            hasRole(TOKEN_ROLE, msg.sender),
            "You are not allowed to call this function!"
        );
        newTaxFee = taxFee;
        newOtherFee = otherFee;
        if (!takefee) {
            return (taxFee, otherFee, takefee);
        }
        //What if there is another pair?
        //Add pair adresses to white list and take max fee for everything else?
        else if (receiver == uniswapV2Pair) {
            (newTaxFee, newOtherFee) = getReleaseFee();
            if (newTaxFee + newOtherFee <= taxFee + otherFee) {
                releaseFeeEnabled = false;
            }
            if (block.timestamp >= (timer_start[sender] + time_limit)) {
                timer_start[sender] = block.timestamp;
                send_amount[sender] = 0;
            }
            //Make check of send amount is bigger than max sell amount to avoid underflow error in next if
            if ((newTaxFee + newOtherFee) < whalefee) {
                if (send_amount[sender] >= max_sell_amount) {
                    //Calculate new fee amount
                    (newTaxFee, newOtherFee) = calculateWhaleFee(
                        0,
                        amount,
                        amount
                    );
                } else if (amount > (max_sell_amount - send_amount[sender])) {
                    //Get amount that is taxed with normal fee and whalefee
                    uint256 normalFeeAmount = max_sell_amount -
                        send_amount[sender];
                    uint256 whaleFeeAmount = amount - normalFeeAmount;
                    (newTaxFee, newOtherFee) = calculateWhaleFee(
                        normalFeeAmount,
                        whaleFeeAmount,
                        amount
                    );
                }
            }
            send_amount[sender] = send_amount[sender] + amount;
        }
        return (newTaxFee, newOtherFee, takefee);
    }

    /**
     * @dev Calculate fee, based on amount that is taxed with whale fee and the amount that is taxed with the normalfee.
     * NormalFee amount can be 0
     * Returns taxFee and otherFee
     */
    function calculateWhaleFee(
        uint256 normalFeeAmount,
        uint256 whaleFeeAmount,
        uint256 totalAmount
    ) private view returns (uint256 newtaxFee, uint256 newotherFee) {
        require(whaleFeeAmount > 0, "Whale fee amount must be bigger than 0!");
        require(totalAmount > 0, "Total amount must be bigger than 0!");
        //Check if normalFeeAmount is over 0 to avoid errors
        normalFeeAmount = normalFeeAmount > 0
            ? (normalFeeAmount * (taxFee + otherFee)) / 100
            : 0;
        whaleFeeAmount = (whaleFeeAmount * whalefee) / 100;
        uint256 totalFee = ((normalFeeAmount + whaleFeeAmount) * 100) /
            totalAmount;
        newtaxFee = (totalFee * taxFee) / totalFee;
        newotherFee = (totalFee * otherFee) / totalFee;
        return (newtaxFee, newotherFee);
    }

    function getReleaseFee()
        public
        view
        returns (uint256 releaseTaxFee, uint256 releaseOtherFee)
    {
        if (!releaseFeeEnabled || releaseFeeStartTime == 0) {
            return (taxFee, otherFee);
        }
        uint256 timeSinceStart = block.timestamp - releaseFeeStartTime;
        uint256 reductionFactor = timeSinceStart / releaseFeeReductionTime;
        if ((releaseFeeReduction * reductionFactor) >= releaseFee) {
            return (taxFee, otherFee);
        }
        uint256 newFee = releaseFee - (reductionFactor * releaseFeeReduction);
        if (newFee <= (taxFee + otherFee)) {
            return (taxFee, otherFee);
        }
        releaseTaxFee = (newFee * taxFee) / (taxFee + otherFee);
        releaseOtherFee = (newFee * otherFee) / (taxFee + otherFee);
        return (releaseTaxFee, releaseOtherFee);
    }

    //Get pair function since interface cant contain a variable
    function getPair() external view override returns (address) {
        return uniswapV2Pair;
    }

    /**
     * @dev Contract needs to receive/hold BNB.
     */
    receive() external payable {}

    /**
     * @dev Function is called after tokens are send to trade to bnb and add liquidity
     * Inputs are sender, reciever, amount and if fee is taken. No every variable is used, but can be useful in future modifications
     */
    function postTransfer(
        address sender,
        address reciever,
        uint256 amount,
        bool takefee
    ) external override onlyRole(TOKEN_ROLE) {
        uint256 balance = _token.balanceOf(address(this));
        //Dont sell if collected amount of tokens is very small and dont sell more than a max amount
        if (balance < min_sell_amount) {
            return;
        }

        if (balance > max_sell_amount) {
            balance = max_sell_amount;
        }

        // Get amount of tokens not to swap
        uint256 liquidityTokenAmount = ((balance * liquidityfee) / otherFee) /
            2;
        uint256 swapamount = balance - liquidityTokenAmount;

        uint256 initialBalance = _pairtoken.balanceOf(address(this));

        swapTokensForToken(swapamount);

        uint256 newBalance = _pairtoken.balanceOf(address(this)) -
            initialBalance;
        // how much ETH did we just swap into?

        // Find liquidity part of swap
        uint256 liquidityPairAmount = (newBalance * liquidityfee) /
            (otherFee * 2);

        //Everything left over just goes to other fees or is included in next swap
        //Anti whale system should reduce this effect
        addLiquidity(liquidityTokenAmount, liquidityPairAmount);

        // add liquidity to uniswap
        emit SwapAndLiquify(liquidityTokenAmount, liquidityPairAmount);
    }

    function swapTokensForToken(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> token
        _token.approve(_uniswapRouter, tokenAmount);
        address[] memory path = new address[](2);
        path[0] = address(_token);
        path[1] = address(_pairtoken);

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of Tokens
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 pairAmount) private {
        // approve token transfer to cover all possible scenarios
        _token.approve(_uniswapRouter, tokenAmount);
        _pairtoken.approve(_uniswapRouter, pairAmount);
        // add the liquidity
        uniswapV2Router.addLiquidity(
            address(_token),
            address(_pairtoken),
            tokenAmount,
            0,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function withdrawLiquidity(address receiver)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(receiver != address(0x0), "Withdraw address cant be 0!");
        uint256 balance = _uniswapV2Pair.balanceOf(address(this));
        _uniswapV2Pair.transfer(receiver, balance);
    }

    function modifyAntiWhale(uint256 time_min, uint256 fee)
        public
        onlyRole(JANITOR_ROLE)
    {
        require(fee < 49, "The fee is too high!");
        time_limit = time_min * 1 minutes;
        whalefee = fee;
    }

    function changeMaxSell(uint256 max) public onlyRole(JANITOR_ROLE) {
        require(
            max > min_sell_amount,
            "Max amount needs to be bigger than min sell amount"
        );
        require(
            max < _pairtoken.totalSupply(),
            "Max amount needs to be less than total supply"
        );
        max_sell_amount = max;
    }

    function changeMinSell(uint256 min) public onlyRole(JANITOR_ROLE) {
        require(
            min < max_sell_amount,
            "Max amount needs to be bigger than min sell amount"
        );
        min_sell_amount = min;
    }

    function withdrawMarketing(address payable receiver, uint256 amount)
        public
        onlyRole(MARKETING_WITHDRAW_ROLE)
    {
        require(receiver != address(0x0), "Withdraw address cant be 0!");
        require(amount > 0, "You need to send more than 0!");
        require(
            amount <= _pairtoken.balanceOf(address(this)),
            "The contract balance is too low"
        );
        _pairtoken.transfer(receiver, amount);
    }

    function withdrawMarketingAll(address payable receiver)
        public
        onlyRole(MARKETING_WITHDRAW_ROLE)
    {
        require(receiver != address(0x0), "Withdraw address cant be 0!");
        _pairtoken.transfer(receiver, _pairtoken.balanceOf(address(this)));
    }

    //Update fees for contract
    function updateFees(
        uint256 tax,
        uint256 marketing,
        uint256 liquidity
    ) public onlyRole(FEE_ROLE) {
        require(
            (tax + marketing + liquidity) < 20,
            "The normal fee cant be higher than 20%!"
        );
        taxFee = tax;
        marketingfee = marketing;
        liquidityfee = liquidity;
        otherFee = marketingfee + liquidityfee;
        normalfee = taxFee + otherFee;
    }

    function updateReleaseFee(
        uint256 fee,
        uint256 reduction,
        uint256 reductionTime
    ) public onlyRole(FEE_ROLE) {
        require(
            releaseFeeStartTime == 0,
            "This can only be done before launch!"
        );
        require(fee <= 45, "The fee cant be higher than 45%!");
        require(
            releaseFee > releaseFeeReduction,
            "The reduction cant be higher than the fee!"
        );
        require(
            reductionTime < 120 hours,
            "The max reduction time pr step is 5 days!"
        );
        releaseFee = fee;
        releaseFeeReduction = reduction;
        releaseFeeReductionTime = reductionTime;
    }

    function disableReleaseFee() public onlyRole(FEE_ROLE) {
        releaseFeeEnabled = false;
    }

    function StartReleaseFee() public onlyRole(FEE_ROLE) {
        require(releaseFeeStartTime == 0, "You can only do this once");
        releaseFeeEnabled = true;
        releaseFeeStartTime = block.timestamp;
    }

    //Withdraw tokens, can be vanurable to reentrancy attacks, but doesn't matter becouse of onlyOwner
    function emergencyWithdraw(uint256 amount, address token)
        public
        onlyRole(JANITOR_ROLE)
    {
        require(amount > 0, "You cant withdraw 0");
        require(
            token != address(_token),
            "You cant withdraw the token manually from this contract!"
        );
        require(token != address(_pairtoken));
        IERC20 tokenobj = IERC20(token);
        require(
            amount >= tokenobj.balanceOf(address(this)),
            "The contract balance is too low"
        );
        tokenobj.transfer(msg.sender, amount);
    }
}
