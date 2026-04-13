// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  MoatFirewall
/// @notice Queues transactions for watchtower review. The watchtower may approve
///         and execute any pending transaction. If it does not act within
///         `timelockDuration`, the original submitter may execute it themselves
///         via `pushThrough`.
///
///         ERC-20 flows: if a transaction requires a token transfer, the submitter
///         specifies `(token, tokenAmount)` at submission time and approves the
///         firewall for that amount. On execution the firewall pulls from the
///         submitter, approves the target for exactly that amount, calls it, then
///         resets the approval to zero — so no leftover allowance remains.
contract MoatFirewall {
    using SafeERC20 for IERC20;

    // ── Storage ─────────────────────────────────────────────────────────────

    address public admin;
    address public watchtower;
    uint256 public timelockDuration;

    enum Status {
        Pending,
        Executed
    }

    struct Transaction {
        address submitter;
        address target;
        uint256 value;
        bytes   data;
        uint256 submittedAt;
        Status  status;
        address token;
        uint256 tokenAmount;
    }

    mapping(bytes32 => Transaction) public txs;
    mapping(address => bool)        public whitelist;

    // ── Events ───────────────────────────────────────────────────────────────

    event Queued(
        bytes32 indexed id,
        address indexed submitter,
        address indexed target,
        uint256 value,
        address token,
        uint256 tokenAmount,
        bytes data
    );
    event Executed(bytes32 indexed id);
    event TargetSet(address indexed target, bool allowed);

    // ── Errors ───────────────────────────────────────────────────────────────

    error Unauthorized();
    error NotPending(bytes32 id);
    error TimelockActive(bytes32 id, uint256 unlocksAt);
    error CallFailed(bytes returnData);
    error TargetNotAllowed(address target);
    error ValueMismatch(uint256 sent, uint256 expected);
    error DuplicateTransaction(bytes32 id);

    // ── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyWatchtower() {
        if (msg.sender != watchtower) revert Unauthorized();
        _;
    }

    // ── Constructor ──────────────────────────────────────────────────────────

    constructor(address _admin, address _watchtower, uint256 _timelockDuration) {
        admin = _admin;
        watchtower = _watchtower;
        timelockDuration = _timelockDuration;
    }

    // ── Submission ───────────────────────────────────────────────────────────

    /// @notice Queue a transaction for watchtower review.
    /// @param token        ERC-20 token the target needs, or address(0) for none.
    /// @param tokenAmount  Amount of `token` to pull from the submitter on execution.
    /// @return id          Unique identifier for the queued transaction.
    function submit(address target, uint256 value, address token, uint256 tokenAmount, bytes calldata data)
        external
        payable
        returns (bytes32 id)
    {
        if (!whitelist[target]) revert TargetNotAllowed(target);
        if (msg.value != value) revert ValueMismatch(msg.value, value);

        id = keccak256(abi.encode(msg.sender, target, data, block.timestamp));
        if (txs[id].submitter != address(0)) revert DuplicateTransaction(id);

        txs[id] = Transaction({
            submitter:   msg.sender,
            target:      target,
            value:       value,
            data:        data,
            submittedAt: block.timestamp,
            status:      Status.Pending,
            token:       token,
            tokenAmount: tokenAmount
        });

        emit Queued(id, msg.sender, target, value, token, tokenAmount, data);
    }

    // ── Watchtower ───────────────────────────────────────────────────────────

    /// @notice Approve and immediately execute a pending transaction.
    function approve(bytes32 id) external onlyWatchtower {
        _requirePending(id);
        txs[id].status = Status.Executed;
        _execute(id);
        emit Executed(id);
    }

    // ── Timelock fallback ────────────────────────────────────────────────────

    /// @notice Execute a pending transaction after the timelock has elapsed.
    ///         Only callable by the original submitter.
    function pushThrough(bytes32 id) external {
        Transaction storage txn = txs[id];
        if (msg.sender != txn.submitter) revert Unauthorized();
        if (txn.status != Status.Pending) revert NotPending(id);

        uint256 unlocksAt = txn.submittedAt + timelockDuration;
        if (block.timestamp < unlocksAt) revert TimelockActive(id, unlocksAt);

        txn.status = Status.Executed;
        _execute(id);
        emit Executed(id);
    }

    // ── Views ────────────────────────────────────────────────────────────────

    function statusOf(bytes32 id) external view returns (Status) {
        return txs[id].status;
    }

    function submittedAt(bytes32 id) external view returns (uint256) {
        return txs[id].submittedAt;
    }

    // ── Admin ────────────────────────────────────────────────────────────────

    function allow(address target) external onlyAdmin {
        whitelist[target] = true;
        emit TargetSet(target, true);
    }

    function disallow(address target) external onlyAdmin {
        whitelist[target] = false;
        emit TargetSet(target, false);
    }

    function setWatchtower(address _watchtower) external onlyAdmin {
        watchtower = _watchtower;
    }

    function setTimelockDuration(uint256 _duration) external onlyAdmin {
        timelockDuration = _duration;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    function _requirePending(bytes32 id) internal view {
        if (txs[id].status != Status.Pending) revert NotPending(id);
    }

    function _execute(bytes32 id) internal {
        Transaction storage txn = txs[id];

        if (txn.token != address(0) && txn.tokenAmount > 0) {
            IERC20 token = IERC20(txn.token);
            token.safeTransferFrom(txn.submitter, address(this), txn.tokenAmount);
            token.safeIncreaseAllowance(txn.target, txn.tokenAmount);
            (bool ok, bytes memory ret) = txn.target.call{value: txn.value}(txn.data);
            token.safeDecreaseAllowance(txn.target, token.allowance(address(this), txn.target));
            if (!ok) revert CallFailed(ret);
        } else {
            (bool ok, bytes memory ret) = txn.target.call{value: txn.value}(txn.data);
            if (!ok) revert CallFailed(ret);
        }
    }
}
