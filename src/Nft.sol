pragma ton-solidity >= 0.47.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import '../tnft-interfaces/NftInterfaces/INftBase/NftBase.sol';
import '../tnft-interfaces/NftInterfaces/IName/Name.sol';
import '../tnft-interfaces/NftInterfaces/ITIP6/TIP6.sol';

interface IContract {
    function junction(uint256 id, uint16 data) external;
}

interface IRoot {
    function mintNftChild(uint16 gen, address owner) external;
}

contract Nft is NftBase, Name, TIP6 {

    constructor(
        address addrOwner, 
        TvmCell codeIndex,
        uint128 indexDeployValue, 
        uint16 data
    ) public {
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        require(optSalt.hasValue(), NftErrors.value_is_empty);
        (address addrRoot) = optSalt.get().toSlice().decode(address);
        require(msg.sender == addrRoot, NftErrors.sender_is_not_root);
        require(msg.value >= (_indexDeployValue * 2), NftErrors.value_less_than_required);
        tvm.accept();
        _addrRoot = addrRoot;
        _addrOwner = addrOwner;
        _codeIndex = codeIndex;
        _indexDeployValue = indexDeployValue;
        _data = data;
        _lastWatered = 0;

        _supportedInterfaces[ 
            bytes4(
            tvm.functionId(INftBase.setIndexDeployValue) ^ 
            tvm.functionId(INftBase.transferOwnership) ^
            tvm.functionId(INftBase.getIndexDeployValue) ^
            tvm.functionId(INftBase.getOwner)
            )
        ] = true;

        _supportedInterfaces[ bytes4(tvm.functionId(IName.getName)) ] = true;
        _supportedInterfaces[ bytes4(tvm.functionId(ITIP6.supportsInterface)) ] = true;

        emit TokenWasMinted(addrOwner);

        _deployIndex(addrOwner);
    }

    function resolveNft(
        address addrRoot,
        uint256 id
    ) public view returns (address addrNft) {
        TvmCell code = _buildNftCode(addrRoot);
        TvmCell state = _buildNftState(code, id);
        uint256 hashState = tvm.hash(state);
        addrNft = address.makeAddrStd(0, hashState);
    }

    function _buildNftCode(address addrRoot) internal virtual view returns (TvmCell) {

        return tvm.code();

    }

    function _buildNftState(
        TvmCell code,
        uint256 id
    ) internal virtual pure returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Nft,
            varInit: {_id: id},
            code: code
        });
    }

    function breed(uint256 id) public {

        if (((now - _lastWatered) >= 200 ) && (_lastWatered != 0)) {

                _data = 0;
                
        }
        else {

            address Nft2 = resolveNft(_addrRoot, id);
            IContract(Nft2).junction{value: 0, flag: 64}(_id, _data);

        }

    }

    function getWatered() public view responsible returns(uint128 lastWatered) {

        return {value: 0, flag: 128} _lastWatered;

    }

    function getAllData() public view responsible returns(uint16 data, uint128 lastWatered, uint128 birthTime, uint128 lastHarvest) {

        return {value: 0, flag: 128} (_data, _lastWatered, _birthTime, _lastHarvest);

    }

    function water() public onlyOwner {

        tvm.rawReserve(msg.value, 1);

        if (((now - _lastWatered) >= 200 ) && (_lastWatered != 0)) {

            _data = 0;
            
        }
        else {
            _lastWatered = now;
            if (_birthTime == 0) {
                _birthTime = _lastWatered;
            }

            _waters += 1;
        }

    }

    function harvest() public {

        if ((now - _lastHarvest) >= 40 ) {

            if (((now - _lastWatered) >= 200 ) && (_lastWatered != 0)) {

                _data = 0;

            }
            else {

                IRoot(_addrRoot).mintNftChild{value: 0, flag: 64}(_data, _addrOwner);
                _lastHarvest = now;

            }

        }

    }


    function junction(uint256 id, uint16 data) public OnlyNft(id) {

        if (((now - _lastWatered) >= 200 ) && (_lastWatered != 0)) {

                _data = 0;
                
        }
        else {

            _child = (_data + data) / 2;
            IRoot(_addrRoot).mintNftChild{value: 0, flag: 64}(_child, _addrOwner);

        }

    }

    modifier OnlyNft(uint256 id) {
        require(msg.sender == resolveNft(_addrRoot, id), 120);
        _;
    }

}