const Adspot = artifacts.require("Adspot");

var expect = require('chai').expect;
const utils = require('./helpers/utils');
const { time } = require('@openzeppelin/test-helpers');

contract("Adspot", accounts => {
  let alice = accounts[5];
  let bob = accounts[7];
  let kevin = accounts[9];

  let contractInstance;
  let amount = web3.utils.toWei('0.1', 'ether');

  beforeEach(async () => {
    contractInstance = await Adspot.new();
  })

  xcontext("", async () => {
    it("", async () => {

    });
  });
});
