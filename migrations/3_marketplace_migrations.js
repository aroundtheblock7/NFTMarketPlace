const KittyContract = artifacts.require("KittyContract");
const Marketplace = artifacts.require("KittyMarketPlace")

module.exports = function (deployer) {
    deployer.deploy(Marketplace, KittyContract.address);
};
