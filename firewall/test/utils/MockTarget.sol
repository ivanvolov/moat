// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Minimal call recorder for firewall tests.
///         Captures every inbound call and can be toggled to revert.
///         If a token is configured, pulls its full approved allowance from
///         the caller on every invocation — simulating a real target that
///         claims the tokens the firewall approved for it.
contract MockTarget {
    struct Call {
        bytes   data;
        uint256 value;
    }

    Call[]         public calls;
    bool           public shouldRevert;
    string         public revertMessage;
    address        public token;

    function setShouldRevert(bool _revert, string calldata _message) external {
        shouldRevert = _revert;
        revertMessage = _message;
    }

    function setToken(address _token) external {
        token = _token;
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }

    function lastCall() external view returns (Call memory) {
        return calls[calls.length - 1];
    }

    fallback() external payable {
        if (shouldRevert) revert(revertMessage);
        _pullToken();
        calls.push(Call({data: msg.data, value: msg.value}));
    }

    receive() external payable {
        if (shouldRevert) revert(revertMessage);
        _pullToken();
        calls.push(Call({data: "", value: msg.value}));
    }

    function _pullToken() internal {
        if (token == address(0)) return;
        IERC20Minimal t = IERC20Minimal(token);
        uint256 approved = t.allowance(msg.sender, address(this));
        if (approved > 0) t.transferFrom(msg.sender, address(this), approved);
    }
}
