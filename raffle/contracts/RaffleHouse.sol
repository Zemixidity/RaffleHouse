// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "hardhat/console.sol";

/**
 * @title RaffleHouse
 * @dev Facilitate Raffles
 */

contract RaffleHouse {

    using Counters for Counters.Counter;
    Counters.Counter private raffleCount;

    enum RaffleStatus{ACTIVE, FINISHED}


    struct Raffle {
        address owner;
        address nftCollectionAddress;
        uint nftTokenId;
        uint reservePrice;
        uint ticketPrice;
        uint ticketsBought;
        address winner;
        address[] entries;
        uint raffleId;
        RaffleStatus status;
    }

    mapping (uint => Raffle) public Raffles;

    constructor() {
        
    }


    function createRaffle(address _nftCollectionAddress, uint _nftTokenId, uint _reservePrice, uint _ticketPrice ) public {
        Raffles[raffleCount.current()] = Raffle(msg.sender, _nftCollectionAddress, _nftTokenId, _reservePrice, _ticketPrice, 0,  address(0), new address[](0), raffleCount.current(), RaffleStatus.ACTIVE);
      

        ERC721(_nftCollectionAddress).transferFrom(msg.sender, address(this), _nftTokenId);
        raffleCount.increment();

    }

    function buyRaffleTickets(uint _raffleId,uint  _numTickets) public payable {
        require(Raffles[_raffleId].nftCollectionAddress != address(0), "Raffle does not exist!");
        require(msg.value >= Raffles[_raffleId].ticketPrice * _numTickets, "Did not pay for desired number of tickets!");
        for (uint i = 0; i < _numTickets; i++) {
            Raffles[_raffleId].entries.push(msg.sender);
        }
        Raffles[_raffleId].ticketsBought += _numTickets;

    }

    function endRaffle(uint _raffleId) public {
        require(Raffles[_raffleId].nftCollectionAddress != address(0), "Raffle does not exist!");
        require(Raffles[_raffleId].winner == address(0x0), "Raffle has already ended!");
        require(Raffles[_raffleId].ticketsBought*Raffles[_raffleId].ticketPrice >= Raffles[_raffleId].reservePrice, "Reserve price not met!");
        Raffles[_raffleId].winner = Raffles[_raffleId].entries[0];
    }

    function withdrawPrize(uint _raffleId) public payable {
        require(Raffles[_raffleId].status == RaffleStatus.ACTIVE, "Prizes already withdrawn!");
        require(Raffles[_raffleId].nftCollectionAddress != address(0), "Raffle does not exist!");
        require(Raffles[_raffleId].winner != address(0x0), "Winner has not been selected yet!");

        ERC721(Raffles[_raffleId].nftCollectionAddress).transferFrom(address(this), Raffles[_raffleId].winner,  Raffles[_raffleId].nftTokenId);

        Raffles[_raffleId].status = RaffleStatus.FINISHED;
        
        (bool sent, ) = payable(Raffles[_raffleId].owner).call{value: Raffles[_raffleId].ticketsBought*Raffles[_raffleId].ticketPrice}("");
        require(sent, "Failed to send Ether");
        console.log("Raffle Winner", Raffles[_raffleId].winner , " has withdrawn prize!");

    }



}