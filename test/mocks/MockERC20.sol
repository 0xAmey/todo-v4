// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK", 18) {
        _mint(msg.sender, 10000e18);
    }
}
