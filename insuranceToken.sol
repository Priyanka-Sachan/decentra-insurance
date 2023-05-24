// SPDX-License-Identifier:MIT
pragma solidity >=0.8.1 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract IToken is ERC721 {

    error IToken__NotEnoughETH();
    error IToken__NotRegister();
    error IToken__NoTokenLeft();
    error IToken__TokenDoesNotExist();
    error IToken__TransferFailed();

    // Address of insurance register contract
    address public iRegister_address;

	uint256 public s_govTokenCounter;
    uint256 public s_insTokenCounter;

	mapping(uint256 => uint256) public s_tokenValues;

	event TokenMinted(uint256 indexed tokenId, address indexed owner, uint256 price);
    event SendEthToRegister(uint256 amount,uint256 time);

	constructor(address register_address) ERC721("Insurance", "INS")
	{
        iRegister_address=register_address;
		s_govTokenCounter = 0;
        s_insTokenCounter=0;
	}

    modifier isRegister(address sender){
        if(iRegister_address!=sender) revert IToken__NotRegister();
        _;
    }

    // Mint Governance Tokens (maximum supply - 10000)
    function mintGovToken() public payable{
        if(s_govTokenCounter>=10000) revert IToken__NoTokenLeft();
        if(msg.value<1) revert IToken__NotEnoughETH();
        _safeMint(msg.sender, s_govTokenCounter);
		s_tokenValues[s_govTokenCounter] =  msg.value;
		emit TokenMinted(s_govTokenCounter, msg.sender, msg.value);
		s_govTokenCounter = s_govTokenCounter + 1;
        // (bool success, ) = payable(iRegister_address).call{value: msg.value}("");
        // if (!success) revert IToken__TransferFailed();
    }

    // Mint Insurance Tokens -- only for policyholders in proportion to their insurance premium 
	function mintInsToken(address insuree, uint256 insuranceValue) public isRegister(msg.sender){
        _safeMint(insuree, s_insTokenCounter+10000);
		s_tokenValues[s_insTokenCounter+10000] =  insuranceValue;
		emit TokenMinted(s_insTokenCounter+10000, insuree, insuranceValue);
        s_insTokenCounter=s_insTokenCounter+1;
    }

    // Get value of a token
	function getTokenValue(uint256 tokenId) public view returns (uint256) {
		if(!_exists(tokenId))
            revert IToken__TokenDoesNotExist();
		return s_tokenValues[tokenId];
	}

	function getGovTokenCounter() public view returns (uint256) {
		return s_govTokenCounter;
	}
}