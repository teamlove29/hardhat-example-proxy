// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IHouseToken is IERC721 {

    event HouseCreated(uint256 indexed tokenId);

    event MinterUpdated(address minter);

    event MinterLocked();

    event PlanformAddressUpdated(address planformAdress);

    function mint() external returns (uint256);

    function setMinter(address minter) external;

    function lockMinter() external;
}
