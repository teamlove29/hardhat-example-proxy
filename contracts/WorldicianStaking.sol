// SPDX-License-Identifier: MIT LICENSE

/// @title The Worldician Staking Contract

pragma solidity ^0.8.6;

import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { IERC1155 } from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import { ERC721Holder } from '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import { ERC1155Holder } from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import { WorldicianToken } from './WorldicianToken.sol';

contract NFTStaking is ERC721Holder, ERC1155Holder{

    WorldicianToken public worldicianToken;

    struct Stake {
        // erc721 | erc1155
        address nftAddress;
        // index of unstake
        uint256 index;
        // tokenId of nft
        uint256 tokenId;
        // amount nft
        uint256 amount;
        // worldicianId of worldicianToken
        uint256 worldicianId;
        // owner of nft
        address owner;
    }

    mapping(address => Stake[]) private _stakes;
    mapping(address => uint256) public stakedOfOwner;

    bytes4 private _ERC721Interface = 0x80ac58cd;
    bytes4 private _ERC1155Interface = 0xd9b67a26;

    event NFTStaked(address nftAddress,address owner, uint256 tokenId, uint256 value);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 value);

    constructor(address _worldicianToken) {
        worldicianToken = WorldicianToken(_worldicianToken);
    }

    function stakeNFT(uint256 _worldicianId, address[] memory _NFTAddress,uint256[] memory _tokenIds, uint256[] memory _amounts) external {
        require(worldicianToken.ownerOf(_worldicianId) == msg.sender,"WorldicianStaking: not owner worldician");
        stakedOfOwner[msg.sender] += _tokenIds.length;

        for(uint i = 0; i < _NFTAddress.length; i++) {
            require(_NFTAddress[i] != address(worldicianToken),"WorldicianStaking: WorldicianToken can not stake");
                Stake memory _newStakes = Stake({
                    nftAddress: _NFTAddress[i],
                    index: _stakes[msg.sender].length,
                    worldicianId: _worldicianId,
                    tokenId: _tokenIds[i],
                    amount: _amounts[i],
                    owner: msg.sender
                });

                _stakes[msg.sender].push(_newStakes);
                if(IERC1155(_NFTAddress[i]).supportsInterface(_ERC1155Interface)) {
                    IERC1155(_NFTAddress[i]).safeTransferFrom(msg.sender,address(this), _tokenIds[i], _amounts[i], "0x00");
                }else{
                    IERC721(_NFTAddress[i]).safeTransferFrom(msg.sender,address(this), _tokenIds[i], "0x00");
                }
                emit NFTStaked(_NFTAddress[i],msg.sender,_tokenIds[i],_amounts[i]);
        }  
    }

    function unStakeNFT(uint256[] memory _index) external {
        for(uint i = 0; i < _index.length; i++) {
            require(_index.length <= _stakes[msg.sender].length,"WorldicianStaking: No data");
            Stake memory _stake = _stakes[msg.sender][_index[i]];
            require(_stake.nftAddress != address(0),"WorldicianStaking: NFT unstaked");
            require(_stake.owner == msg.sender,"WorldicianStaking: Not an owner");

            stakedOfOwner[msg.sender] -= 1;
            delete _stakes[msg.sender][_index[i]];

            if(IERC1155(_stake.nftAddress).supportsInterface(_ERC1155Interface)) {
                IERC1155(_stake.nftAddress).safeTransferFrom(address(this),msg.sender, _stake.tokenId, _stake.amount, "0x00");
            }else{
                IERC721(_stake.nftAddress).transferFrom(address(this),msg.sender, _stake.tokenId);
            }
            emit NFTUnstaked(msg.sender, _stake.tokenId, block.timestamp);
        }
    }

    function ownerOfStake(address _owner, uint256 _index) external view returns(address nftAddress, uint256 worldicianId, uint256 index ,uint256 tokenId,uint256 amount,address owner){
        Stake memory _stake = _stakes[_owner][_index];
        return (_stake.nftAddress,_stake.worldicianId, _stake.index, _stake.tokenId,_stake.amount,_stake.owner);
    }
}

