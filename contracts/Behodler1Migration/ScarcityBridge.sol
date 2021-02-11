// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

abstract contract IERC20 {
    function totalSupply() external virtual returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 value
    ) external virtual returns (bool);

    function balanceOf(address holder) external virtual returns (uint256);
}

abstract contract SCX {
    function burn(uint256 value) external virtual;

    function migrateMint(address recipient, uint256 value) public virtual;
}

contract ScarcityBridge {
    struct ScarcityTotals {
        uint256 total_v1;
        uint256 total_v2;
        uint256 blockRecorded;
        address scarcity1;
        address scarcity2;
    }
    uint256 public exchangeRate; //also represents the minimum old SCX required to get 1 unit of new SCX
    ScarcityTotals public totals;
    address migrator;

    modifier onlyMigrator {
        require(msg.sender == migrator);
        _;
    }

    constructor(
        address scarcity1,
        address scarcity2,
        address _migrator
    ) {
        totals.scarcity1 = scarcity1;
        totals.scarcity2 = scarcity2;
        migrator = _migrator;
    }

    function collectScarcity1BeforeBurning(uint256 scx) public onlyMigrator {
        totals.total_v1 += scx;
    }

    function recordExchangeRate() public onlyMigrator {
        totals.total_v2 = IERC20(totals.scarcity2).totalSupply();
        exchangeRate = totals.total_v1 / totals.total_v2;
        totals.blockRecorded = block.number;
    }

    function swap() public {
        uint256 v1Balance = IERC20(totals.scarcity1).balanceOf(msg.sender);
        require(
            IERC20(totals.scarcity1).transferFrom(
                msg.sender,
                address(this),
                v1Balance
            ),
            "SCX BRIDGE: transfer failed."
        );
        uint256 newSCX = v1Balance / exchangeRate;
        require(newSCX > 0, "SCX BRIDGE: insufficient SCX sent.");
        uint256 thisBalance = IERC20(totals.scarcity1).balanceOf(address(this));
        require(thisBalance == v1Balance, "Invariant fail");
        SCX(totals.scarcity1).burn(v1Balance); //bug
        SCX(totals.scarcity2).migrateMint(msg.sender, newSCX);
    }
}
