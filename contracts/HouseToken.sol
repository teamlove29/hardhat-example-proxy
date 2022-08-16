// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { ERC721Checkpointable } from './base/ERC721Checkpointable.sol';
import { ERC721 } from './base/ERC721.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IWETH } from './interface/IWETH.sol';
import { IHouseToken } from './interface/IHouseToken.sol';

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

contract HouseToken is IHouseToken ,ERC721Checkpointable, Ownable, ReentrancyGuardUpgradeable{

    using SafeMath for uint256;

    address public weth;
    // An address who has permissions to mint
    address public minter;

    address public adminDAO;

    // Whether the minter can be updated
    bool public isMinterLocked;

    uint256 public maxSupply;

    // The internal Worldician ID tracker
    uint256 private _currentWorldicianId;

    string private _baseTokenURI;

    mapping (uint256 => address) internal idToOwner;
    bool public marketPaused;
    bool public contractSealed;
    mapping (address => uint256) public ethBalance;
    mapping (bytes32 => bool) public cancelledOffers;

    struct Offer {
        address maker;
        address taker;
        uint256 makerWei;
        uint256[] makerIds;
        uint256 takerWei;
        uint256[] takerIds;
        uint256 expiry;
        uint256 salt;
    }

    event OfferCancelled(bytes32 hash);
    event Deposit(address indexed account, uint amount);
    event Withdraw(address indexed account, uint amount);
    event Trade(bytes32 indexed hash, address indexed maker, address taker, uint makerWei, uint[] makerIds, uint takerWei, uint[] takerIds);


    modifier whenMinterNotLocked() {
        require(!isMinterLocked, 'Minter is locked');
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, 'Sender is not the minter');
        _;
    }

    constructor(address _minter,address _weth) ERC721('Houses', 'HOUSE') {
        minter = _minter;
        maxSupply = 10000;
        weth = _weth;
    }

    function mint() public override onlyMinter returns (uint256) {
        require(_currentWorldicianId <= maxSupply);
        if(_currentWorldicianId >= maxSupply){
            return _mintTo(adminDAO, _currentWorldicianId++);
        }else{
            return _mintTo(minter, _currentWorldicianId++);
        }
        
    }

    function setMinter(address _minter) external override onlyOwner whenMinterNotLocked {
        minter = _minter;
        emit MinterUpdated(_minter);
    }

    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;
        emit MinterLocked();
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function hashOffer(Offer memory offer) private pure returns (bytes32){
        return keccak256(abi.encode(
                    offer.maker,
                    offer.taker,
                    offer.makerWei,
                    keccak256(abi.encodePacked(offer.makerIds)),
                    offer.takerWei,
                    keccak256(abi.encodePacked(offer.takerIds)),
                    offer.expiry,
                    offer.salt
                ));
    }

    function hashToSign(address maker, address taker, uint256 makerWei, uint256[] memory makerIds, uint256 takerWei, uint256[] memory takerIds, uint256 expiry, uint256 salt) public pure returns (bytes32) {
        Offer memory offer = Offer(maker, taker, makerWei, makerIds, takerWei, takerIds, expiry, salt);
        return hashOffer(offer);
    }

    function hashToVerify(Offer memory offer) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hashOffer(offer)));
    }

    function verify(address signer, bytes32 hash, bytes memory signature) internal pure returns (bool) {
        require(signer != address(0));
        require(signature.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28);

        return signer == ecrecover(hash, v, r, s);
    }

    function tradeValid(address maker, address taker, uint256 makerWei, uint256[] memory makerIds, uint256 takerWei, uint256[] memory takerIds, uint256 expiry, uint256 salt, bytes memory signature) view public returns (bool) {
        Offer memory offer = Offer(maker, taker, makerWei, makerIds, takerWei, takerIds, expiry, salt);
        // Check for cancellation
        bytes32 hash = hashOffer(offer);
        require(cancelledOffers[hash] == false, "Trade offer was cancelled.");
        // Verify signature
        bytes32 verifyHash = hashToVerify(offer);
        require(verify(offer.maker, verifyHash, signature), "Signature not valid.");
        // Check for expiry
        require(block.timestamp < offer.expiry, "Trade offer expired.");
        // Only one side should ever have to pay, not both
        require(makerWei == 0 || takerWei == 0, "Only one side of trade must pay.");
        // At least one side should offer tokens
        require(makerIds.length > 0 || takerIds.length > 0, "One side must offer tokens.");
        // Make sure the maker has funded the trade
        require(ethBalance[offer.maker] >= offer.makerWei, "Maker does not have sufficient balance.");
        // Ensure the maker owns the maker tokens
        for (uint i = 0; i < offer.makerIds.length; i++) {
            require(idToOwner[offer.makerIds[i]] == offer.maker, "At least one maker token doesn't belong to maker.");
        }
        // If the taker can be anybody, then there can be no taker tokens
        if (offer.taker == address(0)) {
            // If taker not specified, then can't specify IDs
            require(offer.takerIds.length == 0, "If trade is offered to anybody, cannot specify tokens from taker.");
        } else {
            // Ensure the taker owns the taker tokens
            for (uint i = 0; i < offer.takerIds.length; i++) {
                require(idToOwner[offer.takerIds[i]] == offer.taker, "At least one taker token doesn't belong to taker.");
            }
        }
        return true;
    }

    function cancelOffer(address maker, address taker, uint256 makerWei, uint256[] memory makerIds, uint256 takerWei, uint256[] memory takerIds, uint256 expiry, uint256 salt) external {
        require(maker == msg.sender, "Only the maker can cancel this offer.");
        Offer memory offer = Offer(maker, taker, makerWei, makerIds, takerWei, takerIds, expiry, salt);
        bytes32 hash = hashOffer(offer);
        cancelledOffers[hash] = true;
        emit OfferCancelled(hash);
    }

    function acceptTrade(address maker, address taker, uint256 makerWei, uint256[] memory makerIds, uint256 takerWei, uint256[] memory takerIds, uint256 expiry, uint256 salt, bytes memory signature) external payable nonReentrant {
        require(!marketPaused, "Market is paused.");
        require(msg.sender != maker, "Can't accept ones own trade.");
        Offer memory offer = Offer(maker, taker, makerWei, makerIds, takerWei, takerIds, expiry, salt);
        if (msg.value > 0) {
            ethBalance[msg.sender] = ethBalance[msg.sender].add(msg.value);
            emit Deposit(msg.sender, msg.value);
        }
        require(offer.taker == address(0) || offer.taker == msg.sender, "Not the recipient of this offer.");
        require(tradeValid(maker, taker, makerWei, makerIds, takerWei, takerIds, expiry, salt, signature), "Trade not valid.");
        require(ethBalance[msg.sender] >= offer.takerWei, "Insufficient funds to execute trade.");
        // // Transfer ETH
        ethBalance[offer.maker] = ethBalance[offer.maker].sub(offer.makerWei);
        ethBalance[msg.sender] = ethBalance[msg.sender].add(offer.makerWei);
        ethBalance[msg.sender] = ethBalance[msg.sender].sub(offer.takerWei);
        ethBalance[offer.maker] = ethBalance[offer.maker].add(offer.takerWei);
        // // Transfer maker ids to taker (msg.sender)
        for (uint i = 0; i < makerIds.length; i++) {
            _transfer(maker, msg.sender, makerIds[i]);
        }
        // // Transfer taker ids to maker
        for (uint i = 0; i < takerIds.length; i++) {
            _transfer(taker,maker, takerIds[i]);
        }
        // // Prevent a replay attack on this offer
        bytes32 hash = hashOffer(offer);
        cancelledOffers[hash] = true;
        emit Trade(hash, offer.maker, msg.sender, offer.makerWei, offer.makerIds, offer.takerWei, offer.takerIds);
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

    function withdraw(uint amount) external nonReentrant {
        require(amount <= ethBalance[msg.sender]);
        ethBalance[msg.sender] = ethBalance[msg.sender].sub(amount);
        _safeTransferETHWithFallback(msg.sender,amount);
        emit Withdraw(msg.sender, amount);
    }

    function deposit() external payable {
        ethBalance[msg.sender] = ethBalance[msg.sender].add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _mintTo(address to, uint256 worldicianId) internal returns (uint256) {
        _mint(owner(), to, worldicianId);
        emit HouseCreated(worldicianId);
        return worldicianId;
    }
}