// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC777/IERC777Recipient.sol)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/interfaces/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "./i-fee-calculater.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Simple777Recipient
 * @dev Very simple ERC777 Recipient
 */
contract FeeRecieverBasic is IERC777Recipient, IFeeCalculater, Ownable {

    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 private constant _GU_FEE_RECIEVER_INTERFACE_HASH = keccak256("GUFeeReciever");

    uint256 private maxInt = 2**256 - 1;
    IERC777 private _token;

    mapping(address => uint256) private _recieverPercentage;
    address[] private _recievers;
    uint256 _totalFeePercentage;

    event TokenReceived(address operator, address from, address to, uint256 amount, bytes userData, bytes operatorData);

    constructor (address token) {
        _token = IERC777(token);

        _erc1820.setInterfaceImplementer(address(this), _TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
        _erc1820.setInterfaceImplementer(address(this), _GU_FEE_RECIEVER_INTERFACE_HASH, address(this));
    }

    function calculateFee(uint256 amount) public virtual override view returns(uint256) {
        uint256 fee = 0;
        for ( uint i = 0; i < _recievers.length; i++ ) {
            fee = fee + amount * _recieverPercentage[_recievers[i]] / 10000;
        }
        return fee;
    }

    function registerReciever(address reciever, uint256 ratio) public {
        require(ratio < 10000, "Retio must be lower than 10000");
        _recievers.push(reciever);
        _recieverPercentage[reciever] = ratio;
        _totalFeePercentage = _totalFeePercentage + ratio;
    }
    
    // function removeReciever(address reciever) public {
    //     _recievers.push(reciever);
    //     _recieverPercentage[reciever] = ratio;
    //     _totalFeePercentage = _totalFeePercentage + ratio;
    // }

    // function revokeReciever(address reciever) {
    //     delete(_recieverPercentage[address]);
    // }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external virtual override {
        require(msg.sender == address(_token), "FeeRecipent: Invalid token");
        require(amount < maxInt / 10000, "");
        if (amount != 0) {
            emit TokenReceived(operator, from, to, amount, userData, operatorData);   
            console.log("from %s", from);
            console.log("this %s", address(this));
            if ( from != address(this) ) {            
                for ( uint i = 0; i < _recievers.length; i++ ) {
                    uint256 fee = amount * _recieverPercentage[_recievers[i]] / _totalFeePercentage;
                    console.log("amount %s", amount);
                    console.log("_recieverPercentage %s", _recieverPercentage[_recievers[i]]);
                    console.log("fee %s", fee);
                    _token.send(_recievers[i], fee, "");
                }
            }
        }

    }
}