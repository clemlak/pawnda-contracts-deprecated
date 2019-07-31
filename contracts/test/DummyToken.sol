pragma solidity 0.5.10;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";


contract DummyToken is ERC20 {
    function claimFreeTokens(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
