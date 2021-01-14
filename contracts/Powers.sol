// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;
import "./Angband.sol";
import "./openzeppelin/Ownable.sol";

struct Power{
    bytes32 name;
    bytes32 domain; //Thangorodrim mapping 
    bool transferrable;
    bool unique;
}

abstract contract PowerInvoker {
    event PowerInvoked (address user, bytes32 minion, bytes32 domain);
    
    Power public power;
    PowersRegistry public registry;
    Angband public angband;
    bool invoked;

    constructor (bytes32 _power, address _angband) {
        angband = Angband(_angband);
        address _registry = angband.getAddress(angband.POWERREGISTRY());
        registry = PowersRegistry(_registry);
        (bytes32 name, bytes32 domain,bool transferrable, bool unique) = registry.powers(_power);
        power = Power(name,domain,transferrable,unique);
    }

    modifier revertOwnership {
        _;
        address ownableContract = angband.getAddress(power.domain);
        if(ownableContract!=address(angband)) Ownable(ownableContract).transferOwnership(address(angband));
    }

    function destruct () public{
        require(invoked, "MORGOTH: awaiting invocation");
        selfdestruct(msg.sender);
    }

    function orchestrate() internal virtual returns (bool);

    function invoke(bytes32 minion, address sender) public revertOwnership{
        require(msg.sender == address(angband),"MORGOTH: angband only");
        require(registry.isUserMinion(sender, minion), "MORGOTH: Invocation by minions only.");
        require(!invoked, "MORGOTH: Power cannot be invoked.");
        require(orchestrate(), "MORGOTH: Power invocation");
        invoked = true;
        emit PowerInvoked(sender, minion, power.domain);
    }
}

contract Empowered is Ownable {
    PowersRegistry internal powersRegistry;
    bool initialized;

    function changePower(address _powers) public  requiresPowerOrInitialCondition(powersRegistry.CHANGE_POWERS(),address(powersRegistry)==address(0)) {
        bytes32 _power = PowersRegistry(_powers).CHANGE_POWERS();
        powersRegistry = PowersRegistry(_powers);
        require(!initialized ||powersRegistry.userHasPower(_power,msg.sender), "MORGOTH: forbidden power");
        initialized = true;
    }

    modifier requiresPower(bytes32 power) {
        require(initialized, "MORGOTH: powers not allocated.");
        require(powersRegistry.userHasPower(power,msg.sender), "MORGOTH: forbidden power");
        _;
    }

    modifier requiresPowerOnInvocation(address invoker) {
        (bytes32 power,,,) = PowerInvoker(invoker).power();
        require(initialized, "MORGOTH: powers not allocated.");
        require(powersRegistry.userHasPower(power,msg.sender), "MORGOTH: forbidden power");
        _;
    }

    modifier requiresPowerOrInitialCondition(bytes32 power, bool initialCondition) {
        require(initialized, "MORGOTH: powersRegistry not allocated.");
        require(initialCondition || powersRegistry.userHasPower(power,msg.sender), "MORGOTH: forbidden power");
        _;
    }


    modifier hasEitherPower(bytes32 power1, bytes32 power2) {
        require(initialized, "MORGOTH: powers not allocated.");
        require(powersRegistry.userHasPower(power1,msg.sender) || powersRegistry.userHasPower(power2,msg.sender) , "MORGOTH: forbidden powers");
        _;
    }
}

/*
Every user privilege is a power in MorgothDAO. At first these powers will be controlled by personalities. Over time they can be handed over to increasingly
decentralized mechanisms.
*/

contract PowersRegistry is Empowered {
    bytes32 public constant NULL = "NULL";
    bytes32 public constant POINT_TO_BEHODLER = "POINT_TO_BEHODLER"; // set all behodler addresses
    bytes32 public constant WIRE_ANGBAND = "WIRE_ANGBAND";
    bytes32 public constant CHANGE_POWERS = "CHANGE_POWERS"; // change the power registry
    bytes32 public constant CONFIGURE_THANGORODRIM = "CONFIGURE_THANGORODRIM"; // set the registry of contract addresses
    bytes32 public constant SEIZE_POWER = "SEIZE_POWER"; //reclaim a delegated power.
    bytes32 public constant CREATE_NEW_POWER = "CREATE_NEW_POWER";
    bytes32 public constant BOND_USER_TO_MINION = "BOND_USER_TO_MINION";
    bytes32 public constant ADD_TOKEN_TO_BEHODLER = "ADD_TOKEN_TO_BEHODLER";
    bytes32 public constant CONFIGURE_SCARCITY = "CONFIGURE_SCARCITY";
    bytes32 public constant VETO_BAD_OUTCOME = "VETO_BAD_OUTCOME";
    bytes32 public constant DISPUTE_DECISION = "DISPUTE_DECISION";
    bytes32 public constant SET_DISPUTE_TIMEOUT = "SET_DISPUTE_TIMEOUT";
    bytes32 public constant INSERT_SILMARIL = "INSERT_SILMARIL";
    bytes32 public constant AUTHORIZE_INVOKER = "AUTHORIZE_INVOKER";
    mapping (bytes32 => Power) public powers;

    mapping (address=> mapping (bytes32=>bool))  userIsMinion;
    mapping (bytes32=>mapping (bytes32=>bool))  powerIsInMinion; //power,minion,bool
    mapping (bytes32=>mapping (bytes32=>bool))  minionHasPower; // minion,power,bool
    mapping (address=>bytes32) public userMinion;

    bytes32[] minions;

    constructor() {
        minions.push("Melkor");
        minions.push("Ungoliant");
        minions.push("Sauron");
        minions.push("Saruman");
        minions.push("Glaurung");
        minions.push("Gothmog");
        minions.push("Carcharoth");
        minions.push("Witchking");
        minions.push("Smaug");
        minions.push("dragon");
        minions.push("balrog");
        minions.push("orc");
        userIsMinion[msg.sender]["Melkor"] = true;
        powerIsInMinion[CREATE_NEW_POWER]["Melkor"] = true;
        powerIsInMinion[SEIZE_POWER]["Melkor"] = true;
        powerIsInMinion[BOND_USER_TO_MINION]["Melkor"] = true;
        
        userMinion[msg.sender] = "Melkor";

        minionHasPower["Melkor"][CREATE_NEW_POWER] = true;
        minionHasPower["Melkor"][SEIZE_POWER] = true;
        minionHasPower["Melkor"][BOND_USER_TO_MINION] = true;
        initialized =true;
    }

    function seed () public {
        powersRegistry = PowersRegistry(address(this));
    }

    function userHasPower(bytes32 power, address user)
        public
        view
        returns (bool)
    {
        bytes32 minion = userMinion[user];
        return minionHasPower[minion][power];
    }

    function isUserMinion (address user, bytes32 minion) public view returns (bool){
          return userIsMinion[user][minion];
    }
    
    function create (bytes32 power,
        bytes32 domain,
        bool transferrable,
        bool unique) 
        requiresPower(CREATE_NEW_POWER)
         public {
        powers[power] = Power(power,
            domain,
            transferrable,
            unique
        );
    }

    function destroy (bytes32 power) public hasEitherPower(CREATE_NEW_POWER,CHANGE_POWERS){
        powers[power] = Power(NULL,NULL,false,false);
    }
    
    function pour(bytes32 power, bytes32 minion_to) hasEitherPower(power,SEIZE_POWER) public {
        Power memory currentPower = powers[power];
        require(currentPower.transferrable, "MORGOTH: power not transferrable");


        bytes32 fromMinion = userMinion[msg.sender];
        powerIsInMinion[power][fromMinion] = false;
        minionHasPower[fromMinion][power] = false;

        _spread(currentPower,power, minion_to);
    }

    function spread (bytes32 power, bytes32 minion_to) requiresPower(power) public {
        Power memory currentPower = powers[power];
         require(!currentPower.unique, "MORGOTH: power not divisible.");
        _spread(currentPower,power,minion_to);
    }

    function _spread(Power memory power, bytes32 name, bytes32 minion_to) internal {
        powerIsInMinion[name][minion_to] = true;
        minionHasPower[minion_to][name] = true;
    }

    function castIntoVoid (address user, bytes32 minion) public requiresPower(BOND_USER_TO_MINION) {
        userIsMinion[user][minion] = false;
        userMinion[user] = "";
    }

    function bondUserToMinion(address user, bytes32 minion)public requiresPower(BOND_USER_TO_MINION) {
        require(!userIsMinion[user][minion], "MORGOTH: minion already assigned");
        userIsMinion[user][minion] = true;
        userMinion[user] = minion;
    }
 }