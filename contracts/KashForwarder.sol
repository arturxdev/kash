// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "hardhat/console.sol"; 

contract KashTokenForwarder is EIP712 {
    using ECDSA for bytes32;
    // Defining a meta-transaction structure
    struct MetaTx {
        address from;
        address to;
        uint256 nonce;
        bytes data;
    }

    // typeHash
    bytes32 private constant _SIGNATURE_STRUCT_HASH =
        keccak256("MetaTx(address from,address to,uint256 nonce,bytes data)");

    // storing nonces to avoid reply attacks
    mapping(address => uint256) private _nonces;

    // Initiating contracts
    constructor() EIP712("KashTokenForwarder", "0.0.1") {}

    // Getting current nonce for an account
    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }

    // Veriying meta-transaction
    function verifyMetaTx(MetaTx calldata metaTx, bytes calldata signature)
        public
        view
        returns (bool)
    {
        // bytes32 digest = _hashTypedDataV4(
        //     keccak256(
        //         abi.encode(
        //             // hashStruct(s)
        //             _SIGNATURE_STRUCT_HASH,
        //             metaTx.from,
        //             metaTx.to,
        //             metaTx.nonce,
        //             keccak256(metaTx.data)
        //         )
        //     )
        // );
        address signer = _hashTypedDataV4(
            keccak256(abi.encode(_SIGNATURE_STRUCT_HASH, metaTx.from, metaTx.to, metaTx.nonce, keccak256(metaTx.data)))
        ).recover(signature);

        // address metaTxSigner = ECDSA.recover(digest, signature);
        // console.log("from",metaTx.from);
        // console.log("to",metaTx.to);
        // console.log("nonce",metaTx.nonce);
        console.log("signer in contract",signer);
        // Verifying signer does match
        // return metaTxSigner == metaTx.from;
        return signer == metaTx.from;
    }

    // executing a meta-transaction
    function executeFunction(MetaTx calldata metaTx, bytes calldata signature)
        public
        returns (bool)
    {
        // Verifying meta-tx signature
        require(
            verifyMetaTx(metaTx, signature),
            "KashTokenForwarder: Invalid signature"
        );
        // incrementing nonce so the message cannot be used again
        _nonces[metaTx.from] = metaTx.nonce + 1;

        // adding address to the transaction data so the token contract can use it
        (bool success, ) = metaTx.to.call(
            abi.encodePacked(metaTx.data, metaTx.from)
        );
        // returning wheter contract execution was successful
        return success;
    }
}