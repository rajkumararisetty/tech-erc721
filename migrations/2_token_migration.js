const Token = artifacts.require('TokenERC721Metadata');

module.exports = function(deployer) {
	const initalSupply = 0;
	deployer.deploy(Token, initalSupply, 'Raj', 'R');
}