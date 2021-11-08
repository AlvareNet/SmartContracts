// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./interfaces/uniswapinterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract PairFinder {
    struct Pool {
        address liquidityPool;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
    }
    function findPair(address _Router, address[] memory tokens) external view returns(Pool[] memory foundPools){
        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Router02(_Router).factory());
        uint position = 0;
        for(uint i = 0; i < tokens.length; i++){
            for(uint j = i+1; j < tokens.length; j++){
                address pair = factory.getPair(tokens[i], tokens[j]);
                if(pair != address(0)){
                    uint256 balanceA = IERC20(tokens[i]).balanceOf(pair);
                    uint256 balanceB = IERC20(tokens[j]).balanceOf(pair);
                    foundPools[position] = Pool(pair, tokens[i], tokens[j], balanceA, balanceB);
                    position++;
                }
            }
        }
    }
}