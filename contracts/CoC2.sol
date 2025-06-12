// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoC {
    struct CustodyEvent {
        string owner;
        address ownerAccount;
        string action;        // collected, transferred, analyzed, etc.
        string description;
        uint256 timestamp;
    }

    struct Evidence {
        string evidenceId;
        string description;
        string currentOwner;
        address currentOwnerAccount;
        bool exists;
        bool deleted;
    }

    // evidenceId => Evidence details
    mapping(string => Evidence) public evidences;

    // evidenceId => custody history
    mapping(string => CustodyEvent[]) private custodyHistory;

    event EvidenceRegistered(string evidenceId, string owner, address ownerAccount, string description, uint256 timestamp);
    event CustodyTransferred(string evidenceId, string from, address fromAccount, string to, address toAccount, uint256 timestamp);
    event EvidenceDeleted(string evidenceId, uint256 timestamp);

    modifier onlyOwner(string memory _evidenceId) {
        require(evidences[_evidenceId].currentOwnerAccount == msg.sender, "Not evidence owner");
        require(!evidences[_evidenceId].deleted, "Evidence deleted");
        require(evidences[_evidenceId].exists, "Evidence does not exist");
        _;
    }

    function registerEvidence(string memory _evidenceId, string memory _description) public {
        require(!evidences[_evidenceId].exists, "Already registered");
        evidences[_evidenceId] = Evidence({
            evidenceId: _evidenceId,
            description: _description,
            currentOwner: "Initial",
            currentOwnerAccount: msg.sender,
            exists: true,
            deleted: false
        });
        custodyHistory[_evidenceId].push(CustodyEvent({
            owner: "Initial",
            ownerAccount: msg.sender,
            action: "collected",
            description: _description,
            timestamp: block.timestamp
        }));
        emit EvidenceRegistered(_evidenceId, "Initial", msg.sender, _description, block.timestamp);
    }

    function transferCustody(string memory _evidenceId, string memory _newOwner, address _newOwnerAccount, string memory _action, string memory _description) public onlyOwner(_evidenceId) {
        Evidence storage ev = evidences[_evidenceId];
        custodyHistory[_evidenceId].push(CustodyEvent({
            owner: _newOwner,
            ownerAccount: _newOwnerAccount,
            action: _action,
            description: _description,
            timestamp: block.timestamp
        }));
        emit CustodyTransferred(_evidenceId, ev.currentOwner, ev.currentOwnerAccount, _newOwner, _newOwnerAccount, block.timestamp);
        ev.currentOwner = _newOwner;
        ev.currentOwnerAccount = _newOwnerAccount;
    }

    function deleteEvidence(string memory _evidenceId) public onlyOwner(_evidenceId) {
        evidences[_evidenceId].deleted = true;
        emit EvidenceDeleted(_evidenceId, block.timestamp);
    }

    function getEvidence(string memory _evidenceId) public view returns (Evidence memory) {
        require(evidences[_evidenceId].exists, "Not found");
        return evidences[_evidenceId];
    }

    function getCustodyHistory(string memory _evidenceId) public view returns (CustodyEvent[] memory) {
        require(evidences[_evidenceId].exists, "Not found");
        return custodyHistory[_evidenceId];
    }
}