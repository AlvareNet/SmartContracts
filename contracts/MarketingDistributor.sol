// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import './proxyimplementation.sol';
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MarketingDistributor is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    uint8 public Marketing = 50;
    uint8 public IT_Service = 5;
    uint8 public Salary = 20;
    uint8 public Exchange_Platform = 10;
    uint8 public Savings = 15;
    uint8 public TotalFees;

    //Wallets recieving fees
    address payable public Marketing_Wallet;
    address payable public IT_Service_Wallet;
    address payable public Exchange_Platform_Wallet;
    address payable public Salary_Wallet;
    address payable public Savings_Wallet;

    //Wallet recieving trading fees
    address payable public Fee_Wallet;

    address public Fee_Currency;

    constructor(address payable _Marketing_Wallet,
     address payable _IT_Service_Wallet,
     address payable _Salary_Wallet,
     address payable _Exchange_Platform_Wallet,
     address payable _Savings_Wallet,
     address payable _Fee_Wallet,
     address _Fee_Currency
    ){

        _setRecieverWallets(
            _Marketing_Wallet,
            _IT_Service_Wallet,
            _Salary_Wallet,
            _Exchange_Platform_Wallet,
            _Savings_Wallet
        );

        _setFeeWallet(_Fee_Wallet);

        _setFeeCurrency(_Fee_Currency);

        _calculateTotalFee();
    }


    function _calculateTotalFee() private {
        TotalFees = Marketing + IT_Service + Exchange_Platform + Salary + Savings;
    }

    function _setFeeCurrency(address _Fee_Currency) private {
        require(_Fee_Currency != address(0));

        Fee_Currency = _Fee_Currency;

    }

    function _setRecieverWallets(
        address payable _Marketing_Wallet,
        address payable _IT_Service_Wallet,
        address payable _Salary_Wallet,
        address payable _Exchange_Platform_Wallet,
        address payable _Savings_Wallet
    ) private {

        require(_Marketing_Wallet != address(0));
        require(_IT_Service_Wallet != address(0));
        require(_Exchange_Platform_Wallet != address(0));
        require(_Salary_Wallet != address(0));
        require(_Savings_Wallet != address(0));
        Marketing_Wallet = _Marketing_Wallet;
        IT_Service_Wallet = _IT_Service_Wallet;
        Exchange_Platform_Wallet = _Exchange_Platform_Wallet;
        Salary_Wallet = _Salary_Wallet;
        Savings_Wallet = _Savings_Wallet;

    }

    function _setFeeWallet(address payable _Fee_Wallet) private {
        require(_Fee_Wallet != address(0));
        Fee_Wallet = _Fee_Wallet;
    }

    function setFeeCurrency(address _Fee_Currency) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setFeeCurrency(_Fee_Currency);
    }

    function setFeeWallet(address payable _Fee_Wallet) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setFeeWallet(_Fee_Wallet);
    }

    function setRecieverWallets(
        address payable _Marketing_Wallet,
        address payable _IT_Service_Wallet,
        address payable _Salary_Wallet,
        address payable _Exchange_Platform_Wallet,
        address payable _Savings_Wallet
     ) external onlyRole(DEFAULT_ADMIN_ROLE) {

        _setRecieverWallets(
            _Marketing_Wallet,
            _IT_Service_Wallet,
            _Salary_Wallet,
            _Exchange_Platform_Wallet,
            _Savings_Wallet
        );
    }

    function setFeeDistribution(
        uint8 _Marketing,
        uint8 _IT_Service,
        uint8 _Salary,
        uint8 _Savings, 
        uint8 _Exchange_Platform
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Marketing = _Marketing;
        IT_Service = _IT_Service;
        Salary = _Salary;
        Savings = _Savings;
        Exchange_Platform = _Exchange_Platform;
        _calculateTotalFee();
    }

    function distribute() external onlyRole(WITHDRAWER_ROLE){
        ProxyFunctions proxy = ProxyFunctions(Fee_Wallet);
        IERC20 feecurrency = IERC20(Fee_Currency);

        //Withdraw tokens
        proxy.withdrawMarketingAll(payable(address(this)));

        //Check if balance is big enough
        uint256 balance = feecurrency.balanceOf(address(this));
        require(balance > 0);

        feecurrency.safeTransfer(Marketing_Wallet, balance * Marketing / TotalFees);

        feecurrency.safeTransfer(IT_Service_Wallet, balance * IT_Service / TotalFees);

        feecurrency.safeTransfer(Salary_Wallet, balance * Salary / TotalFees);

        feecurrency.safeTransfer(Savings_Wallet, balance * Savings / TotalFees);

        feecurrency.safeTransfer(Exchange_Platform_Wallet, balance * Exchange_Platform / TotalFees);
    }

    function deposit() public payable {}
    
    function WithdrawTokens(address _token, address _reciever)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "You cant withdraw 0");
        token.safeTransfer(_reciever, balance);
    }

    function WithdrawBNB(address payable _reciever) public {
        uint256 balance = address(this).balance;
        require(balance > 0, "You cant withdraw 0");
        _reciever.transfer(address(this).balance);
    }

}



