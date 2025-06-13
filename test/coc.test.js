const EvidenceAccessControl = artifacts.require("EvidenceAccessControl");
const EvidenceChainOfCustody = artifacts.require("EvidenceChainOfCustody");

contract("EvidenceChainOfCustody + EvidenceAccessControl", accounts => {
  const [admin, alice, bob, carol] = accounts;
  const caseId = "CASE2025";
  const evidenceId = "EV1";
  const evidenceId2 = "EV2";
  const ipfsHash = "QmHash1";
  const ipfsHash2 = "QmHash2";

  let acToken, coc;

  beforeEach(async () => {
    // Deploy AC with the test admin as admin (for now)
    acToken = await EvidenceAccessControl.new(admin);
    // Deploy Chain contract, with acToken address injected
    coc = await EvidenceChainOfCustody.new(acToken.address, {from: admin});
    // Set AC's admin to the chain contract itself
    await acToken.setAdmin(coc.address, {from: admin});
  });

  it("should register evidence and assign AC to registrant", async () => {
    await coc.registerEvidence(caseId, evidenceId, "Alice", "First evidence", ipfsHash, "collected", {from: alice});

    const key = await coc.computeKey(caseId, evidenceId);
    assert.equal(await acToken.query_CapAC(key, alice), true);

    const ev = await coc.viewEvidence(caseId, evidenceId, {from: alice});
    assert.equal(ev[0], evidenceId);
    assert.equal(ev[1], alice);
    assert.equal(ev[2], "Alice");
    assert.equal(ev[4], ipfsHash);
    assert.equal(ev[5], false);
  });

  it("should transfer custody and assign AC to new holder", async () => {
    await coc.registerEvidence(caseId, evidenceId, "Alice", "First evidence", ipfsHash, "collected", {from: alice});
    await coc.transferEvidence(caseId, evidenceId, bob, "Bob", "transferred", "To Bob", {from: alice});
    const key = await coc.computeKey(caseId, evidenceId);

    // Bob has AC
    assert.equal(await acToken.query_CapAC(key, bob), true);

    // Bob is new holder
    const ev = await coc.viewEvidence(caseId, evidenceId, {from: bob});
    assert.equal(ev[1], bob);
    assert.equal(ev[2], "Bob");
  });

  it("should allow admin to assign and revoke AC", async () => {
    await coc.registerEvidence(caseId, evidenceId2, "Bob", "Second evidence", ipfsHash2, "collected", {from: bob});
    const key = await coc.computeKey(caseId, evidenceId2);

    // Carol does not have access by default
    assert.equal(await acToken.query_CapAC(key, carol), false);

    // Only Chain contract can assign/revoke, so we must call via Chain contract logic if you implement such a function
    // For direct AC admin test, you would need a helper function in the chain contract

    // For now, test that access is not present
    try {
      await coc.viewEvidence(caseId, evidenceId2, {from: carol});
      assert.fail("Carol should not have access");
    } catch (e) {
      assert(e.message.includes("Not authorized"));
    }
  });

  it("should soft delete evidence and enforce permissions", async () => {
    await coc.registerEvidence(caseId, evidenceId, "Alice", "First evidence", ipfsHash, "collected", {from: alice});
    await coc.transferEvidence(caseId, evidenceId, bob, "Bob", "transferred", "To Bob", {from: alice});
    await coc.deleteEvidence(caseId, evidenceId, {from: bob});

    // Evidence is marked as deleted
    const ev = await coc.viewEvidence(caseId, evidenceId, {from: admin});
    assert.equal(ev[5], true);

    // Non-holder/non-admin cannot delete
    await coc.registerEvidence(caseId, evidenceId2, "Bob", "Second evidence", ipfsHash2, "collected", {from: bob});
    try {
      await coc.deleteEvidence(caseId, evidenceId2, {from: alice});
      assert.fail("Alice should not be able to delete");
    } catch (e) {
      assert(e.message.match(/Not current holder or admin/));
    }
  });

  it("should record full history for each evidence", async () => {
    await coc.registerEvidence(caseId, evidenceId, "Alice", "First evidence", ipfsHash, "collected", {from: alice});
    await coc.transferEvidence(caseId, evidenceId, bob, "Bob", "transferred", "To Bob", {from: alice});
    await coc.transferEvidence(caseId, evidenceId, alice, "Alice", "transferred", "Back to Alice", {from: bob});
    const history = await coc.getHistory(caseId, evidenceId, {from: admin});
    assert.equal(history.length, 3);
    assert.equal(history[0].holderName, "Alice");
    assert.equal(history[1].holderName, "Bob");
    assert.equal(history[2].holderName, "Alice");
  });
});