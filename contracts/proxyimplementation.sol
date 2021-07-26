// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    mapping(address => uint256) private _send_amount;
    mapping(address => uint256) private _timer_start;

    //Modifiable values
    //Tokenomics
    uint256 private _min_sell_amount;
    uint256 public min_sell_pmille = 1;

    //Fees to send to token
    //Fee going to holders
    uint256 public taxFee = 3;
    //Fee going to this contract
    uint256 public otherFee = liquidityfee + marketingfee;

    //Other fee distribution
    uint256 public liquidityfee = 4;
    uint256 public marketingfee = 3;

    //Total fee amounts for normal fee and whale fee
    uint256 public normalfee = taxFee + otherFee;
    uint256 public whalefee = 40;
        

    //Anti whale
    uint256 private _time_limit = 1 hours;
    uint256 private _max_sell_amount;
    uint256 public max_sell_pmille = 10;

    address private immutable _uniswapRouter;

    IERC20 private immutable _token;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    IUniswapV2Pair private immutable _uniswapV2Pair;

    event SwapAndLiquify(uint256, uint256);

    constructor(
        address token_address,
        address uniswap_router,
        address uniswap_pair
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MARKETING_WITHDRAW_ROLE, _msgSender());
        _setupRole(JANITOR_ROLE, _msgSender());
        _setupRole(FEE_ROLE, _msgSender());
        _setupRole(TOKEN_ROLE, token_address);
        _uniswapRouter = uniswap_router;
        _token = IERC20(token_address);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(uniswap_router);
        //Create a uniswap pair for this new token
        // address tmpuniswapV2Pair =
        //     IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
        //         tokenaddress,
        //         _uniswapV2Router.WETH()
        //     );
        _max_sell_amount =
            (IERC20(token_address).totalSupply() * max_sell_pmille) /
            1000;
        _min_sell_amount =
            (IERC20(token_address).totalSupply() * min_sell_pmille) /
            1000;
        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        _uniswapV2Pair = IUniswapV2Pair(uniswap_pair);
        uniswapV2Pair = uniswap_pair;
    }

    //Anti whale function
    //Cant sell more than x tokens within 3 hours.
    function preTransfer(
        address sender,
        address receiver,
        uint256 amount,
        bool takefee
    ) external override onlyRole(TOKEN_ROLE) returns (uint256 newTaxFee, uint256 newOtherFee, bool _takFee) {
        require(
            hasRole(TOKEN_ROLE, msg.sender),
            "You are not allowed to call this function!"
        );
        newTaxFee = taxFee;
        newOtherFee = otherFee;
        if(!takefee){
            return(taxFee, otherFee, takefee);
        }
        else if (receiver == uniswapV2Pair) {

            if (block.timestamp >= (_timer_start[sender] + _time_limit)) {
                _timer_start[sender] = block.timestamp;
                _send_amount[sender] = 0;
            }
            //Make check of send amount is bigger than max sell amount to avoid underflow error in next if
            if(_send_amount[sender] >= _max_sell_amount){
                //Calculate new fee amount
                (newTaxFee, newOtherFee) = calculateWhaleFee(0, amount, amount);
            }
            else if(amount > (_max_sell_amount - _send_amount[sender])){
                //Get amount that is taxed with normal fee and whalefee
                uint256 normalFeeAmount = _max_sell_amount - _send_amount[sender];
                uint256 whaleFeeAmount = amount - normalFeeAmount;
                (newTaxFee, newOtherFee) = calculateWhaleFee(normalFeeAmount, whaleFeeAmount, amount);

            }
            _send_amount[sender] = _send_amount[sender] + amount;
        }
        return (newTaxFee, newOtherFee, takefee);
    }

    /**
     * @dev Calculate fee, based on amount that is taxed with whale fee and the amount that is taxed with the normalfee.
     * NormalFee amount can be 0
     * Returns taxFee and otherFee
     */
    function calculateWhaleFee(uint256 normalFeeAmount, uint256 whaleFeeAmount, uint256 totalAmount) private view returns(uint256 newtaxFee, uint256 newotherFee){
        require(whaleFeeAmount > 0, 'Whale fee amount must be bigger than 0!');
        require(totalAmount > 0, 'Total amount must be bigger than 0!');
        //Check if normalFeeAmount is over 0 to avoid errors
        normalFeeAmount = normalFeeAmount > 0 ? normalFeeAmount * (taxFee + otherFee) / 100 : 0;
        whaleFeeAmount = whaleFeeAmount * whalefee / 100;
        uint256 totalFee = (normalFeeAmount + whaleFeeAmount) * 100 / totalAmount;
        newtaxFee = totalFee * taxFee / totalFee; 
        newotherFee = totalFee * otherFee / totalFee;
        return (newtaxFee, newotherFee);
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
    function postTransfer(address sender, address reciever, uint256 amount, bool takefee) external override onlyRole(TOKEN_ROLE){
        uint256 balance = _token.balanceOf(address(this));
        //Dont sell if collected amount of tokens is very small and dont sell more than a max amount
        if (balance < _min_sell_amount) {
            return;
        }

        if (balance > _max_sell_amount) {
            balance = _max_sell_amount;
        }
        
        // Get amount of tokens not to swap
        uint256 liquidityTokenAmount = ((balance * liquidityfee) / otherFee) / 2;
        uint256 swapamount = balance - liquidityTokenAmount;

        //Approve the tokens to swap
        _token.approve(_uniswapRouter, swapamount);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(swapamount);

        uint256 newBalance = address(this).balance - initialBalance;
        // how much ETH did we just swap into?

        // Find liquidity part of swap
        uint256 liquidityETH =
            (newBalance * liquidityfee) / (otherFee * 2);

        //Everything left over just goes to other fees or is included in next swap
        //Anti whale system should reduce this effect
        addLiquidity(liquidityTokenAmount, liquidityETH);

        // add liquidity to uniswap
        emit SwapAndLiquify(liquidityTokenAmount, liquidityETH);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(_token);
        path[1] = uniswapV2Router.WETH();

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(_token),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    //Withdraw liquidity in case of emergency
    function withdrawLiquidity(address receiver)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 balance = _uniswapV2Pair.balanceOf(address(this));
        _uniswapV2Pair.transfer(receiver, balance);
    }

    function modifyAntiWhale(uint256 time_min, uint256 max_pmille, uint256 fee)
        public
        onlyRole(JANITOR_ROLE)
    {
        require(fee < 49, 'The fee is too high!');
        _time_limit = time_min * 1 minutes;
        _max_sell_amount = (_token.totalSupply() * max_pmille) / 1000;
        max_sell_pmille = max_pmille;
        whalefee = fee;
    }

    function withdrawMarketing(address payable receiver, uint256 amount)
        public
        onlyRole(MARKETING_WITHDRAW_ROLE)
    {
        require(amount > 0, "You need to send more than 0!");
        require(amount <= address(this).balance, 'The contract balance is too low');
        (bool success, ) = receiver.call{value:amount}("");
        require(success, 'Error sending BNB to sender');
    }

    function withdrawMarketingAll(address payable receiver)
        public
        onlyRole(MARKETING_WITHDRAW_ROLE)
    {
        (bool success, ) = receiver.call{value:address(this).balance}("");
        require(success, 'Error sending BNB to sender');
    }

    //Update fees for contract
    function updateFees(
        uint256 tax,
        uint256 marketing,
        uint256 liquidity
    ) public onlyRole(FEE_ROLE) {
        require((tax + marketing + liquidity) < 20, 'The normal fee cant be higher than 20%!');
        taxFee = tax;
        marketingfee = marketing;
        liquidityfee = liquidity;
        otherFee = marketingfee + liquidityfee;
        normalfee = taxFee + otherFee;
    }

    //Withdraw tokens, can be vanurable to reentrancy attacks, but doesn't matter becouse of onlyOwner
    function emergencyWithdraw(uint256 amount, address token) public onlyRole(JANITOR_ROLE){
        require(amount > 0, 'You cant withdraw 0');
        require(token != address(_token), 'You cant withdraw the token manually from this contract!');
        IERC20 tokenobj = IERC20(token);
        require(amount >= tokenobj.balanceOf(address(this)), 'The contract balance is too low');
        tokenobj.transfer(msg.sender, amount);
    }
}
