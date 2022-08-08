// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KittyContract is IERC721, Ownable {
    string public TokenName = "HoeToken";
    string public TokenSymbol = "HOE";
    uint256 public constant CREATION_LIMIT_GEN0 = 10;
    uint256 public gen0Counter;

    bytes4 internal constant MAGIC_ERC721_RECEIVED =
        bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    struct Kitty {
        uint256 genes;
        uint64 birthTime;
        uint32 mumId;
        uint32 dadId;
        uint16 generation;
    }

    Kitty[] internal kitties;

    mapping(uint256 => address) public tokenApprovals;
    mapping(uint256 => address) public kittyIndexToOwner;
    mapping(address => uint256) public ownerTokenCount;
    mapping(address => mapping(address => bool)) public operatorApprovals;

    event Birth(
        address owner,
        uint256 kittenId,
        uint256 mumId,
        uint256 dadId,
        uint256 genes
    );

    function supportsInterface(bytes4 _interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return (_interfaceId == _INTERFACE_ID_ERC721 ||
            _interfaceId == _INTERFACE_ID_ERC165);
    }

    function createKittyGen0(uint256 _genes)
        public
        onlyOwner
        returns (uint256)
    {
        require(gen0Counter < CREATION_LIMIT_GEN0);

        gen0Counter++;

        return _createKitty(_genes, 0, 0, 0, msg.sender);
    }

    //Notice all the inputs are 256 bits verse the smaller uint's each property takes in struct...
    //this is because it is easier to input a 256 number, than convert it to say uint32 than it is to input 32 from getgo
    function _createKitty(
        uint256 _genes,
        uint256 _mumId,
        uint256 _dadId,
        uint256 _generation,
        address _owner
    ) private returns (uint256) {
        Kitty memory _kitty = Kitty({
            genes: _genes,
            birthTime: uint64(block.timestamp),
            mumId: uint32(_mumId),
            dadId: uint32(_dadId),
            generation: uint16(_generation)
        });
        //First kat will have an id of 0, so we will do -1.
        kitties.push(_kitty);

        uint256 newKittenId = kitties.length - 1;

        emit Birth(_owner, newKittenId, _mumId, _dadId, _genes);

        _transfer(address(0), _owner, newKittenId);

        return newKittenId;
    }

    function breed(uint256 _dadId, uint256 _mumId) public returns (uint256) {
        require(
            owns(msg.sender, _dadId) && owns(msg.sender, _mumId),
            "You dont own these cats"
        );

        uint256 dadGeneration = kitties[_dadId].generation;
        uint256 mumGeneration = kitties[_mumId].generation;
        uint256 newGeneration;
        if (dadGeneration > mumGeneration) {
            newGeneration = dadGeneration++;
        } else {
            newGeneration = mumGeneration++;
        }

        uint256 dadDna = kitties[_dadId].genes;
        uint256 mumDna = kitties[_mumId].genes;
        uint256 newDna = _mixDna(dadDna, mumDna);

        uint256 mintedCat = _createKitty(
            newDna,
            _mumId,
            _dadId,
            newGeneration,
            msg.sender
        );

        return mintedCat;
    }

    function _mixDna(uint256 _dadDna, uint256 _mumDna)
        public
        pure
        returns (uint256)
    {
        //dadDna 11 22 33 44 55 66 77 88 ... Dividing by 100000000 will leave use with the fist 8 (11, 22, 33, 44)
        //mumDna 88 77 66 55 44 33 22 11 ... Modulo (%) 10000000 will leav use with the last 8 (44, 33, 22, 11)

        uint256 firstHalf = _dadDna / 100000000; //11 22 33 44
        uint256 secondHalf = _mumDna % 100000000; //44 33 22 11
        //If we have 10 + 20 and we want 1020, we can't add these together like 10 + 20 as this is 30
        //We need to do 10 * 100 = 1000, then 1000 + 20 which will give us 1020.
        //So if we set this up in Remix to test and past in mumDna and dadDna our newDan should be 1122334444332211

        uint256 extendedDna = firstHalf * 100000000;
        uint256 finalDna = extendedDna + secondHalf;
        return finalDna;
    }

    //We could have just listed the types uint256, uint256, and then had a return statement at end with the names..
    //but it is cleaner to list type and name this way and leave off the return statement with this many variables
    function getKitty(uint256 _id)
        external
        view
        returns (
            uint256 genes,
            uint256 birthTime,
            uint256 mumId,
            uint256 dadId,
            uint256 generation
        )
    {
        //we want to do "storage" here and not memory because we want to create a pointer to refer to our global storage
        Kitty storage kitty = kitties[_id];
        genes = kitty.genes;
        birthTime = uint256(kitty.birthTime);
        mumId = uint256(kitty.mumId);
        dadId = uint256(kitty.dadId);
        generation = uint256(kitty.generation);
    }

    function balanceOf(address ownerAddress)
        external
        view
        override
        returns (uint256 balance)
    {
        return ownerTokenCount[ownerAddress];
    }

    function totalSupply() external view returns (uint256) {
        return kitties.length;
    }

    function name() external view returns (string memory) {
        return TokenName;
    }

    function symbol() external view returns (string memory) {
        return TokenSymbol;
    }

    function ownerOf(uint256 _tokenId)
        external
        view
        override
        returns (address)
    {
        address ownerAddress = kittyIndexToOwner[_tokenId];
        require(ownerAddress != address(0), "Cannot be owner of zero address");
        return ownerAddress;
    }

    function transfer(address _to, uint256 _tokenId) external {
        require(_to != address(0), "To address must be defined.");
        require(_to != address(this), "Cannot transfer to the contract itself");
        require(owns(msg.sender, _tokenId), "Cannot send token you not own");
        require(_to != msg.sender, "Cannot send to yourselves");

        _transfer(msg.sender, _to, _tokenId);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        ownerTokenCount[_to]++;
        if (_from != address(0)) {
            ownerTokenCount[_from]--;
        }
        kittyIndexToOwner[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) external override {
        address ownerAddress = kittyIndexToOwner[_tokenId];
        require(ownerAddress != address(0));
        require(
            owns(msg.sender, _tokenId) ||
                isApprovedForAll(ownerAddress, msg.sender)
        );
        require(_to != msg.sender, "ERC721: approval to current owner");
        _approve(_to, _tokenId);
    }

    function _approve(address _to, uint256 _tokenId) internal {
        tokenApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function owns(address _claimant, uint256 _tokenId)
        public
        view
        returns (bool)
    {
        return kittyIndexToOwner[_tokenId] == _claimant;
    }

    function setApprovalForAll(address _operator, bool _approved)
        external
        override
    {
        require(_operator != msg.sender);
        _setApprovalForAll(msg.sender, _operator, _approved);
    }

    function _setApprovalForAll(
        address _owner,
        address _operator,
        bool _approved
    ) internal {
        require(msg.sender != _operator, "ERC721: approve to caller");
        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(_owner, _operator, _approved);
    }

    function isApprovedForAll(address _ownerAddress, address _operator)
        public
        view
        override
        returns (bool)
    {
        return operatorApprovals[_ownerAddress][_operator];
    }

    function getApproved(uint256 _tokenId)
        public
        view
        override
        returns (address)
    {
        require(_tokenId < kitties.length);
        return tokenApprovals[_tokenId];
    }

    function exists(uint256 _tokenId) internal view virtual returns (bool) {
        return kittyIndexToOwner[_tokenId] != address(0);
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        require(exists(_tokenId), "Token Id does not exist");
        address ownerAddress = kittyIndexToOwner[_tokenId];
        return (_spender == ownerAddress ||
            tokenApprovals[_tokenId] == _spender ||
            operatorApprovals[ownerAddress][_spender]);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override {
        require(_to != address(0), "Reciever must not be dead address!");
        require(
            isApprovedOrOwner(_from, _tokenId) ||
                isApprovedForAll(_from, msg.sender)
        );
        require(exists(_tokenId), "Token Id does not exist");

        _transfer(_from, _to, _tokenId);
    }

    function _safeTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) internal {
        _transfer(_from, _to, _tokenId);
        require(_checkERC721Support(_from, _to, _tokenId, _data));
    }

    function _checkERC721Support(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) internal returns (bool) {
        if (!_isContract(_to)) {
            return true;
        }
        //Call onERC721Received in the _to contract
        bytes4 returnData = IERC721Receiver(_to).onERC721Received(
            msg.sender,
            _from,
            _tokenId,
            _data
        );
        //Check return value
        return returnData == MAGIC_ERC721_RECEIVED;
    }

    //Need to check codesize > 0 here...
    function _isContract(address _to) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_to)
        }
        return size > 0;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external override {
        require(_to != address(0));
        require(exists(_tokenId), "Not a valid tokenId");
        require(_tokenId < kitties.length);
        require(
            msg.sender == _from ||
                isApprovedOrOwner(_from, _tokenId) ||
                isApprovedForAll(_from, msg.sender)
        );
        _safeTransfer(_from, _to, _tokenId, _data);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override {
        require(owns(_from, _tokenId));
        require(_to != address(0));
        require(
            msg.sender == _from ||
                isApprovedOrOwner(_from, _tokenId) ||
                isApprovedForAll(_from, msg.sender)
        );
        require(_tokenId < kitties.length);

        _safeTransfer(_from, _to, _tokenId, "");
    }
}
