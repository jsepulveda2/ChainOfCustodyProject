const CoC = artifacts.require("CoC");

contract("CoC", accounts => {
  const [alice, bob, carol] = accounts;

  it("should register evidence", async () => {
    const coc = await CoC.deployed();
    await coc.registerEvidence(
      "EV1", "Laptop with case data", "Alice", "QmDummyHash", "collected", {from: alice}
    );
    const evidence = await coc.getEvidence("EV1", {from: alice});
    assert.equal(evidence[0], "EV1"); // evidenceId
    assert.equal(evidence[1], "Laptop with case data"); // description
    assert.equal(evidence[2], alice); // currentOwner
    assert.equal(evidence[3], "Alice"); // currentOwnerName
    assert.equal(evidence[4], "QmDummyHash"); // ipfsHash
    assert.equal(evidence[5], false); // isDeleted
  });

  it("should allow transfer of evidence", async () => {
    const coc = await CoC.deployed();
    await coc.transferEvidence(
      "EV1", bob, "Bob", "transferred", "Handed to Bob for analysis", {from: alice}
    );

    const evidence = await coc.getEvidence("EV1", {from: bob});
    assert.equal(evidence[2], bob); // new currentOwner
    assert.equal(evidence[3], "Bob"); // new currentOwnerName
  });

  it("should grant and revoke access", async () => {
    const coc = await CoC.deployed();
    // Bob grants Carol access
    await coc.grantAccess("EV1", carol, {from: bob});
    let evidence = await coc.getEvidence("EV1", {from: carol});
    assert.equal(evidence[0], "EV1"); // carol can now view

    // Bob revokes Carol's access
    await coc.revokeAccess("EV1", carol, {from: bob});
    // Carol should now be denied access
    try {
      await coc.getEvidence("EV1", {from: carol});
      assert.fail("Carol should not have access after revoke");
    } catch (err) {
      assert(err.message.includes("No access"), "Expected No access revert");
    }
  });

  it("should allow soft deletion", async () => {
    const coc = await CoC.deployed();
    // Bob deletes the evidence
    await coc.deleteEvidence("EV1", {from: bob});
    const evidence = await coc.getEvidence("EV1", {from: bob});
    assert.equal(evidence[5], true); // isDeleted
  });

  it("should record and return full history", async () => {
    const coc = await CoC.deployed();
    // Register new evidence for fresh history
    await coc.registerEvidence(
      "EV2", "USB drive", "Bob", "QmAnotherHash", "collected", {from: bob}
    );
    await coc.transferEvidence(
      "EV2", alice, "Alice", "transferred", "Returned to Alice", {from: bob}
    );
    const history = await coc.getHistory("EV2", {from: alice});
    assert.equal(history.length, 2);
    assert.equal(history[0].ownerName, "Bob");
    assert.equal(history[0].action, "collected");
    assert.equal(history[1].ownerName, "Alice");
    assert.equal(history[1].action, "transferred");
  });

  it("should show correct evidence count and lookup by index", async () => {
    const coc = await CoC.deployed();
    const count = await coc.evidenceCount();
    assert.equal(count.toNumber(), 2);
    const evid0 = await coc.getEvidenceIdAt(0);
    assert.equal(evid0, "EV1");
    const evid1 = await coc.getEvidenceIdAt(1);
    assert.equal(evid1, "EV2");
  });
});