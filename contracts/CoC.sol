// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EvidenceAccessControl.sol";

// Chain of Custody for Digital Evidence
// Uses external access control for permission verification
contract EvidenceChainOfCustody {
    address public admin; // Contract admin
    EvidenceAccessControl public acToken; // Access control reference

    // Custody event for evidence transfer history
    struct CustodyEvent {
        address holderAccount;
        string holderName;
        string action;     // "collected", "transferred", "analyzed", etc.
        string description;
        uint256 timestamp;
    }

    // Main structure to hold evidence data and transfer history
    struct Evidence {
        string evidenceId;
        address currentHolder;
        string currentHolderName;
        string description;
        string ipfsHash;
        bool isDeleted;
        CustodyEvent[] history; // Timeline of custody changes
    }

    // Storage for evidence using a hash of (caseId + evidenceId) as key
    mapping(bytes32 => Evidence) private evidences;
    bytes32[] private evidenceKeys; // To allow enumeration

    // Events for logging actions
    event EvidenceRegistered(bytes32 indexed evidenceKey, string evidenceId, address holder, string holderName, string ipfsHash, uint256 timestamp);
    event EvidenceTransferred(bytes32 indexed evidenceKey, address from, address to, string action, uint256 timestamp);
    event EvidenceDeleted(bytes32 indexed evidenceKey, uint256 timestamp);

    // Access modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier evidenceExists(bytes32 key) {
        require(bytes(evidences[key].evidenceId).length != 0, "Evidence does not exist");
        _;
    }

    modifier onlyHolderOrAdmin(bytes32 key) {
        require(msg.sender == evidences[key].currentHolder || msg.sender == admin, "Not holder or admin");
        _;
    }

    modifier notDeleted(bytes32 key) {
        require(!evidences[key].isDeleted, "Evidence is deleted");
        _;
    }

    modifier hasAccess(bytes32 key) {
        require(
            msg.sender == admin ||
            msg.sender == evidences[key].currentHolder ||
            acToken.query_CapAC(key, msg.sender),
            "No access"
        );
        _;
    }

    // Constructor sets the admin and the access control contract
    constructor(address _acTokenAddress) {
        admin = msg.sender;
        acToken = EvidenceAccessControl(_acTokenAddress);
    }

    // Helper to generate a unique key from caseId and evidenceId
    function computeKey(string memory caseId, string memory evidenceId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(caseId, evidenceId));
    }

    // Register new digital evidence
    function registerEvidence(
        string memory caseId,
        string memory evidenceId,
        string memory holderName,
        string memory description,
        string memory ipfsHash,
        string memory action
    ) public {
        bytes32 key = computeKey(caseId, evidenceId);
        require(bytes(evidences[key].evidenceId).length == 0, "Evidence already exists");

        Evidence storage e = evidences[key];
        e.evidenceId = evidenceId;
        e.currentHolder = msg.sender;
        e.currentHolderName = holderName;
        e.description = description;
        e.ipfsHash = ipfsHash;
        e.isDeleted = false;
        evidenceKeys.push(key);

        e.history.push(CustodyEvent({
            holderAccount: msg.sender,
            holderName: holderName,
            action: action,
            description: description,
            timestamp: block.timestamp
        }));

        emit EvidenceRegistered(key, evidenceId, msg.sender, holderName, ipfsHash, block.timestamp);

        // Give access rights to the registering user
        acToken.assignAC(key, msg.sender);
    }

    // Transfer evidence to another holder
    function transferEvidence(
        string memory caseId,
        string memory evidenceId,
        address to,
        string memory toName,
        string memory action,
        string memory description
    ) public {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];

        require(!e.isDeleted, "Evidence is deleted");
        require(msg.sender == e.currentHolder, "Not current holder");
        require(to != msg.sender, "Cannot transfer to self");

        address from = e.currentHolder;
        e.currentHolder = to;
        e.currentHolderName = toName;

        e.history.push(CustodyEvent({
            holderAccount: to,
            holderName: toName,
            action: action,
            description: description,
            timestamp: block.timestamp
        }));

        emit EvidenceTransferred(key, from, to, action, block.timestamp);

        // Assign access to the new holder
        acToken.assignAC(key, to);
    }

    // Soft-delete an evidence record
    function deleteEvidence(string memory caseId, string memory evidenceId) public {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(!e.isDeleted, "Already deleted");
        require(msg.sender == e.currentHolder || msg.sender == admin, "Not current holder or admin");

        e.isDeleted = true;

        e.history.push(CustodyEvent({
            holderAccount: msg.sender,
            holderName: e.currentHolderName,
            action: "deleted",
            description: "Evidence soft-deleted",
            timestamp: block.timestamp
        }));

        emit EvidenceDeleted(key, block.timestamp);
    }

    // --- VIEWS ---

    // View details of evidence if authorized
    function viewEvidence(string memory caseId, string memory evidenceId)
        public view
        returns (
            string memory, address, string memory, string memory, string memory, bool
        )
    {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(
            msg.sender == admin ||
            msg.sender == e.currentHolder ||
            acToken.query_CapAC(key, msg.sender),
            "Not authorized"
        );
        return (
            e.evidenceId,
            e.currentHolder,
            e.currentHolderName,
            e.description,
            e.ipfsHash,
            e.isDeleted
        );
    }

    // Get full custody history of an evidence
    function getHistory(string memory caseId, string memory evidenceId)
        public view
        returns (CustodyEvent[] memory)
    {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(
            msg.sender == admin ||
            msg.sender == e.currentHolder ||
            acToken.query_CapAC(key, msg.sender),
            "Not authorized"
        );

        CustodyEvent[] memory hist = new CustodyEvent[](e.history.length);
        for(uint i = 0; i < e.history.length; i++) {
            hist[i] = e.history[i];
        }
        return hist;
    }

    // Get number of evidence records
    function evidenceCount() public view returns (uint) {
        return evidenceKeys.length;
    }

    // // Get evidence ID and key at a given index
    // function getEvidenceIdAt(uint idx) public view returns (bytes32, string memory) {
    //     require(idx < evidenceKeys.length, "Out of range");
    //     Evidence storage e = evidences[evidenceKeys[idx]];
    //     return (evidenceKeys[idx], e.evidenceId);
    // }


function getAllEvidenceIds() public view returns (string[] memory) {
    string[] memory ids = new string[](evidenceKeys.length);
    for (uint i = 0; i < evidenceKeys.length; i++) {
        Evidence storage e = evidences[evidenceKeys[i]];
        ids[i] = e.evidenceId;
    }
    return ids;
}

}
