// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;
import "../contracts/Powers.sol";

interface BurnableERC20 {
    function transfer(address recipient, uint256 value) external returns (bool);

    function balanceOf(address holder) external returns (uint256);

    function burn(uint256 amount) external;
}

contract IronCrown is Empowered {
    BurnableERC20 scx;
    struct Silmaril {
        uint16 percentage; //0-1000
        address exit;
    }

    uint8 public constant perpetualMining = 0; //liquid vault etc
    uint8 public constant dev = 1;
    uint8 public constant treasury = 2; //angband

    Silmaril[3] silmarils;

    constructor(address _powers) {
        powersRegistry = PowersRegistry(_powers);
        initialized = true;
    }

    function setSCX(address _scx) public onlyOwner {
        scx = BurnableERC20(_scx);
    }

    function settlePayments() public {
         uint256 balance = scx.balanceOf(address(this));
        if (balance == 0) return;
        for (uint8 i = 0; i < 3; i++) {
            Silmaril memory silmaril = silmarils[i];
            uint256 share = (balance * silmaril.percentage) / 1000;
            if (address(silmarils[i].exit) == address(0)) {
                scx.burn(share);
            } else {
                scx.transfer(silmarils[i].exit, share);
            }
        }
    }

    function setSilmaril(
        uint8 index,
        uint8 percentage,
        address exit
    ) external {
        require(index < 3, "MORGOTH: index out of bounds");
        settlePayments();
        silmarils[index].percentage = percentage;
        require(
            silmarils[0].percentage +
                silmarils[1].percentage +
                silmarils[2].percentage <=
                1000,
            "MORGOTH: percentage exceeds 100%"
        );
        silmarils[index].exit = exit;
    }

    function getSilmaril(uint256 index) external view returns (uint16, address) {
        return (silmarils[index].percentage, silmarils[index].exit);
    }
}
