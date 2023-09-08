// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Data } from "./Data.sol";
import { Create } from "./Create.sol";
import { Slasher } from "./Slasher.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

abstract contract Litigate is Data, Create, Slasher, EIP712 {

    bytes32 private constant CONTENT_TO_ADD_TYPE =
    keccak256("ContentToAdd(string title,string url,address submittedBy,uint256 likes,string[] tagIds)");

    bytes32 private constant TAG_TO_ADD_TYPE =
    keccak256("TagToAdd(string name,address createdBy,string[] contentIds)");

    constructor(uint256 slashingFee, uint256 backendRegistrationFee)
        EIP712("Channel4Contract", "0.0.1")
        Slasher(slashingFee, backendRegistrationFee)
    {}

    /// Ligitation functions

    /// @notice Verify if EIP-712 signature for content is valid
    /// @dev For EIP-712 in Solidity check https://gist.github.com/markodayan/e05f524b915f129c4f8500df816a369b
    /// @param content Content message
    /// @param signature EIP-712 signature
    function verifyMetaTxContent(ContentToAdd calldata content, bytes calldata signature) public view returns (bool) {
        bytes32[] memory encodedTagIds = new bytes32[](content.tagIds.length);
        for (uint256 i = 0; i < content.tagIds.length; i++) {
            encodedTagIds[i] = keccak256(bytes(content.tagIds[i]));
        }

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            CONTENT_TO_ADD_TYPE,
            keccak256(bytes(content.title)),
            keccak256(bytes(content.url)),
            content.submittedBy,
            content.likes,
            keccak256(abi.encodePacked( encodedTagIds ))
        )));
        address signer = ECDSA.recover(digest, signature);
        return signer == backendAddress;
    }

    /// @notice Verify if EIP-712 signature for tag is valid
    /// @dev For EIP-712 in Solidity check https://gist.github.com/markodayan/e05f524b915f129c4f8500df816a369b
    /// @param tag Tag message
    /// @param signature EIP-712 signature
    function verifyMetaTxTag(TagToAdd calldata tag, bytes calldata signature) public view returns (bool) {
        bytes32[] memory encodedContentIds = new bytes32[](tag.contentIds.length);
        for (uint256 i = 0; i< tag.contentIds.length; i++){
            encodedContentIds[i] = keccak256(bytes(tag.contentIds[i]));
        }

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            TAG_TO_ADD_TYPE,
            keccak256(bytes(tag.name)),
            tag.createdBy,
            keccak256(abi.encodePacked( encodedContentIds ))
        )));
        address signer = ECDSA.recover(digest, signature);
        return signer == backendAddress;
    }

    /// @notice Litigate a specific content (add it and claim slashing)
    /// @dev For more info about verifying EIP-712
    /// check https://github.com/aglawson/Meta-Transactions/blob/main/contracts/MinimalForwarder.sol
    /// @param content Content to litigate
    /// @param signature EIP-712 signature
    function litigateContent(
        ContentToAdd calldata content,
        bytes calldata signature
    ) public returns (bool) {
        require( verifyMetaTxContent(content, signature), "Invalid signature");
        // check if content is already registered
        string memory firstUrl = contents.list[0].url;
        require( keccak256(bytes(content.url)) != keccak256(bytes(firstUrl)), "Initial content is not litigable" );
        uint256 contentIndex = contents.ids[content.url];
        if (contentIndex != 0){
            // content exists, check if constant values are correct
            Content memory existingContent = contents.list[contentIndex];
            bool isTitleCorrect = keccak256(bytes(content.title)) == keccak256(bytes(existingContent.title));
            bool isSubmittedByCorrect = content.submittedBy == existingContent.submittedBy;
            bool isTagIdsCorrect = content.tagIds.length == existingContent.tagIds.length;
            bool isTagNameCorrect = false;
            if (isTagIdsCorrect){
                for (uint256 i = 0; i < content.tagIds.length; i++) {
                    isTagNameCorrect =
                        keccak256(bytes(content.tagIds[i]))
                        ==
                        keccak256(bytes(tags.list[existingContent.tagIds[i]].name));
                    isTagIdsCorrect = isTagIdsCorrect && isTagNameCorrect;
                }
            }
            // if Content values are correct return false because litigation is not correct
            if (isTitleCorrect && isSubmittedByCorrect && isTagIdsCorrect){
                return false;
            }
        }
        // content does not exists or values are incorrect, add it or modify it
        _createContentIfNotExists(
            content.title,
            content.url,
            content.submittedBy,
            content.likes,
            content.tagIds
        );
        slashBackend(msg.sender);
        return true;
    }

    /// @notice Litigate a specific tag (add it and claim slashing)
    /// @dev For more info about verifying EIP-712
    /// check https://github.com/aglawson/Meta-Transactions/blob/main/contracts/MinimalForwarder.sol
    /// @param tag Tag to litigate
    /// @param signature EIP-712 signature
    function litigateTag(
        TagToAdd calldata tag,
        bytes calldata signature
    ) public returns (bool) {
        require( verifyMetaTxTag(tag, signature), "Invalid signature" );
        // check if tag is already registered
        string memory firstTag = tags.list[0].name;
        require( keccak256(bytes(tag.name)) != keccak256(bytes(firstTag)), "Initial tag is not litigable" );
        uint256 tagIndex = tags.ids[tag.name];
        if (tagIndex != 0){
            // tag exists, check if constant values are correct
            Tag memory existingTag = tags.list[tagIndex];
            bool isNameCorrect = keccak256(bytes(tag.name)) == keccak256(bytes(existingTag.name));
            bool isCreatedByCorrect = tag.createdBy == existingTag.createdBy;
            // if tag values are correct return false because litigation is not correct
            if (isNameCorrect && isCreatedByCorrect){
                return false;
            }
        }
        // tag does not exists or values are incorrect, add it or modify it
        _createTagIfNotExists(
            tag.name,
            tag.createdBy
        );
        slashBackend(msg.sender);
        return true;
    }
}