// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "hardhat/console.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */


/**
 * @title RaffleHouse
 * @dev Facilitate Raffles
 */
contract RaffleHouse is VRFConsumerBaseV2{
    uint256 private constant ROLL_IN_PROGRESS = 42;


    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Mumbaio coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords =  1;

    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    //using these two maps to assign vrf results to id
    // map rollers to requestIds
    mapping(uint256 => uint) private s_rollers;
    // map vrf results to rollers
    mapping(uint => uint256) private s_results;


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

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
  }

        // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint _raffleId) internal {
        require(s_results[_raffleId] == 0, 'Already rolled');
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );

        s_rollers[s_requestId] = _raffleId;
        s_results[_raffleId] = ROLL_IN_PROGRESS;
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_results[s_rollers[s_requestId]] = randomWords[0];    
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
        requestRandomWords(_raffleId);
        // Raffles[_raffleId].winner = Raffles[_raffleId].entries[0];
    }

    function withdrawPrize(uint _raffleId) public payable {
        require(s_results[_raffleId] != 0, "Raffle hasn't ended. Call endRaffle or wait for reserve to be met!");
        require(s_results[_raffleId] != ROLL_IN_PROGRESS, "endRaffle call still in progress!");
        require(Raffles[_raffleId].status == RaffleStatus.ACTIVE, "Prizes already withdrawn!");
        require(Raffles[_raffleId].nftCollectionAddress != address(0), "Raffle does not exist!");
        // require(Raffles[_raffleId].winner != address(0x0), "Winner has not been selected yet!");

        Raffles[_raffleId].winner = Raffles[_raffleId].entries[s_results[_raffleId] % Raffles[_raffleId].entries.length];

        ERC721(Raffles[_raffleId].nftCollectionAddress).transferFrom(address(this), Raffles[_raffleId].winner,  Raffles[_raffleId].nftTokenId);

        Raffles[_raffleId].status = RaffleStatus.FINISHED;
        
        (bool sent, ) = payable(Raffles[_raffleId].owner).call{value: Raffles[_raffleId].ticketsBought*Raffles[_raffleId].ticketPrice}("");
        require(sent, "Failed to send Ether");
        console.log("Raffle Winner", Raffles[_raffleId].winner , " has withdrawn prize!");

    }

    function getRaffleCount() public view returns (uint) {
        return raffleCount.current();
    }



}