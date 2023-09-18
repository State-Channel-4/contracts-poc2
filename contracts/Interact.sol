// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Data } from "./Data.sol";
import { OnlyBackend } from "./OnlyBackend.sol";

abstract contract Interact is Data, OnlyBackend {
    /// Interaction functions

    /// @notice toggles like status by a given user for given content
    /// @dev this function can only be called by the backend
    /// @dev todo: change string to id to save gas
    /// @param url - the content to like or unlike
    /// @param submittedBy - the user that is liking or unliking content
    function toggleLike(
        string memory url,
        address submittedBy
    ) public onlyBackend {
        // index of content in id map
        uint256 contentId = contents.ids[url];
        // mutable reference to user storage
        User storage user = users.list[users.ids[submittedBy]];
        // check if user already liked the content
        bool alreadyLiked = users.likedContent[submittedBy][contentId];
        
        // toggle binary like state of content for user
        users.likedContent[submittedBy][contentId] = !alreadyLiked;
        // increment or decrement user's liked content sum
        user.numberOfLikedContent = alreadyLiked
            ? user.numberOfLikedContent - 1
            : user.numberOfLikedContent + 1;
        // increment or decrement content's like sum
        contents.list[contentId].likes = alreadyLiked
            ? contents.list[contentId].likes - 1
            : contents.list[contentId].likes + 1;
    }
}