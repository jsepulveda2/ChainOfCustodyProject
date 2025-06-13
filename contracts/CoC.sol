// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract CoC {
    // --- ADMINISTRATION ---
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // --- DATA STRUCTURES ---

    /// @notice Records every action taken on evidence
    struct CustodyEvent {
        address holderAddress;
        string holderName;
        string action;       // "collected", "transferred", "analyzed", "deleted", "grant", "revoke"
        string description;  // Details about the action, can include rationale or context
        uint256 timestamp;
    }

    /// @notice Digital evidence and its chain of custody
    struct Evidence {
        string caseId;             // Investigation/case namespace
        string evidenceId;         // Unique within caseId
        address currentHolder;     // Current holder's address
        string currentHolderName;  // Current holder's name
        string description;        // Description/details, may reference raw evidence, e.g., IPFS CID
        string ipfsHash;           // IPFS hash (immutable reference to raw data)
        bool isDeleted;            // Soft delete flag
        CustodyEvent[] history;    // Full chain of custody & access events
        mapping(address => bool) accessList; // Who can view this evidence
        address[] accessAddresses;           // Track all addresses ever granted access
    }

    // --- STORAGE ---

    mapping(bytes32 => Evidence) private evidences; // key = hash(caseId, evidenceId)
    bytes32[] private evidenceKeys;

    // --- EVENTS ---

    event EvidenceRegistered(string caseId, string evidenceId, address holder, string holderName, string ipfsHash, uint256 timestamp);
    event EvidenceTransferred(string caseId, string evidenceId, address from, address to, string action, uint256 timestamp);
    event EvidenceDeleted(string caseId, string evidenceId, uint256 timestamp);
    event AccessGranted(string caseId, string evidenceId, address grantee, uint256 timestamp);
    event AccessRevoked(string caseId, string evidenceId, address grantee, uint256 timestamp);

    // --- UTILITIES ---

    // Compute evidence key from caseId and evidenceId
    function computeKey(string memory caseId, string memory evidenceId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(caseId, evidenceId));
    }

    // --- MODIFIERS ---

    modifier evidenceExists(bytes32 key) {
        require(bytes(evidences[key].evidenceId).length != 0, "Evidence does not exist");
        _;
    }

    modifier onlyHolderOrAdmin(bytes32 key) {
        require(msg.sender == admin || evidences[key].currentHolder == msg.sender, "Not holder or admin");
        _;
    }

    modifier canAudit(bytes32 key) {
        require(
            msg.sender == admin ||
            evidences[key].currentHolder == msg.sender ||
            evidences[key].accessList[msg.sender],
            "No audit access"
        );
        _;
    }

    // --- CORE FUNCTIONS ---

    /// @notice Register new evidence (initial custody)
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
        e.caseId = caseId;
        e.evidenceId = evidenceId;
        e.currentHolder = msg.sender;
        e.currentHolderName = holderName;
        e.description = description;
        e.ipfsHash = ipfsHash;
        e.isDeleted = false;
        evidenceKeys.push(key);

        e.history.push(CustodyEvent({
            holderAddress: msg.sender,
            holderName: holderName,
            action: action,
            description: description,
            timestamp: block.timestamp
        }));

        emit EvidenceRegistered(caseId, evidenceId, msg.sender, holderName, ipfsHash, block.timestamp);
    }

    /// @notice Transfer custody to a new holder
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
        require(e.currentHolder == msg.sender, "Not current holder");
        require(to != msg.sender, "Cannot transfer to self");
        address from = e.currentHolder;
        e.currentHolder = to;
        e.currentHolderName = toName;
        e.history.push(CustodyEvent({
            holderAddress: to,
            holderName: toName,
            action: action,
            description: description,
            timestamp: block.timestamp
        }));
        emit EvidenceTransferred(caseId, evidenceId, from, to, action, block.timestamp);
    }

    /// @notice Soft-delete evidence (cannot be undone)
    function deleteEvidence(
        string memory caseId,
        string memory evidenceId
    ) public {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(!e.isDeleted, "Already deleted");
        require(e.currentHolder == msg.sender || msg.sender == admin, "Not current holder or admin");
        e.isDeleted = true;
        e.history.push(CustodyEvent({
            holderAddress: msg.sender,
            holderName: e.currentHolderName,
            action: "deleted",
            description: "Evidence soft-deleted",
            timestamp: block.timestamp
        }));
        emit EvidenceDeleted(caseId, evidenceId, block.timestamp);
    }

    // --- ACCESS CONTROL & AUDIT ---

    /// @notice Grant access to another address
    function grantAccess(
        string memory caseId,
        string memory evidenceId,
        address grantee
    ) public {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(!e.isDeleted, "Evidence is deleted");
        require(e.currentHolder == msg.sender || msg.sender == admin, "Not current holder or admin");
        if (!e.accessList[grantee]) {
            e.accessList[grantee] = true;
            e.accessAddresses.push(grantee);
        }
        e.history.push(CustodyEvent({
            holderAddress: grantee,
            holderName: "",
            action: "grant",
            description: "Access granted",
            timestamp: block.timestamp
        }));
        emit AccessGranted(caseId, evidenceId, grantee, block.timestamp);
    }

    /// @notice Revoke access from an address
    function revokeAccess(
        string memory caseId,
        string memory evidenceId,
        address grantee
    ) public {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(!e.isDeleted, "Evidence is deleted");
        require(e.currentHolder == msg.sender || msg.sender == admin, "Not current holder or admin");
        if (e.accessList[grantee]) {
            e.accessList[grantee] = false;
        }
        e.history.push(CustodyEvent({
            holderAddress: grantee,
            holderName: "",
            action: "revoke",
            description: "Access revoked",
            timestamp: block.timestamp
        }));
        emit AccessRevoked(caseId, evidenceId, grantee, block.timestamp);
    }

    /// @notice Return all addresses ever granted access, and their current status (true/false)
    function getAccessList(
        string memory caseId,
        string memory evidenceId
    ) public view returns (address[] memory, bool[] memory) {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        uint len = e.accessAddresses.length;
        address[] memory addrs = new address[](len);
        bool[] memory statuses = new bool[](len);
        for (uint i = 0; i < len; i++) {
            addrs[i] = e.accessAddresses[i];
            statuses[i] = e.accessList[addrs[i]];
        }
        return (addrs, statuses);
    }

    // --- VIEWS & ENUMERATION ---

    /// @notice Get current evidence data (ID, case, holder, name, description, IPFS, isDeleted)
    function viewEvidence(
        string memory caseId,
        string memory evidenceId
    )
        public view
        returns (
            string memory, string memory, address, string memory, string memory, string memory, bool
        )
    {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(
            msg.sender == admin ||
            e.currentHolder == msg.sender ||
            e.accessList[msg.sender],
            "Not authorized"
        );
        return (
            e.evidenceId,
            e.caseId,
            e.currentHolder,
            e.currentHolderName,
            e.description,
            e.ipfsHash,
            e.isDeleted
        );
    }

    /// @notice Get full history of custody/events (audit trail)
    function getHistory(
        string memory caseId,
        string memory evidenceId
    )
        public view
        returns (CustodyEvent[] memory)
    {
        bytes32 key = computeKey(caseId, evidenceId);
        Evidence storage e = evidences[key];
        require(
            msg.sender == admin ||
            e.currentHolder == msg.sender ||
            e.accessList[msg.sender],
            "Not authorized"
        );
        CustodyEvent[] memory hist = new CustodyEvent[](e.history.length);
        for(uint i = 0; i < e.history.length; i++) {
            hist[i] = e.history[i];
        }
        return hist;
    }

    /// @notice Number of evidence items registered
    function evidenceCount() public view returns (uint) {
        return evidenceKeys.length;
    }

    /// @notice Get evidence ID and case ID for an index (for enumeration)
    function getEvidenceIdAt(uint idx) public view returns (string memory, string memory) {
        require(idx < evidenceKeys.length, "Out of range");
        Evidence storage e = evidences[evidenceKeys[idx]];
        return (e.caseId, e.evidenceId);
    }
}