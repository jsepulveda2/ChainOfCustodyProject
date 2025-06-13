// contracts/EvidenceAcessControl.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Evidence Access Control Token (AC_Token) for Capability-Based Permissions
/// @notice This contract manages access permissions (capabilities) for evidence items.
///         It is designed to be used alongside a main Evidence contract.

contract EvidenceAccessControl {
    address public admin;

    // Maps evidence key to user address to access status
    mapping(bytes32 => mapping(address => bool)) public access;

    event AccessAssigned(bytes32 indexed evidenceKey, address indexed user, uint256 timestamp);
    event AccessRevoked(bytes32 indexed evidenceKey, address indexed user, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice Allow admin to be updated after deployment, for flexibility
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    /// @notice Assign capability/access to a user for a specific evidence
    function assignAC(bytes32 evidenceKey, address user) external onlyAdmin {
        access[evidenceKey][user] = true;
        emit AccessAssigned(evidenceKey, user, block.timestamp);
    }

    /// @notice Revoke capability/access from a user for a specific evidence
    function revokeAC(bytes32 evidenceKey, address user) external onlyAdmin {
        access[evidenceKey][user] = false;
        emit AccessRevoked(evidenceKey, user, block.timestamp);
    }

    /// @notice Query if a user has capability/access for a specific evidence
    function query_CapAC(bytes32 evidenceKey, address user) external view returns (bool) {
        return access[evidenceKey][user];
    }
}