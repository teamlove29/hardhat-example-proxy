// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { ERC721 } from './base/ERC721.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IWETH } from './interface/IWETH.sol';

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

contract WorldicianADS is ReentrancyGuardUpgradeable, OwnableUpgradeable{

    using SafeMath for uint256;

    ERC721 public worldicianToken;

    address public deployer;

    address public treasury;

    address public weth;

    struct Slot {
        bool isActive; // status turn-on // turn-off
        uint256 duration; // per sec
        uint256 price; // per sec (wei)
        address fromAddress; // by
        uint256 startTime;
        uint256 endTime;
        string url; // link ads
    }

    // WorldicianId => Slot => Detail
    mapping (uint256 => Slot[] ) private _ads;

    event AdsStart(uint256 worldicianId,uint256 slot, uint256 startTime, uint256 endTime, address fromAddress);
    event AdsCreateSlot(uint256 worldicianId,uint256 slot,uint256 duration, uint256 price);
    event AdsEditSlot(uint256 worldicianId,uint256 slot);
    event AdsRemoveSlot(uint256 worldicianId,uint256 slot);

    constructor(address _worldicianToken, address _weth, address _deployer, address _treasury){
        worldicianToken = ERC721(_worldicianToken);
        weth = _weth;
        deployer = _deployer;
        treasury = _treasury;
        _transferOwnership(msg.sender);
    }

    function createSlot(uint256 _worldicianId,uint256 _duration, uint256 _price) public {
        require(worldicianToken.ownerOf(_worldicianId) == msg.sender,"WorldicianADS: Only owner");
        require(_duration > 0,"WorldicianADS: Duration is too low");
        require(_price > 0,"WorldicianADS: Price is too low");

        uint256 currentLength = getLengthSlot(_worldicianId);

        Slot memory _newSlot = Slot({
            isActive: true,
            duration: _duration,
            price: _price,
            fromAddress: address(0),
            startTime: 0,
            endTime: 0,
            url: ""
        });

        _ads[_worldicianId].push(_newSlot);

        emit AdsCreateSlot(_worldicianId,currentLength +1,_duration,_price);
    }

    function editSlot(uint256 _worldicianId, uint256 _slot, bool _status ,uint256 _duration, uint256 _price) public {
        uint256 currentLength = getLengthSlot(_worldicianId);
        Slot memory _stateSlot = _ads[_worldicianId][_slot];

        require(worldicianToken.ownerOf(_worldicianId) == msg.sender,"WorldicianADS: Only owner");
        require(_slot <= currentLength,"WorldicianADS: No this slot");
        require(_duration > 0,"WorldicianADS: Duration is too low");
        require(_price > 0,"WorldicianADS: Price is too low");
        require(block.timestamp > _stateSlot.endTime, "WorldicianADS: Ads running");

        _ads[_worldicianId][_slot] = Slot({
            isActive: _status,
            duration: _duration,
            price: _price,
            fromAddress: _stateSlot.fromAddress,
            startTime: _stateSlot.startTime,
            endTime: _stateSlot.endTime,
            url: _stateSlot.url
        });

        emit AdsEditSlot(_worldicianId,_slot);
    }

    function removeSlot(uint256 _worldicianId, uint256 _slot) public {
        uint256 currentLength = getLengthSlot(_worldicianId);
        Slot memory _stateSlot = _ads[_worldicianId][_slot];

        require(worldicianToken.ownerOf(_worldicianId) == msg.sender,"WorldicianADS: Only owner");
        require(_slot <= currentLength,"WorldicianADS: No this slot");
        require(block.timestamp > _stateSlot.endTime, "WorldicianADS: Ads running");

        delete _ads[_worldicianId][_slot];
        emit AdsRemoveSlot(_worldicianId,_slot);
    }

    function payForAds(uint256 _worldicianId, uint256 _slot, string memory _url) payable public nonReentrant {
        uint256 currentLength = getLengthSlot(_worldicianId);
        Slot memory _stateSlot = _ads[_worldicianId][_slot];

        require(_slot <= currentLength,"WorldicianADS: No this slot");
        require(_stateSlot.isActive,"WorldicianADS: This slot not active");
        require(block.timestamp > _stateSlot.endTime, "WorldicianADS: Ads running");
        require(msg.value >= _stateSlot.price,"WorldicianADS: ETH too low");

        uint256 _startTime = block.timestamp;
        uint256 _endTime = _startTime + _stateSlot.duration;

        _ads[_worldicianId][_slot] = Slot({
            isActive: _stateSlot.isActive,
            duration: _stateSlot.duration,
            price: _stateSlot.price,
            fromAddress: msg.sender,
            startTime: _startTime,
            endTime: _endTime,
            url: _url
        });

        _safeTransferETHWithFallback(worldicianToken.ownerOf(_worldicianId),(_stateSlot.price.mul(50)).div(100)); // ETH => Owner 50%
        _safeTransferETHWithFallback(treasury,(_stateSlot.price.mul(25)).div(100)); // ETH => Treasury 25%
        _safeTransferETHWithFallback(deployer,(_stateSlot.price.mul(25)).div(100)); // ETH => Dev 25%

        emit AdsStart(_worldicianId,_slot, _startTime, _endTime, msg.sender);

    }

    function getLengthSlot(uint256 _worldicianId) public view returns(uint256){
        return _ads[_worldicianId].length;
    }

    function getAdsTimeLeft(uint256 _worldicianId, uint256 _slot) public view returns(uint) {
        require(block.timestamp < _ads[_worldicianId][_slot].endTime, "WorldicianADS: Ads expired");
        return _ads[_worldicianId][_slot].startTime - _ads[_worldicianId][_slot].endTime;
    }

    function setWorldicianToken(address _worldicianToken) public onlyOwner{
        worldicianToken = ERC721(_worldicianToken);
    }

    function setdeployer(address _deployer) public onlyOwner{
        require(_deployer != address(0),"AuctionPlanform: Zero address");
        deployer = _deployer;
    }

    function settreasury(address _treasury) public onlyOwner{
        require(_treasury != address(0),"AuctionPlanform: Zero address");
        treasury = _treasury;
    }

    function getAds(uint256 worldicianId, uint256 _slot) public view returns(bool isActive, uint256 duration, uint256 price, address fromAddress, uint256 startTime, uint256 endTime, string memory url){
         Slot storage slot = _ads[worldicianId][_slot];
         return (slot.isActive, slot.duration, slot.price, slot.fromAddress, slot.startTime, slot.endTime, slot.url);
    }

    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{ value: amount }();
            IERC20(weth).transfer(to, amount);
        }
    }

    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }

}