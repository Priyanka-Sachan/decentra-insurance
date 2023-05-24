// SPDX-License-Identifier:MIT
pragma solidity >=0.8.1 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./insuranceToken.sol";

contract IRegister{

    error IRegister__NotEnoughtMoney();
    error IRegister__NotAuthor();
    error IRegister__NotNFTOwner();
    error IRegister__NotPolicyOwner();
    error IRegister__PolicyDoesNotExist();
    error IRegister__TransferFailed();
    error IRegister__LatePremiumInstallment();
    error IRegister__PolicyExpired();

    // Multiple insurance types
    enum InsuranceType {WORKABLE, REGULAR, PREMIUM}

    //  All declared prices are in ETH
    uint256[] public premiumRates =[10,15,20];
    uint256[] public maxClaim=[1*10**6,5*10**6,10*10**6];
    uint256[] public coverage=[90,80,80];
    uint256 public premiumDelayFine=1;

    // Contract Deployer
    // Used to edit token contract address
    address i_author;
    address itoken_address;
    IToken itoken;

    struct Policy{
        address owner;
        address nftContract;
        uint256 tokenId;
        uint256 declaredPrice;
        uint256 applicationDate;
        uint256 expirationDate;
        InsuranceType insuranceType;
        uint256 premium;
        uint256 currentInstallment;
    }
    mapping(uint256=>Policy) public policies;
    uint256 public policy_count=0;

    constructor (){
        i_author = msg.sender;
    }

    modifier isAuthor(address sender){
        if(i_author!=sender) revert IRegister__NotAuthor();
        _;
    }

    modifier isNFTOwner(
        address nftAddress,
        uint256 tokenId,
        address sender
    ) {
        // For now, don't check
        // IERC721 nft = IERC721(nftAddress);
        // if (nft.ownerOf(tokenId) != sender) revert IRegister__NotNFTOwner();
        _;
    }

    modifier isPolicyOwner(
        uint256 id,
        address sender
    ) {
        if (policies[id].owner != sender) revert IRegister__NotPolicyOwner();
        _;
    }

    modifier policyExist(
        uint256 id
    ) {
        if (policies[id].owner == address(0)) revert IRegister__PolicyDoesNotExist();
        _;
    }

    // Function to set IToken contract address by owner
    function setITokenAddress(address itoken_address) public isAuthor(msg.sender){
        itoken_address=itoken_address;
        itoken=IToken(itoken_address);
    }

    // Function to calculate premium based on given parameters
    function checkPremium (address nftContract, uint256 tokenId, uint256 declaredPrice, InsuranceType insuranceType) public returns (uint256) {
        // Ideal Case
        // Use a oracle to get predicted premium price using a ML Model
        uint256 premium = declaredPrice*premiumRates[uint256(insuranceType)]/(12*100);
        return premium;
    }

    // Function to apply for insurance
    function applyInsurance(address nftContract, uint256 tokenId, uint256 declaredPrice, InsuranceType insuranceType) public isNFTOwner(nftContract,tokenId,msg.sender) returns (uint256) {
        uint256 premiumValue=checkPremium(nftContract,tokenId,declaredPrice,insuranceType);
        policies[policy_count]=Policy({owner:msg.sender,
                                    nftContract:nftContract,
                                    tokenId:tokenId,
                                    declaredPrice:declaredPrice,
                                    applicationDate:block.timestamp,
                                    expirationDate:block.timestamp + 365 days,
                                    insuranceType:insuranceType,
                                    premium:premiumValue,
                                    currentInstallment:0});
        policy_count++;
        // A governance token IToken is transfered to policyholder
        itoken.mintInsToken(msg.sender,premiumValue);
        return (policy_count-1);
    }

    // Function to pay insurance premium every 30 days
    function payPremium(uint256 id) payable public policyExist(id){
        if(msg.value<policies[id].premium) 
            revert IRegister__NotEnoughtMoney();
        if((block.timestamp - policies[id].applicationDate)/60 /60 /24 /30 >policies[id].currentInstallment )
            revert IRegister__LatePremiumInstallment();
        policies[id].currentInstallment+=1;
    }

    // Function to pay insurance late premium
    function payLatePremium(uint256 id) payable public policyExist(id){
        uint256 delay=(block.timestamp - policies[id].applicationDate)/60 /60 /24 /30 -policies[id].currentInstallment ;
        if(msg.value<policies[id].premium + delay*premiumDelayFine) 
            revert IRegister__NotEnoughtMoney();
        policies[id].currentInstallment+=1;
    }    

    // Function to claim insurance
    function claim(uint256 id) public isPolicyOwner(id,msg.sender) policyExist(id){
        // Ideal Case
        // Use a oracle to get data about current hacks and claim validity
        // Voting by all IToken holders
        if(block.timestamp>policies[id].expirationDate)
            revert IRegister__PolicyExpired();
        InsuranceType insuranceType=policies[id].insuranceType;
        uint256 maxClaimValue=maxClaim[uint(insuranceType)];
        uint256 coverageValue=coverage[uint(insuranceType)]*(policies[id]).declaredPrice/100;
        uint256 claimValue= maxClaimValue<coverageValue?maxClaimValue:coverageValue;
       (bool success, ) = payable(msg.sender).call{value: claimValue}("");
        if (!success) revert IRegister__TransferFailed();
    }

    // Function to check liquidity
    function liquidityCheck() public view returns(uint256) {
        return address(this).balance;
    }

}