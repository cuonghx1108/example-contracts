// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

contract MultiSigWallet {
  event Deposit(address indexed sender, uint amount, uint balance);
  event SubmitTransaction(
    address indexed owner,
    uint indexed txIndex,
    address indexed to,
    uint value,
    bytes data
  );
  event ConfirmTransaction(address indexed owner, uint indexed txIndex);
  event ExecuteTransaction(address indexed owner, uint indexed txIndex);
  event RevokeTranscation(address indexed owner, uint indexed txIndex);

  struct Transaction {
    address to;
    uint value;
    bytes data;
    bool executed;
    uint numberConfirmations;
  }

  mapping (address => bool) public isOwner;
  address[] public owners;
  uint public numberConfirmRequired;
  Transaction[] public transactions;
  mapping (uint => mapping(address => bool)) isConfirmed;

  modifier onlyOwner () {
    require(isOwner[msg.sender], "not owner");
    _;
  }

  modifier txExist(uint _txIndex) {
    require(_txIndex < transactions.length);
    _;
  }

  modifier notExecuted(uint _txIndex) {
    require(!transactions[_txIndex].executed, "tx already executed");
    _;
  }

  modifier notConfirmed(uint _txIndex) {
    require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
    _;
  }

  constructor(address[] memory _owners, uint _numberConfirmRequired) {
    require(_owners.length > 0, "owners required");
    require(_numberConfirmRequired > 0 && _numberConfirmRequired <= _owners.length, "invalid number of required confirmations");

    for (uint i = 0; i < _owners.length; i++) {
      address owner = _owners[i];
      require(owner == address(0), "invalid owner");
      require(!isOwner[owner], "owner not unique");

      isOwner[owner] = true;
      owners.push(owner);
    }

    numberConfirmRequired = _numberConfirmRequired;
  }

  receive() external payable {
    emit Deposit(msg.sender, msg.value, address(this).balance);
  }

  function sumbitTransaction(
    address _to,
    uint _value,
    bytes memory _data
  ) public onlyOwner {
    uint txIndex = transactions.length;

    transactions.push(Transaction({
      to: _to,
      value: _value,
      data: _data,
      executed: false,
      numberConfirmations: 0
    }));

    emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
  }

  function confirmTransaction(uint _txIndex) 
    public
    onlyOwner 
    notExecuted(_txIndex) 
    notConfirmed(_txIndex)
    txExist(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    transaction.numberConfirmations += 1;
    isConfirmed[_txIndex][msg.sender] = true;

    emit ConfirmTransaction(msg.sender, _txIndex);
  }

  function executeTransaction (uint _txIndex) 
    public 
    onlyOwner 
    notExecuted(_txIndex) 
    txExist(_txIndex) 
  {
    Transaction storage transaction = transactions[_txIndex];

    require(transaction.numberConfirmations >= numberConfirmRequired, "not enough number confirmation to execute");

    transaction.executed = true;

    (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
    require(success, "tx execute failed");

    emit ExecuteTransaction(msg.sender, _txIndex);
  }

  function revokeConfirmation(uint _txIndex) 
    public
    onlyOwner
    txExist(_txIndex)
    notExecuted(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

    transaction.numberConfirmations -= 1;
    isConfirmed[_txIndex][msg.sender] = false;

    emit RevokeTranscation(msg.sender, _txIndex);
  }

  function getOwners() public view returns(address[] memory) {
    return owners;
  }

  function getTransactionCount() public view returns(uint) {
    return transactions.length;
  }

  function getTransaction(uint _txIndex) 
    public 
    view 
    returns(
      address to,
      uint value,
      bytes memory data,
      bool executed,
      uint numConfirmations
    ) 
  {
      Transaction storage transaction = transactions[_txIndex];

      return (
          transaction.to,
          transaction.value,
          transaction.data,
          transaction.executed,
          transaction.numberConfirmations
      );
  }
}