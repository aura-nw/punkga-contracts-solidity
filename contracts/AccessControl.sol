// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AccessControl {
    using SafeERC20 for IERC20;

    address payable public owner;
    mapping(address => bool) public operators;

    event SetOperator(address indexed add, bool value);

    error OnlyOwnerAllowed();
    error OnlyOperatorAllowed();
    error ZeroAddressNotAllowed();

    constructor(address _ownerAddress) {
        owner = payable(_ownerAddress);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwnerAllowed();
        }
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) {
            revert OnlyOperatorAllowed();
        }
        _;
    }    

    function setOwner(address payable _newOwner) external onlyOwner {
        if (_newOwner == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        owner = _newOwner;
    }

    function setOperator(address _operator, bool _v) external onlyOwner {
        operators[_operator] = _v;
        emit SetOperator(_operator, _v);
    }    

    function emergencyWithdraw(address _token, address payable _to, uint256 amount) external onlyOwner {
        if (_token == address(0x0)) {
            amount = amount != 0 ? amount : address(this).balance;
            payable(_to).transfer(amount);
        }
        else {
            amount = amount != 0 ? amount : IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(_to, amount);
        }
    }
}
