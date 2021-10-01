pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SLOTHI is ERC20 {
    constructor() ERC20("TESTSLOTHI", "SLTH") {
        uint256 initialSupply = 1000000000000000000000000;
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}