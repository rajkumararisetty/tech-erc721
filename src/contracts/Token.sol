pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-solidity/contracts/introspection/ERC165.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Metadata.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Enumerable.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract Token is ERC165, ERC721, IERC721Metadata, IERC721Enumerable {
    using SafeMath for uint256;

    // The address of the contract
    address internal creator;

    // The highest valid tokenId, for checking if a tokenId is valid
    uint256 internal maxId;

    // Meta data variables
    string private __name;
    string private __symbol;
    bytes private __uriBase;

    // Enumerable variables
    uint[] internal tokenIndexes;
    mapping(uint => uint) internal indexTokens;
    mapping(address => uint[]) internal ownerTokenIndexes;
    mapping(uint => uint) internal tokenTokenIndexes;

    // A mapping storing the balance of each address
    mapping (address => uint256) internal balances;

    // mapping of burned tokens, for checking if a tokenId is valid
    // Not needed if your token can't be burnt
    mapping(uint256 => bool) internal burned;

    // A mapping of token owners
    mapping(uint256 => address) internal owners;

    // Mapping of "approved" address for each tokens
    mapping(uint256 => address) internal allowance;

    // A nested mapping for managing "operators"
    mapping (address => mapping(address => bool)) internal authorised;

    // Event
    event Transfer(address from, address to, uint256 tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    constructor(uint256 _initialSupply, string memory _name, string memory _symbol, string memory _uriBase) public {
        // Store the address of the creator
        creator = msg.sender;

        // All initial tokens belongs to the creator
        balances[msg.sender] = _initialSupply;

        // Set maxId to the number of tokens
        maxId = _initialSupply;

        uint256 _tokenId;
        for(uint i= 0; i < _initialSupply; i++) {
            _tokenId = i+1;
            tokenTokenIndexes[_tokenId] = i;
            ownerTokenIndexes[msg.sender].push(_tokenId);
            tokenIndexes.push(_tokenId);
            indexTokens[_tokenId] = i;
        }

        __name = _name;
        __symbol = _symbol;
        __uriBase = bytes(_uriBase);

        // Add to ERC165 interface 
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    function name() external view returns (string memory _name) {
        _name = __name;
    }

    function symbol() external view returns (string memory _symbol){
        _symbol = __symbol;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {

        require(isValidToken(_tokenId));

        // Prepare our tokenId bytes array
        uint256 maxLength = 78;
        bytes memory reversed = new bytes(maxLength);
        // To calculate the token length
        uint8 i = 0;
        uint256 tempId = _tokenId;
        // loop through tokenId and add string values to the array
        while(tempId != 0) {
            uint remainder = tempId % 10;
            tempId /= 10;
            // Note that for digits 0–9, the corresponding UTF-8 codes are 48–57 respectively. So we just have to add remainder+48 to get the UTF-8 code
            reversed[i++] = byte(uint8(48 + remainder));
        }

        // Prepare final array
        bytes memory s = new bytes(__uriBase.length + i);
        uint j;

        //add the base to the final array 
        for (j = 0; j < __uriBase.length; j++) {
            s[j] = __uriBase[j];
        }

        // add the tokenId to the final array
        for (j = 0; j < i; j++) {
            s[j + __uriBase.length] = reversed[i - 1 - j];
        }

        return string(s);
    }

    // balance of owner
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function isValidToken(uint256 _tokenId) internal view returns(bool) {
        return _tokenId != 0 && _tokenId <= maxId && !burned[_tokenId];
    }

    // Owner of a tokenId
    function ownerOf(uint256 _tokenId) public view returns (address) {
        require(isValidToken(_tokenId));
        if (owners[_tokenId] != address(0)) {
            return owners[_tokenId];
        }
        return creator;
    }

    function issueTokens(uint256 _extraTokens) public {
        // Make sure only the contract creator can call this
        require(msg.sender == creator);
        balances[msg.sender] = balances[msg.sender].add(_extraTokens);

        uint thisId; //We'll reuse this for each iteration below.

        // We have to emit an event for each token that gets created
        for (uint256 i = 0; i <= _extraTokens; i++) {
            thisId = maxId.add(i).add(1); //SafeMath to be safe!
            
            //Assign the new token its index in ownerTokenIndexes        
            tokenTokenIndexes[thisId] = ownerTokenIndexes[creator].length;
            //Add the tokenId to the end of ownerTokenIndexes
            ownerTokenIndexes[creator].push(thisId);

            //Add the token to the end of tokenIndexes
            indexTokens[thisId] = tokenIndexes.length;
            tokenIndexes.push(thisId);

            emit Transfer(address(0), creator, thisId);
        }

        //Note: This used to be before the loop 
        // (loop was slightly different).
        maxId = maxId.add(_extraTokens); 
    }

    function burnToken(uint256 _tokenId) external {
        address owner = ownerOf(_tokenId);
        require(owner == msg.sender || allowance[_tokenId] == msg.sender || authorised[owner][msg.sender]);
        burned[_tokenId] = true;
        balances[owner]--;

        emit Transfer(owner, address(0), _tokenId);

        //=== Enumerable Additions ===
        uint oldIndex = tokenTokenIndexes[_tokenId];

        if(ownerTokenIndexes[owner].length -1  != oldIndex) {
            ownerTokenIndexes[owner][oldIndex] = ownerTokenIndexes[owner][ownerTokenIndexes[owner].length - 1];

            tokenTokenIndexes[ownerTokenIndexes[owner][oldIndex]] = oldIndex;
        }

        ownerTokenIndexes[owner].length--;

        delete tokenTokenIndexes[_tokenId];

        //This part deals with tokenIndexes
        oldIndex = indexTokens[_tokenId];

        if(oldIndex != tokenIndexes.length - 1) {
            // Move last token to old index;
            tokenIndexes[oldIndex] = tokenIndexes[tokenIndexes.length - 1];
        }

        tokenIndexes.length--;
    }

    function isApprovedForAll(address _owner, address _operator) public view returns(bool) {
        return authorised[_owner][_operator];
    }

    function setApprovalForAll(address _operator, bool _approved) public {
        authorised[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId) public view returns (address) {
        require(isValidToken(_tokenId));
        return allowance[_tokenId];
    }

    function approve(address _approved, uint256 _tokenId) public {
        address owner = ownerOf(_tokenId);
        require(owner == msg.sender || authorised[owner][msg.sender]);
        allowance[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        address owner = ownerOf(_tokenId);
        require(owner == msg.sender || allowance[_tokenId] == msg.sender || authorised[owner][msg.sender] == true);
        require(owner == _from);
        require(_to != address(0));
        owners[_tokenId] = _to;
        balances[_from]--;
        balances[_to]++;
        if (allowance[_tokenId] != address(0)) {
            delete allowance[_tokenId];
        }
        emit Transfer(_from, _to, _tokenId);

        //=== Enumerable Additions ===

        uint256 oldIndex = tokenTokenIndexes[_tokenId];
        if(oldIndex != ownerTokenIndexes[_from].length - 1) {
            //Move last token to old index
            ownerTokenIndexes[_from][oldIndex] = ownerTokenIndexes[_from][ownerTokenIndexes[_from].length - 1];

            //update token self reference to new position
            tokenTokenIndexes[ownerTokenIndexes[_from][oldIndex]] = oldIndex;
        }

        ownerTokenIndexes[_from].length --;
        tokenTokenIndexes[_tokenId] = ownerTokenIndexes[_to].length;
        ownerTokenIndexes[_to].push(_tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public {
        transferFrom(_from, _to, _tokenId);
        if(_to.isContract()) {
            bytes4 retval = IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(retval == _ERC721_RECEIVED);
        }
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
        safeTransferFrom(_from, _to, _tokenId, '');
    }

    function totalSupply() public view returns (uint256) {
        return tokenIndexes.length;
    }

    function tokenByIndex(uint256 _index) public view returns (uint256) {
        require(_index < tokenIndexes.length);
        return tokenIndexes[_index];
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256 tokenId) {
        require(_index < balances[_owner]);
        return ownerTokenIndexes[_owner][_index];
    }
}
