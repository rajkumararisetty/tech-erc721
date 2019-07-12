pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Metadata.sol";
import "./Token.sol";

contract TokenERC721Metadata is Token, ERC721Metadata {
    string private __name;
    string private __symbol;
    bytes private __uriBase;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    constructor(uint256 _initialSupply, string memory _name, string memory _symbol, string memory _uriBase) public Token(_initialSupply) {
        __name = _name;
        __symbol = _symbol;
        __uriBase = bytes(_uriBase);

        // Add to ERC165 interface che
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    }

    function name() external view returns (string memory _name){
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
}
