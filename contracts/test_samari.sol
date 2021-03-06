pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SAMARI is ERC20 {
    constructor() ERC20("TESTSAMA", "SAMA") {
        uint256 initialSupply = 1273628335437000000000;
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}