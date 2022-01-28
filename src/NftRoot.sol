pragma ton-solidity >=0.43.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './resolvers/IndexResolver.sol';
import './resolvers/NftResolver.sol';

import './IndexBasis.sol';

import './interfaces/IIndexBasis.sol';

import './errors/NftRootErrors.sol';


contract NftRoot is NftResolver, IndexResolver {

    uint256 _ownerPubkey;
    uint256 _totalMinted;
    address _addrIndexBasis;

    /// _indexDeployValue will be spent on the Index deployment in the Nft contract
    uint128 _indexDeployValue = 0.4 ton;
    /// _processingValue - will be spent on executing the mint method
    /// if you want to earn on the remainder, remove the rawReserve
    uint128 _processingValue = 0.9 ton;
    /// _remainOnNft - the number of crystals that will remain after the entire mint 
    /// process is completed on the Nft contract
    uint128 _remainOnNft = 0.3 ton;
    /// _deployIndexValue - the number of tokens that will be sent for the
    /// IndexBasic deployment and will remain on the IndexBasic contract after the deployment
    uint128 _deployIndexBasisValue = 0.4 ton;

    event tokenWasMinted(address nftAddr, address creatorAddr);

    constructor(
        TvmCell codeIndex, 
        TvmCell codeNft, 
        uint256 ownerPubkey
    ) public {
        require(ownerPubkey != 0, NftRootErrors.pubkey_is_empty);
        tvm.accept();
        _codeIndex = codeIndex;
        _codeNft = codeNft;
        _ownerPubkey = ownerPubkey;
    }

    function mintNft() public {
        require(msg.value >= (_indexDeployValue * 2) + _remainOnNft, NftRootErrors.value_less_than_required);
        tvm.accept();
        tvm.rawReserve(msg.value, 1);

        TvmCell codeNft = _buildNftCode(address(this));
        TvmCell stateNft = _buildNftState(codeNft, _totalMinted);
        address nftAddr = new Nft{
            stateInit: stateNft,
            value: (_indexDeployValue * 2) + _remainOnNft
            }(
                msg.sender, 
                _codeIndex,
                _indexDeployValue
            ); 

        emit tokenWasMinted(nftAddr, msg.sender);

        _totalMinted++;

        msg.sender.transfer({value: 0, flag: 128});
    }

    function deployIndexBasis(TvmCell codeIndexBasis) public onlyOwner {
        require(address(this).balance > _deployIndexBasisValue + 0.1 ton, NftRootErrors.value_less_than_required); /// 0.1 ton this is freeze protection
        uint256 codeHashNft = resolveCodeHashNft();
        TvmCell state = tvm.buildStateInit({
            contr: IndexBasis,
            varInit: {
                _codeHashNft: codeHashNft,
                _addrRoot: address(this)
            },
            code: codeIndexBasis
        });
        _addrIndexBasis = new IndexBasis{stateInit: state, value: _deployIndexBasisValue}();
    }

    function destructIndexBasis() public view onlyOwner {
        require(_addrIndexBasis != address(0), NftRootErrors.index_not_deployed);
        IIndexBasis(_addrIndexBasis).destruct();
    }

    function withdraw(address to, uint128 value) public pure onlyOwner {
        require(address(this).balance > value, NftRootErrors.value_is_greater_than_the_balance);
        tvm.accept();
        to.transfer(value, true, 0);
    }

    function setIndexDeployValue(uint128 indexDeployValue) public onlyOwner {
        tvm.accept();
        _indexDeployValue = indexDeployValue;
    }
    
    function setProcessingValue(uint128 processingValue) public onlyOwner {
        tvm.accept();
        _processingValue = processingValue;
    }

    function setRemainOnNft(uint128 remainOnNft) public onlyOwner {
        tvm.accept();
        _remainOnNft = remainOnNft;
    }   

    function setDeployIndexValue(uint128 deployIndexValue) public onlyOwner {
        tvm.accept();
        _deployIndexBasisValue = deployIndexValue;
    }

    function getIndexDeployValue() public view returns(uint128) {
        return _indexDeployValue;
    }

    function getProcessingValue() public view returns(uint128) {
        return _processingValue;
    }

    function getRemainOnNft() public view returns(uint128) {
        return _remainOnNft;
    }

    function getDeployIndexValue() public view returns(uint128) {
        return _deployIndexBasisValue;
    }  

    function getIndexBasisAddress() public view returns(address) {
        return _addrIndexBasis;
    } 

    modifier onlyOwner {
        require(msg.pubkey() == _ownerPubkey, NftRootErrors.not_my_pubkey);
        _;
    }

}