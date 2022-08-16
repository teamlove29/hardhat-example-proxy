// SPDX-License-Identifier: GPL-3.0

/// @title The worldician DAO auction worldician

// LICENSE
// WorldicianAuction.sol is a modified version of Zora's AuctionWorldician.sol:
// https://github.com/ourzora/auction-worldician/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionWorldician.sol
//
// AuctionWorldician.sol source code Copyright Zora licensed under the GPL-3.0 license.
// With modifications by worldicianders DAO.

pragma solidity ^0.8.6;

import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IWETH } from './interface/IWETH.sol';
import { IWorldicianAuctionHouse } from './interface/IWorldicianAuctionHouse.sol';
import { IWorldicianToken } from './interface/IWorldicianToken.sol';


library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
        return c;
    }
}

contract WorldicianAuction is IWorldicianAuctionHouse, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    
    using SafeMath for uint256;
    
    // The Worldician ERC721 token contract
    IWorldicianToken public worldician;
    // HouseDAO address
    address public houseDAO;
    // Deployer address
    address public deployer;

    // The address of the WETH contract
    address public weth;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration;

    uint256 public toDeployer;
    uint256 public toTreasury;
    uint256 public toHouseDAO;

    // The active auction
    IWorldicianAuctionHouse.Auction public auction;

    /**
     * @notice Initialize the auction worldician and base contracts,
     * populate configuration values, and pause the contract.
     * @dev This function can only be called once.
     */
    function initialize(
        IWorldicianToken _worldician,
        address _weth,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init();

        _pause();

        worldician = _worldician;
        weth = _weth;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;

        toDeployer = 50;
        toTreasury = 50;
        toHouseDAO = 0;
    }

    /**
     * @notice Settle the current auction, mint a new worldician, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction() external override nonReentrant whenNotPaused {
        IWorldicianAuctionHouse.Auction memory _auction = auction;
        if (_auction.bidder == payable(0) && block.timestamp >= _auction.endTime) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            // time buffer
                auction = Auction({
                    worldicianId: _auction.worldicianId,
                    amount: 0,
                    startTime: startTime,
                    endTime: endTime,
                    bidder: payable(0),
                    settled: false
                });

                emit AuctionExtended(_auction.worldicianId, _auction.endTime);
            
        }else{
            _settleAuction();
            _createAuction();
        }
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a worldician, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid(uint256 worldicianId) external payable override nonReentrant {
        IWorldicianAuctionHouse.Auction memory _auction = auction;

        require(_auction.worldicianId == worldicianId, 'worldician not up for auction');
        require(block.timestamp < _auction.endTime, 'Auction expired');
        require(msg.value >= reservePrice, 'Must send at least reservePrice');
        require(
            msg.value >= _auction.amount + ((_auction.amount * minBidIncrementPercentage) / 100),
            'Must send more than last bid by minBidIncrementPercentage amount'
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.worldicianId, msg.sender, msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.worldicianId, _auction.endTime);
        }
    }

    /**
     * @notice Pause the worldician auction worldician.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the worldician auction worldician.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external override onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    function setNewTokenAndUpdate(address _houseToken, address _houseDAO,uint256 _toDeployer, uint256 _toTreasury,uint256 _toHouseDAO) external onlyOwner{
        _pause();
        
        worldician = IWorldicianToken(_houseToken);
        houseDAO = _houseDAO;
        toDeployer = _toDeployer;
        toTreasury = _toTreasury;
        toHouseDAO = _toHouseDAO;
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyOwner {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint256 _reservePrice) external override onlyOwner {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    function setDeployerAddress(address _newDeployer) public onlyOwner {
        require(_newDeployer != address(0),"AuctionPlanform: Zero address");
        deployer = _newDeployer;
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage) external override onlyOwner {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction() internal {
        try worldician.mint() returns (uint256 worldicianId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction = Auction({
                worldicianId: worldicianId,
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false
            });

            emit AuctionCreated(worldicianId, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the worldician is burned.
     */
    function _settleAuction() internal {
        IWorldicianAuctionHouse.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(block.timestamp >= _auction.endTime, "Auction hasn't completed");

        auction.settled = true;

        worldician.transferFrom(address(this), _auction.bidder, _auction.worldicianId);

        if (_auction.amount > 0) {
            _safeTransferETHWithFallback(owner(), _auction.amount.mul(toTreasury).div(100)); // => treasury
            _safeTransferETHWithFallback(deployer, _auction.amount.mul(toDeployer).div(100)); // => deployer
            if(houseDAO != address(0)){
                _safeTransferETHWithFallback(houseDAO, _auction.amount.mul(toHouseDAO).div(100)); // => deployer
            }
        }
        emit AuctionSettled(_auction.worldicianId, _auction.bidder, _auction.amount);
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{ value: amount }();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }
}
