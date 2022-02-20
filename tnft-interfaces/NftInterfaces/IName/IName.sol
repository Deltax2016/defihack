pragma ton-solidity >= 0.47.0;

interface IName {
    function getName() external responsible returns (uint16 data);
}