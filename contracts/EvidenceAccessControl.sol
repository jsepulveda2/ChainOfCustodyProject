// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// This contract manages access permissions (capabilities) for evidence items.


contract EvidenceAccessControl {
    address public admin;

    // Map evidence key to user address to access status
    mapping(bytes32 => mapping(address => bool)) public access;

    event AccessAssigned(bytes32 indexed evidenceKey, address indexed user, uint256 timestamp);
    event AccessRevoked(bytes32 indexed evidenceKey, address indexed user, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Assign capability/access to a user for a specific evidence
    function assignAC(bytes32 evidenceKey, address user) external onlyAdmin {
        access[evidenceKey][user] = true;
        emit AccessAssigned(evidenceKey, user, block.timestamp);
    }

    ///  Revoke capability/access from a user for a specific evidence
    function revokeAC(bytes32 evidenceKey, address user) external onlyAdmin {
        access[evidenceKey][user] = false;
        emit AccessRevoked(evidenceKey, user, block.timestamp);
    }

    // Query if a user has capability/access for a specific evidence
    function query_CapAC(bytes32 evidenceKey, address user) external view returns (bool) {
        return access[evidenceKey][user];
    }
}