const ethUtil = require('ethereumjs-util');
const abi = require('ethereumjs-abi');
const crypto = require('crypto');

const choice = 0; // HEADS=0 , TAILS=1
const account_id = "0xD3776b414F5Ec37a1dd2FDD49BBb502b60A516E3"; // Setup your own account here
const nonce = crypto.randomBytes(32);

const commit = ethUtil.keccak256(abi.rawEncode(["address", "uint8", "bytes32"],[account_id, choice, nonce]));

console.log(
`commit-hash = 0x${commit.toString('hex')}
choice=${choice}
nonce = 0x${nonce.toString('hex')}`
    );