const EvidenceAccessControl = artifacts.require("EvidenceAccessControl");
const EvidenceChainOfCustody = artifacts.require("EvidenceChainOfCustody");

contract("EvidenceChainOfCustody with EvidenceAccessControl", accounts => {
  const [admin, alice, bob, carol] = accounts;
  let acToken, coc;
  const caseId = "CASE123";
  const evidenceId = "EV1";
  const ipfsHash = "QmTestHash";
  const description = "Forensic laptop";
  const key = web3.utils.soliditySha3(caseId, evidenceId);

  before(async () => {
    acToken = await EvidenceAccessControl.new({from: admin});
    coc = await EvidenceChainOfCustody.new(acToken.address, {from: admin});
  });

  it("should register evidence and allow admin to assign AC to creator", async () => {
    await coc.registerEvidence(
      caseId, evidenceId, "Alice", description, ipfsHash, "collected", {from: alice}
    );
    // At this point, Alice has registered, but does NOT have AC yet
    let hasAccess = await acToken.query_CapAC(key, alice);
    assert.equal(hasAccess, false);

    // Admin assigns AC to Alice
    await acToken.assignAC(key, alice, {from: admin});
    hasAccess = await acToken.query_CapAC(key, alice);
    assert.equal(hasAccess, true);

    // Now Alice can view
    const ev = await coc.viewEvidence(caseId, evidenceId, {from: alice});
    assert.equal(ev[0], evidenceId);
    assert.equal(ev[1], alice);
    assert.equal(ev[2], "Alice");
    assert.equal(ev[3], description);
    assert.equal(ev[4], ipfsHash);
    assert.equal(ev[5], false);
  });

  it("should transfer custody and grant AC to new holder", async () => {
    // Admin assigns AC to Bob first (as only admin can assign)
    await acToken.assignAC(key, bob, {from: admin});
    await coc.transferEvidence(
      caseId, evidenceId, bob, "Bob", "transferred", "For analysis", {from: alice}
    );
    const ev = await coc.viewEvidence(caseId, evidenceId, {from: bob});
    assert.equal(ev[1], bob);
    assert.equal(ev[2], "Bob");
    // Bob now has access
    const hasAccess = await acToken.query_CapAC(key, bob);
    assert.equal(hasAccess, true);
  });

  it("should allow admin to assign and revoke access (AC token)", async () => {
    // Carol does NOT have access yet
    let carolAccess = await acToken.query_CapAC(key, carol);
    assert.equal(carolAccess, false);

    // Admin assigns AC to Carol
    await acToken.assignAC(key, carol, {from: admin});
    carolAccess = await acToken.query_CapAC(key, carol);
    assert.equal(carolAccess, true);

    // Carol can now view evidence
    const ev = await coc.viewEvidence(caseId, evidenceId, {from: carol});
    assert.equal(ev[0], evidenceId);

    // Admin revokes Carol's access
    await acToken.revokeAC(key, carol, {from: admin});
    carolAccess = await acToken.query_CapAC(key, carol);
    assert.equal(carolAccess, false);

    // Carol cannot view evidence anymore
    try {
      await coc.viewEvidence(caseId, evidenceId, {from: carol});
      assert.fail("Carol should not have access after revoke");
    } catch (e) {
      assert(e.message.includes("Not authorized"));
    }
  });

  it("should soft delete evidence and allow only admin and holder to view", async () => {
    // Bob (holder) deletes
    await coc.deleteEvidence(caseId, evidenceId, {from: bob});
    const ev = await coc.viewEvidence(caseId, evidenceId, {from: bob});
    assert.equal(ev[5], true); // isDeleted

    // Admin can still view
    const evAdmin = await coc.viewEvidence(caseId, evidenceId, {from: admin});
    assert.equal(evAdmin[5], true);

    // Alice cannot view (unless admin assigns AC back)
    try {
      await coc.viewEvidence(caseId, evidenceId, {from: alice});
      assert.fail("Alice should not have access after deletion");
    } catch (e) {
      assert(e.message.includes("Not authorized"));
    }
  });

  it("should record full custody history", async () => {
    // Register new evidence for a clean history
    const evidenceId2 = "EV2";
    const key2 = web3.utils.soliditySha3(caseId, evidenceId2);
    await coc.registerEvidence(
      caseId, evidenceId2, "Bob", "USB Drive", "QmUSBHash", "collected", {from: bob}
    );
    await acToken.assignAC(key2, bob, {from: admin});
    await acToken.assignAC(key2, alice, {from: admin});
    await coc.transferEvidence(
      caseId, evidenceId2, alice, "Alice", "transferred", "Returned to Alice", {from: bob}
    );
    const history = await coc.getHistory(caseId, evidenceId2, {from: admin});
    assert.equal(history.length, 2);
    assert.equal(history[0].holderName, "Bob");
    assert.equal(history[1].holderName, "Alice");
    assert.equal(history[0].action, "collected");
    assert.equal(history[1].action, "transferred");
  });
});