// contracts/CoC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoC {
    // Each action taken with evidence (like transfer, collection, etc.) is recorded in this struct
    struct CustodyEvent {
        address ownerAccount;      // Ethereum address of the person doing the action
        string ownerName;          // Name of the person
        string action;             // What was done (e.g., collected, transferred, analyzed)
        string description;        // Optional details about the action
        uint256 timestamp;         // When the action happened
    }

    // Information about the actual piece of evidence
    struct Evidence {
        string evidenceId;         // Unique ID for the evidence
        string description;        // Description of what the evidence is
        address currentOwner;      // Ethereum address of the person currently holding the evidence
        string currentOwnerName;   // Name of the current holder
        string ipfsHash;           // IPFS hash pointing to the digital file or data
        bool isDeleted;            // Whether the evidence has been deleted (soft delete)
        mapping(address => bool) accessList; // Addresses allowed to view this evidence
        CustodyEvent[] history;    // Record of everything that's happened to this evidence
    }

    // Maps each evidence ID to its corresponding data
    mapping(string => Evidence) private evidences;

    // Stores list of all evidence IDs for tracking/counting
    string[] private evidenceIds;

    // Event logs for the blockchain to track
    event EvidenceRegistered(string evidenceId, string ownerName, address indexed ownerAccount, string ipfsHash, uint256 timestamp, string action);
    event EvidenceTransferred(string evidenceId, address indexed from, address indexed to, string action, uint256 timestamp);
    event EvidenceDeleted(string evidenceId, uint256 timestamp);
    event AccessGranted(string evidenceId, address indexed grantee);
    event AccessRevoked(string evidenceId, address indexed grantee);

    // Only allow the current evidence holder to do certain things
    modifier onlyOwner(string memory _evidenceId) {
        require(evidences[_evidenceId].currentOwner == msg.sender, "Not evidence owner");
        require(!evidences[_evidenceId].isDeleted, "Evidence is deleted");
        _;
    }

    // Makes sure the evidence actually exists before proceeding
    modifier evidenceExists(string memory _evidenceId) {
        require(bytes(evidences[_evidenceId].evidenceId).length != 0, "Evidence does not exist");
        _;
    }

    // Ensures the caller has permission to view the evidence
    modifier hasAccess(string memory _evidenceId) {
        require(
            evidences[_evidenceId].currentOwner == msg.sender ||
            evidences[_evidenceId].accessList[msg.sender],
            "No access to evidence"
        );
        _;
    }

    // Register a new piece of evidence in the system
    function registerEvidence(
        string memory _evidenceId,
        string memory _description,
        string memory _ownerName,
        string memory _ipfsHash,
        string memory _action
    ) public {
        require(bytes(evidences[_evidenceId].evidenceId).length == 0, "Evidence already exists");

        Evidence storage e = evidences[_evidenceId];
        e.evidenceId = _evidenceId;
        e.description = _description;
        e.currentOwner = msg.sender;
        e.currentOwnerName = _ownerName;
        e.ipfsHash = _ipfsHash;
        e.isDeleted = false;
        evidenceIds.push(_evidenceId);

        // Record the initial action (usually "collected" or "created")
        e.history.push(CustodyEvent({
            ownerAccount: msg.sender,
            ownerName: _ownerName,
            action: _action,
            description: _description,
            timestamp: block.timestamp
        }));

        emit EvidenceRegistered(_evidenceId, _ownerName, msg.sender, _ipfsHash, block.timestamp, _action);
    }

    // Transfer ownership of evidence to someone else
    function transferEvidence(
        string memory _evidenceId,
        address _to,
        string memory _toName,
        string memory _action,
        string memory _description
    )
        public
        evidenceExists(_evidenceId)
        onlyOwner(_evidenceId)
    {
        Evidence storage e = evidences[_evidenceId];
        address previousOwner = e.currentOwner;
        e.currentOwner = _to;
        e.currentOwnerName = _toName;

        // Add to history log
        e.history.push(CustodyEvent({
            ownerAccount: _to,
            ownerName: _toName,
            action: _action,
            description: _description,
            timestamp: block.timestamp
        }));

        emit EvidenceTransferred(_evidenceId, previousOwner, _to, _action, block.timestamp);
    }

    // Give someone else permission to view evidence details
    function grantAccess(string memory _evidenceId, address _grantee) public evidenceExists(_evidenceId) onlyOwner(_evidenceId) {
        evidences[_evidenceId].accessList[_grantee] = true;
        emit AccessGranted(_evidenceId, _grantee);
    }

    // Remove someone's viewing access
    function revokeAccess(string memory _evidenceId, address _grantee) public evidenceExists(_evidenceId) onlyOwner(_evidenceId) {
        evidences[_evidenceId].accessList[_grantee] = false;
        emit AccessRevoked(_evidenceId, _grantee);
    }

    // Mark evidence as deleted (it still exists but is considered inactive)
    function deleteEvidence(string memory _evidenceId) public evidenceExists(_evidenceId) onlyOwner(_evidenceId) {
        evidences[_evidenceId].isDeleted = true;
        emit EvidenceDeleted(_evidenceId, block.timestamp);
    }

    // View all details about a piece of evidence (only if you have access)
    function getEvidence(string memory _evidenceId) public view evidenceExists(_evidenceId) hasAccess(_evidenceId) returns (
        string memory, string memory, address, string memory, string memory, bool
    ) {
        Evidence storage e = evidences[_evidenceId];
        return (
            e.evidenceId,
            e.description,
            e.currentOwner,
            e.currentOwnerName,
            e.ipfsHash,
            e.isDeleted
        );
    }

    // View full history of actions taken on this piece of evidence
    function getHistory(string memory _evidenceId) public view evidenceExists(_evidenceId) hasAccess(_evidenceId) returns (
        CustodyEvent[] memory
    ) {
        Evidence storage e = evidences[_evidenceId];
        CustodyEvent[] memory hist = new CustodyEvent[](e.history.length);
        for (uint i = 0; i < e.history.length; i++) {
            hist[i] = e.history[i];
        }
        return hist;
    }

    // Return how many evidence items are in the system
    function evidenceCount() public view returns (uint) {
        return evidenceIds.length;
    }

    // Look up an evidence ID by its position in the list
    function getEvidenceIdAt(uint index) public view returns (string memory) {
        require(index < evidenceIds.length, "Out of range");
        return evidenceIds[index];
    }
}
