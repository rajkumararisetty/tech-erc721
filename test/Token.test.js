import {DEFAULT_TOKEN_ADDRESS, EVM_REVERT} from './helper';
const Token = artifacts.require('Token');

require('chai').use(require('chai-as-promised')).should();

contract('Token', ([deployer, otherUser]) => {
    let token;
    const initialBalance = 10;
    beforeEach(async () => {
        // Deploy token
        token = await Token.new(initialBalance);
    });

    describe('Balance after deployemt', () => {
        it('Check balance of deployer', async () => {
            const balance = await token.balanceOf(deployer);
            balance.toString().should.equal(initialBalance.toString());
        });
    });

    describe('issue new tokens', () => {
        const extraTokens = 10;
        describe('Success', () => {
            let result;
            beforeEach(async () => {
                result = await token.issueTokens(extraTokens, {from: deployer});
            });
            it('deployer create new tokens', async () => {
                const balance = await token.balanceOf(deployer);
                balance.toString().should.equal((initialBalance + extraTokens).toString());
            });
            it('Events emitted by issueTokens', async () => {
                const log = result.logs;
                let eachLogEvent;
                for (let eachEvent = 0; eachEvent < extraTokens; eachEvent++) {
                    log[eachEvent]['event'].should.equal('Transfer');
                    eachLogEvent = log[eachEvent]['args'];
                    eachLogEvent.from.should.equal(DEFAULT_TOKEN_ADDRESS);
                    eachLogEvent.to.should.equal(deployer);
                    eachLogEvent.tokenId.toString().should.equal((initialBalance+eachEvent+1).toString());
                }
            });
        });

        describe('Failure', () => {
            it('Try to issue tokens from other user', async () => {
                await token.issueTokens(extraTokens, {from: otherUser}).should.be.rejectedWith(EVM_REVERT);
            });
        });
    });

    describe('owner validation', () => {
        const tokenId = 1;
        describe('Success', () => {
            it('get the owner of the token', async() => {
                const result = await token.ownerOf(tokenId);
                result.should.equal(deployer);
            });
        });

        describe('Failure', () => {
            beforeEach(async() => {
                await token.burnToken(tokenId, {from: deployer});
            });

            it ('check owner of burned token', async () => {
                await token.ownerOf(tokenId).should.be.rejectedWith(EVM_REVERT);
            });

            it('check non existing tokens', async () => {
                await token.ownerOf(10000000).should.be.rejectedWith(EVM_REVERT);
                await token.ownerOf(0).should.be.rejectedWith(EVM_REVERT);
            });
        })
    });

    describe('Burn tokens', () => {
        let result;
        const tokenId = 1;
        beforeEach(async() => {
            result = await token.burnToken(tokenId, {from: deployer});
        });
        describe('Success', () => {

            it('Check balance after burning tokens', async () => {
                const balance = await token.balanceOf(deployer);
                balance.toString().should.equal((initialBalance - 1).toString());
            });

            it('burn event transfers token to token default address', async () => {
                const log = result.logs[0];
                log.event.should.equal('Transfer');
                const event = log.args;
                event.from.should.equal(deployer);
                event.to.should.equal(DEFAULT_TOKEN_ADDRESS);
                event.tokenId.toString().should.equal(tokenId.toString());
            });
        });

        describe('Failure', () => {
            let failureResult;
            it('burn already burned token', async () => {
               await token.burnToken(tokenId, {from: deployer}).should.be.rejectedWith(EVM_REVERT);
            });

            it('burn others token', async () => {
                await token.burnToken(2, {from: otherUser}).should.be.rejectedWith(EVM_REVERT);
            });
        });
    });
});
