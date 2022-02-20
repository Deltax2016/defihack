pragma ton-solidity >= 0.47.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import '../../../src/resolvers/IndexResolver.sol';
import '../../../src/errors/NftErrors.sol';
import './INftBase.sol';
import './ITokenTransferCallback.sol';


abstract contract NftBase is INftBase, IndexResolver {

    uint256 public static _id;

    address _addrRoot;
    address _addrOwner;

    uint128 _indexDeployValue;
    uint128 _indexDestroyValue;
    uint128 _lastWatered;
    uint128 public _lastHarvest;

    uint128 public _birthTime = 0;
    uint16 public _waters;

    uint16 public _child = 0;
    
    event TokenWasMinted(address owner);
    event OwnershipTransferred(address oldOwner, address newOwner);

    /// @param sendGasToAddr can be empty. If sendGasToAddr is not empty - remaining gas will be returned to the specified address, else gas will be transferred to sender
    /// @param addrTo can't be empty. After executing the method, the account with this address will become the owner
    /// @param callbacks for receiving callback
    function transferOwnership(
        address sendGasToAddr, 
        address addrTo, 
        mapping(address => CallbackParams) callbacks
    ) public override onlyOwner {
        require(msg.value >= (_indexDeployValue * 2), NftErrors.value_less_than_required);
        require(addrTo.value != 0, NftErrors.value_is_empty);
        tvm.rawReserve(msg.value, 1);

        address addrOwner = _addrOwner;
        sendGasToAddr = sendGasToAddr.value != 0 ? sendGasToAddr : msg.sender;

        _transfer(addrTo, sendGasToAddr);
        emit OwnershipTransferred(addrOwner, addrTo);

        optional(TvmCell) callbackToGasOwner;
        for ((address dest, CallbackParams p) : callbacks) {
            if (dest.value != 0) {
                if (sendGasToAddr != dest) {
                    ITokenTransferCallback(dest).tokenTransferCallback{
                        value: p.value,
                        flag: 0,
                        bounce: false
                    }(addrOwner, addrTo, _addrRoot, sendGasToAddr, p.payload);
                } else {
                    callbackToGasOwner.set(p.payload);
                }
            }
        }

        if (sendGasToAddr.value != 0) {
            if (callbackToGasOwner.hasValue()) {
                ITokenTransferCallback(sendGasToAddr).tokenTransferCallback{
                    value: 0,
                    flag: 128,
                    bounce: false
                }(addrOwner, addrTo, _addrRoot, sendGasToAddr, callbackToGasOwner.get());
            } else {
                sendGasToAddr.transfer({
                    value: 0,
                    flag: 128,
                    bounce: false
                });
            }
        }

    }

    function _transfer(
        address to,
        address sendGasToAddr
    ) internal {
        require(to.value != 0, NftErrors.value_is_empty);

        _destructIndex(sendGasToAddr);
        _addrOwner = to;
        _deployIndex(sendGasToAddr);
    }

    function _deployIndex(address sendGasToAddr) internal view {
        TvmCell codeIndexOwner = _buildIndexCode(_addrRoot, _addrOwner);
        TvmCell stateIndexOwner = _buildIndexState(codeIndexOwner, address(this));
        new Index{stateInit: stateIndexOwner, value: _indexDeployValue}(_addrRoot, sendGasToAddr, _indexDeployValue - 0.1 ton);

        TvmCell codeIndexOwnerRoot = _buildIndexCode(address(0), _addrOwner);
        TvmCell stateIndexOwnerRoot = _buildIndexState(codeIndexOwnerRoot, address(this));
        new Index{stateInit: stateIndexOwnerRoot, value: _indexDeployValue}(_addrRoot, sendGasToAddr, _indexDeployValue - 0.1 ton);
    }

    function _destructIndex(address sendGasToAddr) internal view {
        address oldIndexOwner = resolveIndex(address(0), address(this), _addrOwner);
        IIndex(oldIndexOwner).destruct{value: _indexDestroyValue}(sendGasToAddr);
        address oldIndexOwnerRoot = resolveIndex(_addrRoot, address(this), _addrOwner);
        IIndex(oldIndexOwnerRoot).destruct{value: _indexDestroyValue}(sendGasToAddr);
    }

    function setIndexDeployValue(uint128 indexDeployValue) public override onlyOwner {
        tvm.rawReserve(msg.value, 1);
        _indexDeployValue = indexDeployValue;
        msg.sender.transfer({value: 0, flag: 128});
    }

    function setIndexDestroyValue(uint128 indexDestroyValue) public override onlyOwner {
        tvm.rawReserve(msg.value, 1);
        _indexDestroyValue = indexDestroyValue;
        msg.sender.transfer({value: 0, flag: 128});
    }

    function getIndexDeployValue() public responsible override returns(uint128) {
        return {value: 0, flag: 64} _indexDeployValue;
    }

    function getIndexDestroyValue() public responsible override returns(uint128) {
        return {value: 0, flag: 64} _indexDestroyValue;
    }

    function getOwner() public responsible override returns(address addrOwner) {
        return {value: 0, flag: 64} _addrOwner;
    }


    modifier onlyOwner virtual {
        require(msg.sender == _addrOwner, NftErrors.sender_is_not_owner);
        _;
    }

}