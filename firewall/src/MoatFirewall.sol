// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MoatFirewall
/// @notice Submit a transaction → watchtower approves and executes it, or after
///         the timelock anyone can push it through regardless.
contract MoatFirewall {
    address public admin;
    address public watchtower;
    uint256 public timelockDuration;

    enum Status { Pending, Executed, Rejected }

    struct Tx {
        address submitter;
        address target;
        uint256 value;
        bytes   data;
        uint256 submittedAt;
        Status  status;
    }

    mapping(bytes32 => Tx) public txs;
    mapping(address => uint256) public nonces;
    mapping(address => bool) public whitelist;
    address public currentUser; // set during execution so target contracts can read the submitter

    event Queued(bytes32 indexed id, address indexed submitter, address target, uint256 value, bytes data);
    event Executed(bytes32 indexed id);
    event Rejected(bytes32 indexed id, string reason);
    event TargetSet(address indexed target, bool allowed);

    error Unauthorized();
    error NotPending(bytes32 id);
    error TimelockActive(bytes32 id, uint256 unlocksAt);
    error CallFailed(bytes returnData);
    error TargetNotAllowed(address target);

    modifier onlyAdmin() { if (msg.sender != admin) revert Unauthorized(); _; }
    modifier onlyWatchtower() { if (msg.sender != watchtower) revert Unauthorized(); _; }

    constructor(address _admin, address _watchtower, uint256 _timelockDuration) {
        admin = _admin;
        watchtower = _watchtower;
        timelockDuration = _timelockDuration;
    }

    // ── Submit ──────────────────────────────────────────────────────────────

    function submit(address target, uint256 value, bytes calldata data)
        external payable returns (bytes32 id)
    {
        if (!whitelist[target]) revert TargetNotAllowed(target);
        require(msg.value == value, "value mismatch");
        id = keccak256(abi.encode(msg.sender, target, data, block.timestamp, nonces[msg.sender]++));
        txs[id] = Tx(msg.sender, target, value, data, block.timestamp, Status.Pending);
        emit Queued(id, msg.sender, target, value, data);
    }

    // ── Watchtower ──────────────────────────────────────────────────────────

    function approve(bytes32 id) external onlyWatchtower {
        _requirePending(id);
        txs[id].status = Status.Executed;
        _call(id);
        emit Executed(id);
    }

    function reject(bytes32 id, string calldata reason) external onlyWatchtower {
        _requirePending(id);
        txs[id].status = Status.Rejected;
        emit Rejected(id, reason);
    }

    // ── Timelock fallback ───────────────────────────────────────────────────

    function pushThrough(bytes32 id) external {
        Tx storage t = txs[id];
        if (t.status != Status.Pending && t.status != Status.Rejected)
            revert NotPending(id);
        uint256 unlocksAt = t.submittedAt + timelockDuration;
        if (block.timestamp < unlocksAt)
            revert TimelockActive(id, unlocksAt);
        t.status = Status.Executed;
        _call(id);
        emit Executed(id);
    }

    // ── Admin ───────────────────────────────────────────────────────────────

    function statusOf(bytes32 id) external view returns (Status) { return txs[id].status; }
    function submittedAt(bytes32 id) external view returns (uint256) { return txs[id].submittedAt; }

    function allow(address target) external onlyAdmin { whitelist[target] = true;  emit TargetSet(target, true); }
    function disallow(address target) external onlyAdmin { whitelist[target] = false; emit TargetSet(target, false); }

    function setWatchtower(address _watchtower) external onlyAdmin { watchtower = _watchtower; }
    function setTimelockDuration(uint256 _duration) external onlyAdmin { timelockDuration = _duration; }
    function setAdmin(address _admin) external onlyAdmin { admin = _admin; }

    // ── Internal ────────────────────────────────────────────────────────────

    function _requirePending(bytes32 id) internal view {
        if (txs[id].status != Status.Pending) revert NotPending(id);
    }

    function _call(bytes32 id) internal {
        Tx storage t = txs[id];
        currentUser = t.submitter;
        (bool ok, bytes memory ret) = t.target.call{value: t.value}(t.data);
        currentUser = address(0);
        if (!ok) revert CallFailed(ret);
    }
}
