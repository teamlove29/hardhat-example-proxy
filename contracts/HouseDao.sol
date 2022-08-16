pragma solidity ^0.8.9;
// SPDX-License-Identifier: Unlicensed

import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { ERC721 } from './base/ERC721.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IWETH } from './interface/IWETH.sol';
import { WorldicianToken } from './WorldicianToken.sol';

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract HouseDAO is OwnableUpgradeable, ReentrancyGuardUpgradeable{
    using SafeMath for uint256;

    WorldicianToken public worldician;

    address public weth;

    uint256 private _tTotal; // จำนวนเงินที่ฝากเข้ามาทั้งหมด

    uint256 public balanceContract; // จำนวนเงินที่อยู่ใน contract

    struct Share{
        uint256 worldicianId;
        uint256 amount;
        uint256 lastClaim;
    }

    mapping(uint256 => Share) private _shares;

    event Deposited(address from, uint256 amount, uint256 time);
    event Claimed(uint256 worldicianId, address from, uint256 amount, uint256 time);

    constructor(address _worldician, address _weth){
        _transferOwnership(msg.sender);
        weth = _weth;
        worldician = WorldicianToken(_worldician);
    }

    function deployerDeposit() external payable onlyOwner{
        require(msg.value > 0 , "HouseDAO: Must deposit more zero");
        _tTotal += msg.value;
        balanceContract += msg.value;
    } 

    // 0xc778417E063141139Fce010982780140Aa0cD5Ab weth
    function claimShare(uint256 _worldicianId) external nonReentrant{
        require(worldician.ownerOf(_worldicianId) == msg.sender,"HouseDAO: Owner only can claim");

        uint256 _amountClaim =  _getAmountClaim();
        Share memory _share  = _shares[_worldicianId]; 

        uint256 _claim = _amountClaim.sub(_share.amount); // จำนวนที่เคลมได้ทั้งหมด - จำนวนที่ที่เคยรับมาแล้ว = จำนวนที่จะเคลมได้
        require(_claim > 0, "HouseDAO: Claimed");

        _shares[_worldicianId] = Share({
            worldicianId: _worldicianId,
            amount: _amountClaim, // จำนวนที่เคลมแล้วทั้งหมด
            lastClaim: block.timestamp
        });

        balanceContract -= _claim;
        _safeTransferETHWithFallback(msg.sender,_claim);
        emit Claimed(_worldicianId, msg.sender, _claim, block.timestamp);
    }

     function claimMutilShare(uint256[] memory _worldicianId) external nonReentrant{
         uint256 _totalClaim = 0;

         for(uint i; i < _worldicianId.length; i++){
            require(worldician.ownerOf(_worldicianId[i]) == msg.sender,"HouseDAO: Owner only can claim");
            uint256 _amountClaim =  _getAmountClaim();
            Share memory _share  = _shares[_worldicianId[i]]; 
            uint256 _claim = _amountClaim.sub(_share.amount); // จำนวนที่เคลมได้ทั้งหมด - จำนวนที่ที่เคยรับมาแล้ว = จำนวนที่จะเคลมได้
            require(_claim > 0, "HouseDAO: Claimed");

            _shares[_worldicianId[i]] = Share({
                worldicianId: _worldicianId[i],
                amount: _amountClaim,
                lastClaim: block.timestamp
            });

            _totalClaim += _claim;
            emit Claimed(_worldicianId[i], msg.sender, _claim, block.timestamp);
         }

        balanceContract -= _totalClaim;
        _safeTransferETHWithFallback(msg.sender,_totalClaim);
    }

    function getShare(uint256 _worldicianId) external view returns(uint256 worldicianId,uint256 amount,uint256 lastClaim){
        Share memory _share  = _shares[_worldicianId]; 
        return(_share.worldicianId,_share.amount,_share.lastClaim);
    }

    function canClaim(uint256 _worldicianId) external view returns(uint256){
        assert(_worldicianId <= worldician.totalSupply());
        uint256 _amountClaim =  _getAmountClaim();
        return _amountClaim.sub(_shares[_worldicianId].amount);
    }

    function _getAmountClaim() internal view returns(uint256){
        uint256 _sharePower = 1;
        uint256 _maxSupply = worldician.maxSupply();
        uint256 _amountPerShare = _tTotal.div(_maxSupply);
        uint256 _amountClaim = _sharePower.mul(_amountPerShare);
        assert(_amountClaim.mul(_maxSupply) <= _tTotal);
        return _amountClaim;
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