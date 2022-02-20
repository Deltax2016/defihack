pragma ton-solidity >= 0.47.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import './IName.sol';

abstract contract Name is IName {

    uint16 _data;

    function getName() public override responsible returns (uint16 data) {
        return {value: 0, flag: 64}(_data);
    }

}