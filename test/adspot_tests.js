const Adspot = artifacts.require("Adspot");

var expect = require('chai').expect;
const utils = require('./helpers/utils');
const { time } = require('@openzeppelin/test-helpers');

contract("Adspot", accounts => {
  let alice = accounts[5];
  let bob = accounts[7];
  let ben = accounts[8];
  let kevin = accounts[9];

  let contractInstance;
  let amount = web3.utils.toWei('0.001', 'ether');

  let result;
  let _adspotId;

  const Pending = '0';
  const Accepted = '1';
  const Rejected = '2';
  const Cancelled = '3';
  const Terminated = '4';
  const Completed = '5';

  beforeEach(async () => {
    contractInstance = await Adspot.new();

    result = await contractInstance.create(amount, 3, {from: bob});
    _adspotId = result.logs[0].args.tokenId.toNumber();
  })

  xcontext("In the context of creating and modifying an Adspot", async () => {
    it("It shouldn't allow non-owner to access an Adspot", async () => {
      // console.log(await contractInstance.idToAdSpot(_adspotId));

      await contractInstance.request(_adspotId, 'uri', {from: alice, value: 1.3*amount});
      await utils.shouldThrow(contractInstance.approve(_adspotId, 0, {from: kevin}));
    });
    it("It shouldn't allow owner to approve a Request", async () => {
      await contractInstance.request(_adspotId, 'uri', {from: alice, value: 0.5*amount});
      const r = await contractInstance.approve(_adspotId, 0, {from: bob});
      expect(r.receipt.status).to.equal(true);
    });
  });

  context("In the context of creating Requests and changing status", async () => {
    it("It shouldn't allow more than the maxAds approved", async () => {
      await contractInstance.request(_adspotId, 'uri', {from: alice, value: 2*amount});
      await contractInstance.request(_adspotId, 'uri', {from: alice, value: 1.2*amount});
      await contractInstance.request(_adspotId, 'uri', {from: kevin, value: 1.7*amount});
      await contractInstance.request(_adspotId, 'uri', {from: ben, value: 1.9*amount});

      await contractInstance.approve(_adspotId, 0, {from: bob});
      await contractInstance.approve(_adspotId, 1, {from: bob});
      await contractInstance.approve(_adspotId, 2, {from: bob});

      // console.log(await contractInstance.getRequests(_adspotId));
      await utils.shouldThrow(contractInstance.approve(_adspotId, 3, {from: bob}));
    });
    it("It should process/change Request status correctly", async () => {
      await contractInstance.request(_adspotId, 'uri', {from: ben, value: 0.3*amount});
      await contractInstance.request(_adspotId, 'uri', {from: ben, value: 0.7*amount});

      await contractInstance.reject(_adspotId, 0, {from: bob});
      await contractInstance.approve(_adspotId, 1, {from: bob});

      const requests = await contractInstance.getRequests(_adspotId)

      // console.log(requests)

      expect(requests[0].requestStatus).to.equal(Rejected);
      expect(requests[1].requestStatus).to.equal(Accepted);
    });
    it("It should cancel pending request and receive balance back", async () => {

    });
    it("It should cancel processed request and receive balance diff back", async () => {

    });
    xit("", async () => {

    });
  });
  xcontext("In the context of withdrawing balances", async () => {
    it("It should withdraw the correct amounts based on the timestamps", async () => {

    });
    xit("", async () => {

    });
  });
});
