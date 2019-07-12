pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-solidity/contracts/introspection/ERC165.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract Token is ERC165, ERC721 {
    using SafeMath for uint256;

    // The address of the contract
    address internal creator;

    // The highest valid tokenId, for checking if a tokenId is valid
    uint256 internal maxId;

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

    constructor(uint256 _initialSupply) public {
        // Store the address of the creator
        creator = msg.sender;

        // All initial tokens belongs to the creator
        balances[msg.sender] = _initialSupply;

        // Set maxId to the number of tokens
        maxId = _initialSupply;

        _registerInterface(_INTERFACE_ID_ERC721);
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

        // We have to emit an event for each token that gets created
        for (uint256 i = maxId.add(1); i <= maxId.add(_extraTokens); i++) {
            emit Transfer(address(0), creator, i);
        }

        maxId = maxId.add(_extraTokens);
    }

    function burnToken(uint256 _tokenId) external {
        address owner = ownerOf(_tokenId);
        require(owner == msg.sender || allowance[_tokenId] == msg.sender || authorised[owner][msg.sender]);
        burned[_tokenId] = true;
        balances[owner]--;

        emit Transfer(owner, address(0), _tokenId);
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
}
