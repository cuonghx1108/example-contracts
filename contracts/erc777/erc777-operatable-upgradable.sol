// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC777/ERC777.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777SenderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC1820RegistryUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ArraysUpgradeable.sol";
import "./i-permitter.sol";
import "./i-fee-calculater.sol";
import "hardhat/console.sol";

/**
 * @dev Implementation of the {IERC777} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * Support for ERC20 is included in this contract, as specified by the EIP: both
 * the ERC777 and ERC20 interfaces can be safely used when interacting with it.
 * Both {IERC777-Sent} and {IERC20-Transfer} events are emitted on token
 * movements.
 *
 * Additionally, the {IERC777-granularity} value is hard-coded to `1`, meaning that there
 * are no special restrictions in the amount of tokens that created, moved, or
 * destroyed. This makes integration with ERC20 applications seamless.
 */
contract ERC777OpratableUpgradable is Initializable, ContextUpgradeable, IERC777Upgradeable, IERC20Upgradeable {
    using AddressUpgradeable for address;

    IERC1820RegistryUpgradeable internal constant _ERC1820_REGISTRY = IERC1820RegistryUpgradeable(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    mapping(address => uint256) private _balances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 private constant _GU_FEE_RECIEVER_INTERFACE_HASH = keccak256("GUFeeReciever");

    // This isn't ever read from - it's only used to respond to the defaultOperators query.
    address[] private _defaultOperatorsArray;

    // Immutable, but accounts may revoke them (tracked in __revokedDefaultOperators).
    mapping(address => bool) private _defaultOperators;

    // For each account, a mapping of its operators and revoked default operators.
    mapping(address => mapping(address => bool)) private _operators;
    mapping(address => mapping(address => bool)) private _revokedDefaultOperators;

    // Token Managers (Extended ERC777)
    mapping(address => bool) private _managers;    
    // it's only used to respond to managers() query.
    address[] private _managersArray;    

    // Permitter address (IPermitter implementer)
    address private _permitter; 

    // Fee recievers (IFeeCalculater implementer)
    address private _feeReciever;

    // ERC20-allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    function initialize(
        string memory name_,
        string memory symbol_,
        address[] memory defaultOperators_,
        uint256 initialSupply
    ) public initializer {
        __ERC777_init(name_, symbol_, defaultOperators_);
        _mint(defaultOperators_[0], initialSupply, "", "");
    }

    function mint(
      address account,
      uint256 amount,
      bytes memory userData,
      bytes memory operatorData
    ) public {
        require(_defaultOperators[_msgSender()], "GRC1: mint is allowed by only defaultOperator");
        _mint(account, amount, userData, operatorData, true);
    }

    // Permitter
    function registerPermitter(address permitter) public {
        require(permitter != address(0), "GRC10: can not set zero address");
        _permitter = permitter;
    }

    function _isAllowed(address target) private view returns(bool) {
      if ( _permitter != address(0)) {
          IPermitter permitter = IPermitter(_permitter);    
          return permitter.isAllowed(target);
      }
      return true;
    }

    // Fee reciever
    function registerFeeReciever(address recieverAddr) public virtual {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(recieverAddr, _GU_FEE_RECIEVER_INTERFACE_HASH);
        require(implementer != address(0), "ERC777: token recipient contract has no implementer for ERC777TokensRecipient");
        _feeReciever = recieverAddr;
    }

    function feeReciever() public view virtual returns (address) {
        return _feeReciever;
    }

    /**
     * @dev `defaultOperators` may be an empty array.
     */
    function __ERC777_init(
        string memory name_,
        string memory symbol_,
        address[] memory defaultOperators_
    ) internal onlyInitializing {
        __ERC777_init_unchained(name_, symbol_, defaultOperators_);
    }

    function __ERC777_init_unchained(
        string memory name_,
        string memory symbol_,
        address[] memory defaultOperators_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;

        _defaultOperatorsArray = defaultOperators_;
        for (uint256 i = 0; i < defaultOperators_.length; i++) {
            _defaultOperators[defaultOperators_[i]] = true;
        }

        // register interfaces
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
    }

    /**
     * @dev See {IERC777-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC777-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
    * @dev See {ERC20-decimals}.
    *
    * Always returns 18, as per the
    * [ERC777 EIP](https://eips.ethereum.org/EIPS/eip-777#backward-compatibility).
    */
    function decimals() public pure virtual returns (uint8) {
        return 18;
    }

    /**
    * @dev See {IERC777-granularity}.
    *
    * This implementation always returns `1`.
    */
    function granularity() public view virtual override returns (uint256) {
        return 1;
    }

    /**
    * @dev See {IERC777-totalSupply}.
    */
    function totalSupply() public view virtual override(IERC20Upgradeable, IERC777Upgradeable) returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
    */
    function balanceOf(address tokenHolder) public view virtual override(IERC20Upgradeable, IERC777Upgradeable) returns (uint256) {
        return _balances[tokenHolder];
    }

    /**
    * @dev See {IERC777-send}.
     *
     * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
     */
    function send(
        address recipient,
        uint256 amount,
        bytes memory data
    ) public virtual override {
      _send(_msgSender(), recipient, amount, data, "", true);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Unlike `send`, `recipient` is _not_ required to implement the {IERC777Recipient}
     * interface if it is a contract.
     *
     * Also emits a {Sent} event.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient != address(0), "ERC777: transfer to the zero address");

        address from = _msgSender();

        amount = _sendFee(from, from, amount, "", "", false, false);

        _callTokensToSend(from, from, recipient, amount, "", "");

        _move(from, from, recipient, amount, "", "");

        _callTokensReceived(from, from, recipient, amount, "", "", false);

        return true;
    }

    /**
     * @dev See {IERC777-burn}.
     *
     * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
     */
    function burn(uint256 amount, bytes memory data) public virtual override {
        require(
            _managers[_msgSender()] || _defaultOperators[_msgSender()],
            "GRC1: caller should be defaultOperator or Manager"
        );
        _burn(_msgSender(), amount, data, "");
    }

    /**
         * @dev See {IERC777-isOperatorFor}.
         */
    function isOperatorFor(address operator, address tokenHolder) public view virtual override returns (bool) {
        return
            operator == tokenHolder ||
            (_defaultOperators[operator] && !_revokedDefaultOperators[tokenHolder][operator]) ||
            _operators[tokenHolder][operator] ||
            _managers[operator];
    }

    /**
      * @dev See {IERC777-authorizeOperator}.
      */
    function authorizeOperator(address operator) public virtual override {
        require(_msgSender() != operator, "ERC777: authorizing self as operator");

        if (_defaultOperators[operator]) {
            delete _revokedDefaultOperators[_msgSender()][operator];
        } else {
            _operators[_msgSender()][operator] = true;
        }

        emit AuthorizedOperator(operator, _msgSender());
    }

    /**
      * @dev See {IERC777-revokeOperator}.
      */
    function revokeOperator(address operator) public virtual override {
        require(operator != _msgSender(), "ERC777: revoking self as operator");

        if (_defaultOperators[operator]) {
            _revokedDefaultOperators[_msgSender()][operator] = true;
        } else {
            delete _operators[_msgSender()][operator];
        }

        emit RevokedOperator(operator, _msgSender());
    }

    /**
     * @dev See {IERC777-defaultOperators}.
     */
    function defaultOperators() public view virtual override returns (address[] memory) {
        return _defaultOperatorsArray;
    }

   /**
   * @dev See {GRC10-authorizeManager}
   */
    function authorizeManager(address manager) public {
        require(
            _managers[_msgSender()] || _defaultOperators[_msgSender()],
            "GRC1: caller should be defaultOperator or Manager"
        );
        require(_msgSender() != manager, "GRC1: authorizing self as operator");
        require(!_managers[manager], "GRC1: operator is already registered");

        _managers[manager] = true;
        _managersArray.push(manager);

        emit AuthorizedOperator(manager, _msgSender());
    }

    /**
    * @dev See {GRC1-revokeManager}.
    */
    function revokeManager(address manager) public {
        require(
        _managers[_msgSender()] || _defaultOperators[_msgSender()],
        "GRC1: caller should be defaultOperator or Manager"
        );
        require(manager != _msgSender(), "GRC1: revoking self as operator");
        require(_managers[manager], "GRC1: specified manager is not Manager");

        delete _managers[manager];
        _sliceAddressFromArray(manager);

        emit RevokedOperator(manager, _msgSender());
    }

    function _sliceAddressFromArray(address target) internal {
        for (uint256 i = 0; i < _managersArray.length; i++) {
            if ( _managersArray[i] == target) {
                for (uint256 j = i; j < _managersArray.length - 1; j++) {
                    _managersArray[j] = _managersArray[j + 1];
                }
                _managersArray.pop();
            }
        }
    }

    /**
     * @dev See {GRC10-authorisedManagerHistory}.
     */
    function managers() public view returns (address[] memory) {
        return _managersArray;
    }

  /**
     * @dev See {IERC777-operatorSend}.
     *
     * Emits {Sent} and {IERC20-Transfer} events.
     */
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public virtual override {
        require(isOperatorFor(_msgSender(), sender), "GRC1: caller is not an operator or a manager for holder");
        _send(sender, recipient, amount, data, operatorData, true);
    }

    /**
      * @dev See {IERC777-operatorBurn}.
      *
      * Emits {Burned} and {IERC20-Transfer} events.
      */
    function operatorBurn(
        address account,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public virtual override {
        require(isOperatorFor(_msgSender(), account), "GRC1: caller is not an operator or a manager for holder");
        _burn(account, amount, data, operatorData);
    }

    /**
     * @dev See {IERC20-allowance}.
     *
     * Note that operator and allowance concepts are orthogonal: operators may
     * not have allowance, and accounts with allowance may not be operators
     * themselves.
     */
    function allowance(address holder, address spender) public view virtual override returns (uint256) {
        return _allowances[holder][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Note that accounts cannot have allowance issued by their operators.
     */
    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address holder = _msgSender();
        _approve(holder, spender, value);
        return true;
    }

  /**
     * @dev See {IERC20-transferFrom}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Note that operator and allowance concepts are orthogonal: operators cannot
     * call `transferFrom` (unless they have allowance), and accounts with
     * allowance cannot call `operatorSend` (unless they are operators).
     *
     * Emits {Sent}, {IERC20-Transfer} and {IERC20-Approval} events.
     */
  function transferFrom(
      address holder,
      address recipient,
      uint256 amount
  ) public virtual override returns (bool) {
      require(recipient != address(0), "ERC777: transfer to the zero address");
      require(holder != address(0), "ERC777: transfer from the zero address");

      address spender = _msgSender();

      amount = _sendFee(spender, holder, amount, "", "", false, true);

      _callTokensToSend(spender, holder, recipient, amount, "", "");

      _spendAllowance(holder, spender, amount);

      _move(spender, holder, recipient, amount, "", "");

      _callTokensReceived(spender, holder, recipient, amount, "", "", false);

      return true;
  }

  /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with `operator`, `data` and `operatorData`.
     *
     * See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits {Minted} and {IERC20-Transfer} events.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - if `account` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
  function _mint(
      address account,
      uint256 amount,
      bytes memory userData,
      bytes memory operatorData
  ) internal virtual {
      _mint(account, amount, userData, operatorData, true);
  }

  /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
    * the total supply.
    *
    * If `requireReceptionAck` is set to true, and if a send hook is
    * registered for `account`, the corresponding function will be called with
    * `operator`, `data` and `operatorData`.
    *
    * See {IERC777Sender} and {IERC777Recipient}.
    *
    * Emits {Minted} and {IERC20-Transfer} events.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - if `account` is a contract, it must implement the {IERC777Recipient}
    * interface.
    */
  function _mint(
      address account,
      uint256 amount,
      bytes memory userData,
      bytes memory operatorData,
      bool requireReceptionAck
  ) internal virtual {
      require(account != address(0), "ERC777: mint to the zero address");

      address operator = _msgSender();

      _beforeTokenTransfer(operator, address(0), account, amount);

      // Update state variables
      _totalSupply += amount;
      _balances[account] += amount;

      _callTokensReceived(operator, address(0), account, amount, userData, operatorData, requireReceptionAck);

      emit Minted(operator, account, amount, userData, operatorData);
      emit Transfer(address(0), account, amount);
  }

  /**
    * @dev Send tokens
    * @param from address token holder address
    * @param to address recipient address
    * @param amount uint256 amount of tokens to transfer
    * @param userData bytes extra information provided by the token holder (if any)
    * @param operatorData bytes extra information provided by the operator (if any)
    * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
    */
    function _send(
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(from != address(0), "ERC777: send from the zero address");
        require(to != address(0), "ERC777: send to the zero address");

        address operator = _msgSender();

        amount = _sendFee(operator, from, amount, userData, operatorData, requireReceptionAck, false);

        _callTokensToSend(operator, from, to, amount, userData, operatorData);

        _move(operator, from, to, amount, userData, operatorData);

        _callTokensReceived(operator, from, to, amount, userData, operatorData, requireReceptionAck);
    }

    function calculateFee(uint256 amount) public view returns(uint256) {
        address from = _msgSender();
        if ( _feeReciever != address(0) ) {
            IFeeCalculater reciever = IFeeCalculater(_feeReciever);
            if (from != address(_feeReciever)) {
                return reciever.calculateFee(amount);
            }
        }
        return 0;
    }

    function _sendFee(
        address operator,
        address from,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck,
        bool spendAllowance
    ) public returns(uint256) {
        if ( _feeReciever != address(0) ) {
            uint256 fee = calculateFee(amount);
            if (fee != 0) {
                amount = amount - fee;

                if (spendAllowance) {
                    _spendAllowance(from, operator, fee);
                }

                _callTokensToSend(operator, from, _feeReciever, fee, userData, operatorData);
                _move(operator, from, _feeReciever, fee, userData, operatorData);
                _callTokensReceived(operator, from, _feeReciever, fee, userData, operatorData, requireReceptionAck);
            }
        }

        return amount;
    }

  /**
    * @dev Burn tokens
    * @param from address token holder address
    * @param amount uint256 amount of tokens to burn
    * @param data bytes extra information provided by the token holder
    * @param operatorData bytes extra information provided by the operator (if any)
    */
  function _burn(
      address from,
      uint256 amount,
      bytes memory data,
      bytes memory operatorData
  ) internal virtual {
      require(from != address(0), "ERC777: burn from the zero address");

      address operator = _msgSender();

      _callTokensToSend(operator, from, address(0), amount, data, operatorData);

      _beforeTokenTransfer(operator, from, address(0), amount);

      // Update state variables
      uint256 fromBalance = _balances[from];
      require(fromBalance >= amount, "ERC777: burn amount exceeds balance");
      unchecked {
          _balances[from] = fromBalance - amount;
      }
      _totalSupply -= amount;

      emit Burned(operator, from, amount, data, operatorData);
      emit Transfer(from, address(0), amount);
  }

    function _move(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        _beforeTokenTransfer(operator, from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Sent(operator, from, to, amount, userData, operatorData);
        emit Transfer(from, to, amount);
    }

  /**
    * @dev See {ERC20-_approve}.
    *
    * Note that accounts cannot have allowance issued by their operators.
    */
    function _approve(
        address holder,
        address spender,
        uint256 value
    ) internal virtual {
        require(holder != address(0), "ERC777: approve from the zero address");
        require(spender != address(0), "ERC777: approve to the zero address");

        _allowances[holder][spender] = value;
        emit Approval(holder, spender, value);
    }

    /**
    * @dev Call from.tokensToSend() if the interface is registered
    * @param operator address operator requesting the transfer
    * @param from address token holder address
    * @param to address recipient address
    * @param amount uint256 amount of tokens to transfer
    * @param userData bytes extra information provided by the token holder (if any)
    * @param operatorData bytes extra information provided by the operator (if any)
    */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        require(_isAllowed(from), "GRC10: from address is not allowed.");    // GU
        require(_isAllowed(to), "GRC10: to address is not allowed.");    // GU

        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(from, _TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777SenderUpgradeable(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }

    /**
    * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
    * tokensReceived() was not registered for the recipient
    * @param operator address operator requesting the transfer
    * @param from address token holder address
    * @param to address recipient address
    * @param amount uint256 amount of tokens to transfer
    * @param userData bytes extra information provided by the token holder (if any)
    * @param operatorData bytes extra information provided by the operator (if any)
    * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
    */
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(to, _TOKENS_RECIPIENT_INTERFACE_HASH);
        console.log("implementer %s", implementer);
        if (implementer != address(0)) {
            IERC777RecipientUpgradeable(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
        } else if (requireReceptionAck) {
            require(!to.isContract(), "ERC777: token recipient contract has no implementer for ERC777TokensRecipient");
        }
    }

    /**
    * @dev Spend `amount` form the allowance of `owner` toward `spender`.
    *
    * Does not update the allowance amount in case of infinite allowance.
    * Revert if not enough allowance is available.
    *
    * Might emit an {Approval} event.
    */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC777: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
  }

    /**
    * @dev Hook that is called before any token transfer. This includes
    * calls to {send}, {transfer}, {operatorSend}, minting and burning.
    *
    * Calling conditions:
    *
    * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
    * will be to transferred to `to`.
    * - when `from` is zero, `amount` tokens will be minted for `to`.
    * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
    * - `from` and `to` are never both zero.
    *
    * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
    */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(_isAllowed(operator), "ERC777: from address is not allowed.");    // GU
        require(_isAllowed(from), "ERC777: from address is not allowed.");    // GU
        require(_isAllowed(to), "ERC777: to address is not allowed.");    // GU
    }

    /**
    * @dev This empty reserved space is put in place to allow future versions to add new
    * variables without shifting down storage in the inheritance chain.
    * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    */
    uint256[41] private __gap;
}
