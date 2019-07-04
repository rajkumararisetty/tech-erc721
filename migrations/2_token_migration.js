const Token = artifacts.require('Token');

module.exports = function(deployer) {
	const initalSupply = 0;
	deployer.deploy(Token, initalSupply);
}