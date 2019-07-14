const Token = artifacts.require('Token');

module.exports = function(deployer) {
	const initalSupply = 0;
	deployer.deploy(Token, initalSupply, 'Raj', 'R', 'https://www.super.com/');
}