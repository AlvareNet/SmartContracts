// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

//Imports from openzeppelin library
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/proxyinterface.sol";

contract AlvareNet is Context, IERC20, AccessControlEnumerable {

    //using safe math to not rewrite even though its not needed anymore
    using SafeMath for uint256;

    using Address for address;

    //Create roles for the contract
    bytes32 public constant TOCENOMICS_ROLE = keccak256("TOCENOMICS_ROLE");
    bytes32 public constant JANITOR_ROLE = keccak256("JANITOR_ROLE");
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");

    //Mapping of token and reflection values
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    uint256 private _tOwnedExcluded;
    uint256 private _rOwnedExcluded;

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;

    //Calculate initial total supply and total reflection value
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000000000000 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    //Proxy and antiwhale disabled by default since the contract can first be added after token creation
    bool public proxyfee = false;
    bool public proxyenabled = false;

    //Define initial contract settings
    string private constant _name = "AlvareNET";
    string private constant _symbol = "ALVN";
    uint8 private constant _decimals = 9;

    uint256 public taxFee = 4;
    uint256 private _previousTaxFee = taxFee;

    uint256 public otherFee = 7;
    uint256 private _previousOtherFee = otherFee;

    uint256 public constant maxFeeTotal = 20;

    address public proxycontract;

    bool private _inTransfer = false;

    modifier lockTheSwap {
        _inTransfer = true;
        _;
        _inTransfer = false;
    }

    //TODO What to do with initial fee contract? should it be created from here?
    constructor() {
        //initially set the _msgsender to otherFee contract, can't work once we are working with an interface
        //Send total token amount to contract creator
        _rOwned[_msgSender()] = _rTotal;
        //Give contract creator all roles defined in contract
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TOCENOMICS_ROLE, _msgSender());
        _setupRole(JANITOR_ROLE, _msgSender());
        //
        proxycontract = _msgSender();
        //exclude owner and this contract from transfer fee
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /**
     * @dev Get the token name
     *
     */
    function name() public pure returns (string memory) {
        return _name;
    }

    /**
     * @dev Get the token symbol
     *
     */
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Get the decimals for token
     *
     */
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Get the total token supply
     *
     */
    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev Get the balance of an address
     *
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev Transfer function called by wallet owner
     *
     */
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Show how much spender address is able to take from owner wallet
     *
     */
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approve spender address to take tokens from sender accounts wallet
     *
     */
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    //TODO proxy contract approve!!!
    /**
     * @dev Transfer from address, can be called from different address then sender
     *
     * The address calling this function needs to be approved to take this amount of tokens from the sender address if it isnt the sender
     *
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Decrease the allowance amount, that has been set by the approve function(or this function)
     *
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @dev Decrease the allowance amount, that has been set by the approve or increaseAllowance function
     *
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Check if address is excluded from redistribution rewards
     *
     */
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    /**
     * @dev Get the total fee amount in tokens
     *
     */
    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    /**
     * @dev Set contract that recieves other fee
     *
     */
    function setproxyContract(address contractaddress)
        public onlyRole(DEFAULT_ADMIN_ROLE)
    {
        proxycontract = contractaddress;
        _isExcludedFromFee[contractaddress] = true;
        _isExcluded[contractaddress] = true;
    }

    /**
     * @dev Disable or enable call of external proxy functions
     *
     */
    function changeProxyState(bool newstate) public onlyRole(TOCENOMICS_ROLE){
        proxyenabled = newstate;
    }

    /**
     * @dev Enable or disable using fees supplied by proxy contract
     *
     */
    function changeproxyfeeState(bool newstate) public onlyRole(TOCENOMICS_ROLE){
        proxyfee = newstate;
    }

    /**
     * @dev Change reflected amount to tokens
     *
     */
    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    /**
     * @dev Get the current reflection value from token amount
     *
     */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
     * @dev Get token amount based on reflection value
     *
     */
    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    /**
     * @dev Exclude account from redistribution reward
     *
     * Address needs to be included in rewards before
     *
     */
    function excludeFromReward(address account) public onlyRole(JANITOR_ROLE){
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _tOwnedExcluded = _tOwnedExcluded.add(_tOwned[account]);
        _rOwnedExcluded = _rOwnedExcluded.add(_rOwned[account]);
        _isExcluded[account] = true;
    }

    /**
     * @dev Include account in redistribution reward
     *
     * Address needs to be excluded from rewards before
     *
     */
    function includeInReward(address account) public onlyRole(JANITOR_ROLE){
        require(_isExcluded[account], "Account is already included");
        _tOwnedExcluded = _tOwnedExcluded.sub(_tOwned[account]);
        _rOwnedExcluded = _rOwnedExcluded.sub(_rOwned[account]);
        _tOwned[account] = 0;
        _isExcluded[account] = false;
    }

    /**
     * @dev Exlude address in transferfees
     *
     * Address needs to be included in fees before
     *
     */
    function excludeFromFee(address account) public onlyRole(JANITOR_ROLE){
        _isExcludedFromFee[account] = true;
    }

    /**
     * @dev Include address in transferfees
     *
     * Address needs to be excluded from fees before
     *
     */
    function includeInFee(address account) public onlyRole(JANITOR_ROLE){
        _isExcludedFromFee[account] = false;
    }

    /**
     * @dev Set the the value of the fee that is redistributed between holders
     *
     * Input is in percent
     *
     */
    function setTaxFeePercent(uint256 fee) public onlyRole(TOCENOMICS_ROLE) {
        require(fee.add(otherFee) <= maxFeeTotal, "The total fee cant be higher than 20%");
        taxFee = fee;
    }

    /**
     * @dev Set the the value of other fees in total
     *
     * Input is in percent
     *
     */
    function setOtherFeeFeePercent(uint256 fee) public onlyRole(TOCENOMICS_ROLE) {
        require(fee.add(taxFee) <= maxFeeTotal, "The total fee cant be higher than 20%");
        otherFee = fee;
    }

    /**
     * @dev Check if address is excluded from transfer fees
     *
     */
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @dev Calculate new reflection values and token values based on fee send
     *
     * Subtract fee from total reflection amount and add fee to total token fee amount
     *
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    /**
     * @dev Get token and reflection values
     *
     * Function that combines the following to functions
     *
     */
    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tOtherFee) =
            _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) =
            _getRValues(tAmount, tFee, tOtherFee, _getRate());
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tOtherFee
        );
    }

    /**
     * @dev Get token values
     *
     * Calculate token amounts for transaction that goes to fees and how much is supposed to be send
     *
     */
    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tOtherFee = calculateOtherFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tOtherFee);
        return (tTransferAmount, tFee, tOtherFee);
    }

    /**
     * @dev Get token reflection values
     *
     * Reflection amount of tokens to get how much is subtracted for fees and supposed to be send
     *
     */
    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tOtherFee,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rOtherFee = tOtherFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rOtherFee);
        return (rAmount, rTransferAmount, rFee);
    }

    /**
     * @dev Get current rate between token ammount and refelction amount
     *
     * Is used to calculate what the current reflection amount is worth in actual tokens.
     *
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    //

    /**
     * @dev Internal function to calculate current supply based on token amounts and reflected amounts for not excluded adresses
     *
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if(_rOwnedExcluded > rSupply || _tOwnedExcluded > tSupply){
            return (_rTotal, _tTotal);
        }
        rSupply = rSupply.sub(_rOwnedExcluded);
        tSupply = tSupply.sub(_tOwnedExcluded);
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
     * @dev Internal function to send other fee amounts to proxy contract
     *
     */
    function _takeOtherFee(uint256 tOtherFee, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rOtherFee = tOtherFee.mul(currentRate);
        _rOwned[proxycontract] = _rOwned[proxycontract].add(
            rOtherFee
        );
        if (_isExcluded[proxycontract]){
            _tOwned[proxycontract] = _tOwned[proxycontract]
                .add(tOtherFee);
            _tOwnedExcluded = _tOwnedExcluded.add(tOtherFee);
            _rOwnedExcluded = _rOwnedExcluded.add(rOtherFee);
                }
        emit Transfer(sender, proxycontract, tOtherFee);
    }

    /**
     * @dev Helper functions to calculate fees
     *
     */
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(taxFee).div(10**2);
    }

    function calculateOtherFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(otherFee).div(10**2);
    }

    /**
     * @dev Internal functions to temporary remove fee during one transaction
     *
     *  Set fee to 0 during one transaction to make it simpler to calculate transfer values
     *
     */
    function removeAllFee() private {
        if (taxFee == 0 && otherFee == 0) return;

        _previousTaxFee = taxFee;
        _previousOtherFee = otherFee;

        taxFee = 0;
        otherFee = 0;
    }

    function restoreAllFee() private {
        taxFee = _previousTaxFee;
        otherFee = _previousOtherFee;
    }

    /**
     * @dev Approve other address to remove tokens from wallet
     *
     *  Since pankacke swap and other sites need to remove tokens from the users wallet
     *  it needs to be approved by the wallet the amount is removed from.
     *
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    //Transfer functions

    /**
     * @dev Internal transferfunction to check requirements for transfer
     *
     *  Check if requires are satisfied and check if sender or recipient is excluded from the fee.
     *  Avoid sending too much during one transaction for whales
     *
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private{
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if(_inTransfer){
            _tokenTransfer(from, to, amount, false);
        }
        else {
            _inTransfer = true;
            //antiwhale function upgradable in the future

            //indicates if fee should be deducted from transfer
            bool takeFee = true;
            uint256 contractTax = taxFee;
            uint256 contractOther = otherFee;

            //if any account belongs to _isExcludedFromFee account then remove the fee
            if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
                takeFee = false;
            }

            //If proxy function is enabled, do pretransfer checks and modify fee if its enabled
            if(proxyenabled){

                (uint256 newTaxFee, uint256 newOtherFee, bool newTakeFee) = IProxyContract(proxycontract).preTransfer(from, to, amount, takeFee);

                if(proxyfee){
                    taxFee = newTaxFee;
                    otherFee = newOtherFee;
                    takeFee = newTakeFee;
                }
            }


            //transfer amount, it will take tax, burn, liquidity fee
            _tokenTransfer(from, to, amount, takeFee);

            if(proxyenabled){
                //Reverse fee to old state
                if(proxyfee){
                    taxFee = contractTax;
                    otherFee = contractOther;
                }
                IProxyContract(proxycontract).postTransfer(from, to, amount, takeFee);
            }
            _inTransfer = false;
        }


    }

    /**
     * @dev Check if sender or reciever is excluded from reward and use the right transfer functions based on this
     *
     *  Disable fee, if this transaction is excluded from fees. Check if sender or/and reciever is excluded from rewards
     *  to check if token balance or/and reflection balance need to be added to reciepient addres and subtracted from sender
     */
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) {
            removeAllFee();
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        //Make sure that next transactions have a fee if they aren't excluded
        if (!takeFee) {
            restoreAllFee();
        }
    }

    /**
     * @dev Transfer function when both sender and reciever are included in rewards
     *
     *  Remove the reflection amount from sender and add reflection amount to sender
     *
     */
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOtherFee
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeOtherFee(tOtherFee, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfer function when reciever is exluded from rewards
     *
     *  Remove the reflection amount from sender and only add reflection and token amount to sender
     *
     */
    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOtherFee
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _tOwnedExcluded = _tOwnedExcluded.add(tTransferAmount);
        _rOwnedExcluded = _rOwnedExcluded.add(rTransferAmount);
        _takeOtherFee(tOtherFee, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfer function when sender is exluded from rewards
     *
     *  Remove the token and reflection amount from sender and only add reflection amount to sender
     *
     */
    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOtherFee
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

        //Update total amount
        _tOwnedExcluded = _tOwnedExcluded.sub(tAmount);
        _rOwnedExcluded = _rOwnedExcluded.sub(rAmount);

        _takeOtherFee(tOtherFee, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfer function when sender and reciever is excluded from rewards
     *
     *  Remove the token and reflection amount from sender and add reflection and token amount to sender
     *
     */
    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOtherFee
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

        //Update total amount in total adresses
        _tOwnedExcluded = _tOwnedExcluded.sub(tAmount).add(tTransferAmount);
        _rOwnedExcluded = _rOwnedExcluded.sub(rAmount).add(rTransferAmount);

        _takeOtherFee(tOtherFee, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    //Withdraw tokens, can be vanurable to reentrancy attacks, but doesn't matter becouse of onlyOwner
    function emergencyWithdraw(uint256 _amount, address _token) public onlyRole(JANITOR_ROLE){
        IERC20 token = IERC20(_token);
        require(_amount >= token.balanceOf(address(this)), 'The contract balance is too low');
        token.transfer(msg.sender, _amount);
    }
}