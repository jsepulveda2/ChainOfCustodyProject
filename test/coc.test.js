const CoC = artifacts.require("CoC");

contract("CoC", accounts => {
  const [admin, alice, bob, carol] = accounts;

  it("should register new evidence", async () => {
    const coc = await CoC.deployed();
    await coc.registerEvidence(
      "CASE123", "EV1", "Alice", "Laptop evidence", "QmHash", "collected",
      {from: alice}
    );
    const ev = await coc.viewEvidence("CASE123", "EV1", {from: alice});
    assert.equal(ev[0], "EV1");
    assert.equal(ev[1], "CASE123");
    assert.equal(ev[2], alice);
    assert.equal(ev[3], "Alice");
    assert.equal(ev[4], "Laptop evidence");
    assert.equal(ev[5], "QmHash");
    assert.equal(ev[6], false);
  });

  it("should transfer custody", async () => {
    const coc = await CoC.deployed();
    await coc.transferEvidence(
      "CASE123", "EV1", bob, "Bob", "transferred", "For analysis",
      {from: alice}
    );
    const ev = await coc.viewEvidence("CASE123", "EV1", {from: bob});
    assert.equal(ev[2], bob);
    assert.equal(ev[3], "Bob");
  });

  it("should grant and revoke access", async () => {
    const coc = await CoC.deployed();
    await coc.grantAccess("CASE123", "EV1", carol, {from: bob});
    let ev = await coc.viewEvidence("CASE123", "EV1", {from: carol});
    assert.equal(ev[0], "EV1");
    await coc.revokeAccess("CASE123", "EV1", carol, {from: bob});
    try {
      await coc.viewEvidence("CASE123", "EV1", {from: carol});
      assert.fail("Carol should not have access after revoke");
    } catch (e) {
      assert(e.message.includes("Not authorized"));
    }
  });

  it("should soft delete evidence", async () => {
    const coc = await CoC.deployed();
    await coc.deleteEvidence("CASE123", "EV1", {from: bob});
    const ev = await coc.viewEvidence("CASE123", "EV1", {from: admin});
    assert.equal(ev[6], true);
  });

  it("should record full history", async () => {
    const coc = await CoC.deployed();
    await coc.registerEvidence(
      "CASE123", "EV2", "Bob", "USB evidence", "QmUSB", "collected", {from: bob}
    );
    await coc.transferEvidence(
      "CASE123", "EV2", alice, "Alice", "transferred", "Returned to Alice", {from: bob}
    );
    const history = await coc.getHistory("CASE123", "EV2", {from: admin});
    assert.equal(history.length, 2);
    assert.equal(history[0].holderName, "Bob");
    assert.equal(history[1].holderName, "Alice");
  });
});