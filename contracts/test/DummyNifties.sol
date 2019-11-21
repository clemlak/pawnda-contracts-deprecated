pragma solidity 0.5.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract DummyNifties is ERC721 {
    struct Nifty {
        uint256 foo;
    }

    Nifty[] public nifties;

    function claimFreeNifty() public {
        uint256 niftyId = nifties.push(
            Nifty({
                foo: 0
            })
        ) - 1;

        _mint(msg.sender, niftyId);
    }
}
