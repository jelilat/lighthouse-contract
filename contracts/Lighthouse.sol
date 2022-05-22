// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Lighthouse {
    /** ---------------------Lighthouse Declarations------------------------- */
    IERC20 public _acceptedToken; // accepted token contract
    IERC721 _acceptedNFT; // accepted NFT contract
    struct Bookings {
        uint256 checkinTime;
        uint256 checkoutTime;
        address tenant;
    }
    struct Apartment {
        uint256 id;
        uint256 costPerNight;
        uint256 checkinTime;
        uint256 checkoutTime;
        uint256 numberOfBookings;
        address landlord;
        address tenant;
    }
    struct Loan {
        uint16 ownership;
        uint256 ending;
        uint256 debt;
    }
    struct Users {
        uint256[] apartmentNumber;
        uint256 earnings;
        uint256 timeRegistered; // when they registered an apartment (if applicable)
        uint16 typeofUser; // 1 = landlord, 0 = tenant
        Loan loan;
    }
    struct Liquidity {
        mapping(address => uint256) providers;
        uint256 totalLiquidity;
        uint256 Gains;
    }
    Liquidity public liquidity;
    mapping (address => Users) users;
    mapping (uint256 => Apartment) apartments;
    uint256 listedApartments;

    /** ---------------------Constructor------------------------- */

    constructor(
        IERC20 acceptedToken,
        IERC721 acceptedNFT
        ) {
            _acceptedToken = acceptedToken;
            _acceptedNFT = acceptedNFT;
    }

    /** ---------------------Write Functions------------------------- */

    /* @dev: add a new apartment to the Lighthouse contract
    * @param: landlord: address of the landlord
    * @param: costPerNight: cost per night of the apartment
    **/
    function registerApartment(
        uint256 costPerNight,
        uint256 tokenId
    ) public {
        require(_acceptedNFT.ownerOf(tokenId) == msg.sender, "You are not the owner of this NFT");
       _acceptedNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 totalApartments = listedApartments;
        listedApartments++;
        
        apartments[totalApartments] = Apartment(
            tokenId,
            costPerNight,
            0,
            0,
            0,
            msg.sender,
            address(0)
        );
        (users[msg.sender].apartmentNumber).push(totalApartments);
        if (users[msg.sender].typeofUser == 0) {
            users[msg.sender] = Users (
                users[msg.sender].apartmentNumber,
                0,
                block.timestamp,
                1,
                Loan(100, block.timestamp, 0)
            );
        }
    }

    modifier booking (
        uint256 apartmentNumber,
        uint256 checkoutTime
    ) {
        require(apartments[apartmentNumber].landlord != address(0), "Unlisted apartment");
        require(apartments[apartmentNumber].landlord != msg.sender, "You are the owner");
        require(apartments[apartmentNumber].checkoutTime <= block.timestamp, "Apartment is not available");

        _;
    }

    /* @dev: add a new tenant to the Lighthouse contract
    * @param: apartmentNumber: number of the apartment
    * @param: user: address of the tenant
    **/
    function bookApartment(
        uint256 apartmentNumber,
        uint256 checkoutTime
    ) public payable booking(apartmentNumber, checkoutTime){
        uint256 duration = checkoutTime - block.timestamp;
        uint256 cost = apartments[apartmentNumber].costPerNight * duration;
        bool transferred = _acceptedToken.transferFrom(msg.sender, address(this), cost);
        require(transferred, "Transfer failed. Approve contract to spend token");

        apartments[apartmentNumber].numberOfBookings += 1;
        apartments[apartmentNumber].tenant = msg.sender;
        apartments[apartmentNumber].checkinTime = block.timestamp;
        apartments[apartmentNumber].checkoutTime = checkoutTime;
            
        address landlord = apartments[apartmentNumber].landlord;
        
        uint256 ownership = (users[landlord].loan).ownership;
        users[landlord].earnings = (cost * ownership) / 100;
    }

    function withdrawEarnings(uint256 amount) public {
        require(users[msg.sender].earnings >= amount, "You don't have enough earnings");

        _acceptedToken.transfer(msg.sender, amount);
    }

    function unListApartment(uint256 apartmentId) public {
        require(apartments[apartmentId].landlord == msg.sender, "You are not the owner");
        require(apartments[apartmentId].tenant == address(0), "Apartment is not available");

        apartments[apartmentId] = Apartment(
            apartments[apartmentId].id,
            0,
            0,
            0,
            0,
            address(0),
            address(0)
        );
        _acceptedNFT.safeTransferFrom(address(this), msg.sender, apartments[apartmentId].id);
    }

    /**---------------------------------Loan-------------------------------- */

    function addLiquidity(uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than 0");
        bool transferred = _acceptedToken.transferFrom(msg.sender, address(this), amount);
        require(transferred, "Transfer failed. Approve contract to spend token");

        uint256 totalInvestment = amount;
        if ((liquidity.providers)[msg.sender] != 0) {
            totalInvestment += (liquidity.providers)[msg.sender];
        }

        (liquidity.providers)[msg.sender] = totalInvestment;

        liquidity.totalLiquidity += amount;
    }

    function removeLiquidity(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require((liquidity.providers)[msg.sender] >= amount, "You don't have enough liquidity");

        uint256 investment = (liquidity.providers)[msg.sender];
        uint256 shares = (investment * 100)/liquidity.totalLiquidity;
        uint256 gains = (shares * liquidity.Gains)/100;
        uint256 total = gains + amount;

        (liquidity.providers)[msg.sender] = investment - amount;

        liquidity.totalLiquidity -= amount;
        liquidity.Gains -= gains;
        
        _acceptedToken.transfer(msg.sender, total);
    }

    function borrow(uint256 amount, uint256 end) public {
        require(users[msg.sender].typeofUser == 1, "You are not a landlord");
        require(amount > 0, "Amount must be greater than 0");

        uint256 duration = block.timestamp - users[msg.sender].timeRegistered;
        uint256 earnings = users[msg.sender].earnings;

        uint256 averageEarnings = earnings/duration;

        uint256 credit = averageEarnings * (end - block.timestamp);
        uint256 creditWorthiness = (80 * credit)/100;

        require(creditWorthiness > amount, "You are not creditworthy");

        uint16 amountPercent = uint16((amount * 100)/creditWorthiness);
        users[msg.sender].loan = Loan (
            100 - amountPercent,
            end,
            amount
        );
        
        _acceptedToken.transfer(msg.sender, amount);
    }

    function completeLoan() public {
        require(users[msg.sender].loan.ending <= block.timestamp, "Payment duration not completed");
        require(users[msg.sender].loan.ownership != 100 || users[msg.sender].loan.ownership != 0, "You don't have a loan");

        users[msg.sender].loan = Loan (
            100,
            block.timestamp, 
            0
        );
    }

    /** ---------------------Read Functions------------------------- */

    function getApartment(uint256 apartmentNumber) public view returns(Apartment memory) {
        return apartments[apartmentNumber];
    }

    function getUser(address user) public view returns(Users memory) {
        return users[user];
    }

    function getListedApartments() public view returns(uint256) {
        return listedApartments;
    }

    function getUserApartments(address user) public view returns(uint256[] memory) {
        return users[user].apartmentNumber;
    }

    function getLoan() public view returns(Loan memory) {
        return users[msg.sender].loan;
    }

    function getLiquidity(address landlord) public view returns(uint256) {
        return liquidity.providers[landlord];
    }

    function getProfit(address provider) public view returns(uint256) {
        uint256 ProvidedLiquidity = liquidity.providers[provider];
        uint256 shares = (ProvidedLiquidity * 100)/liquidity.totalLiquidity;

        return (shares * liquidity.Gains)/100;
    }

    function getEarnings(address landloard) public view returns(uint256) {
        return users[landloard].earnings;
    }
}