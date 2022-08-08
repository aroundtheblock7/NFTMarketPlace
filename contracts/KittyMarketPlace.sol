// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./KittyContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IKittyMarketplace.sol";

contract KittyMarketPlace is Ownable {
    KittyContract private _kittyContract;

    struct Offer {
        address payable seller;
        uint256 price;
        uint256 index;
        uint256 tokenId;
        bool active;
    }
    Offer[] public offers;

    mapping(uint256 => Offer) tokenIdToOffer;

    event MarketTransaction(string TxType, address owner, uint256 tokenId);

    constructor(address _kittyContractAddress) {
        setKittyContract(_kittyContractAddress);
    }

    function setKittyContract(address _kittyContractAddress) public onlyOwner {
        _kittyContract = KittyContract(_kittyContractAddress);
    }

    function getOffer(uint256 _tokenId)
        external
        view
        returns (
            address seller,
            uint256 price,
            uint256 index,
            uint256 tokenId,
            bool active
        )
    {
        Offer storage offer = tokenIdToOffer[_tokenId];
        return (
            offer.seller,
            offer.price,
            offer.index,
            offer.tokenId,
            offer.active
        );
    }

    function getAllTokenOnSale()
        external
        view
        returns (uint256[] memory listOfOffers)
    {
        uint256 totalOffers = offers.length;

        if (totalOffers == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](totalOffers);

            uint256 offerId;

            for (offerId = 0; offerId < totalOffers; offerId++) {
                if (offers[offerId].active == true) {
                    result[offerId] = offers[offerId].tokenId;
                }
            }
            return result;
        }
    }

    function _ownsKitty(address _address, uint256 _tokenId)
        public
        view
        returns (bool)
    {
        return (_kittyContract.ownerOf(_tokenId) == _address);
    }

    function _ownerOf(address _address, uint256 _tokenId)
        external
        view
        returns (address)
    {
        return (_kittyContract.ownerOf(_tokenId));
    }

    function setOffer(uint256 _price, uint256 _tokenId) public {
        require(_ownsKitty(msg.sender, _tokenId), "You are not the owner");
        require(
            tokenIdToOffer[_tokenId].active == false,
            "You can't offer the same token twice"
        );
        require(
            _kittyContract.isApprovedForAll(msg.sender, address(this)),
            "Contract needs approval to create offer"
        );
        Offer memory _offer = Offer({
            seller: payable(msg.sender),
            price: _price,
            active: true,
            tokenId: _tokenId,
            index: offers.length
        });
        tokenIdToOffer[_tokenId] = _offer;
        offers.push(_offer);

        emit MarketTransaction("Create offer", msg.sender, _tokenId);
    }

    function removeOffer(uint256 _tokenId) public {
        Offer memory offer = tokenIdToOffer[_tokenId];
        require(
            offer.seller == msg.sender,
            "You are not the seller of this nft"
        );
        delete tokenIdToOffer[_tokenId];
        offers[tokenIdToOffer[_tokenId].index].active = false;

        emit MarketTransaction("Remove offer", msg.sender, _tokenId);
    }

    function buyKitty(uint256 _tokenId) public payable {
        Offer memory offer = tokenIdToOffer[_tokenId];
        require(msg.value == offer.price, "The price is incorrect");
        require(
            tokenIdToOffer[_tokenId].active == true,
            "No active offer present"
        );

        //Important: Delete the kitty from the mapping before paying out to prevent reentantrancy attacks
        delete tokenIdToOffer[_tokenId];
        offers[tokenIdToOffer[_tokenId].index].active = false;

        //Transfer the funds to the seller
        //TO DO: Make this logic pull instead of push
        if (offer.price > 0) {
            offer.seller.transfer(offer.price);
        }

        //Transfer ownership of the kitty
        _kittyContract.transferFrom(offer.seller, msg.sender, _tokenId);

        emit MarketTransaction("Buy", msg.sender, _tokenId);
    }
}
