// contracts/CoC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoC {
    //define data structure using struct
    struct custodyEvent {
        string evidenceId;
        string owner;
        address ownerAccount;
        string description;
        uint256 timestamp;
    }

    //store multiple events
    custodyEvent[] public events;

    event EventRecorded(string evidenceId, string owner, address handler, uint256 timestamp);

    function recordEvent(string memory _evidenceId, string memory _owner, string memory _description) public {
        custodyEvent memory newEvent = custodyEvent({
            evidenceId: _evidenceId,
            owner: _owner,
            ownerAccount: msg.sender,
            description: _description,
            timestamp: block.timestamp
        });

        events.push(newEvent);
        emit EventRecorded(_evidenceId, _owner, msg.sender, block.timestamp);
    }

    function getEvent(uint index) public view returns (custodyEvent memory) {
        require(index < events.length, "Invalid index");
        return events[index];
    }

    function totalEvents() public view returns (uint) {
        return events.length;
    }
}
