import {DEFAULT_TOKEN_ADDRESS, EVM_REVERT} from './helper';
const Token = artifacts.require('Token');

require('chai').use(require('chai-as-promised')).should();

contract('Token', ([deployer, otherUser, operator]) => {
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

    describe('Approve for all tokens of owner', () => {
        describe('Success approval', () => {
            let result;
            beforeEach(async () => {
                result = await token.setApprovalForAll(operator, true, {from: deployer});
            });

            it('check approval status', async () => {
                const status = await token.isApprovedForAll(deployer, operator);
                status.should.equal(true);
            });

            it('set approval emits event', async () => {
                const log = result.logs[0];
                log.event.should.equal('ApprovalForAll');
                const event = log.args;
                event.owner.should.equal(deployer);
                event.operator.should.equal(operator);
                event.approved.should.equal(true);
            });

            it('remove approval all for operator', async () => {
                let result = await token.setApprovalForAll(operator, false, {from: deployer});

                const status = await token.isApprovedForAll(deployer, operator);
                status.should.equal(false);

                const log = result.logs[0];
                log.event.should.equal('ApprovalForAll');
                const event = log.args;
                event.owner.should.equal(deployer);
                event.operator.should.equal(operator);
                event.approved.should.equal(false);
            })
        });

        describe('Not approval all check', () => {
            it('status false if not approved operator', async () => {
                const status = await token.isApprovedForAll(deployer, operator);
                status.should.equal(false);
            });
        });
    });

    describe('Approve specific token', () => {
        const tokenId = 1;
        describe('Success', () => {
            let result;
            beforeEach(async () => {
                result = await token.approve(operator, tokenId, {from: deployer});
            });

            it('get token approval address', async () => {
                const approvedAddress = await token.getApproved(tokenId);
                approvedAddress.should.equal(operator);
            });

            it('event on token approval', async () => {
                const log = result.logs[0];
                log.event.should.equal('Approval');
                const event = log.args;
                event.owner.should.equal(deployer);
                event.approved.should.equal(operator);
                event.tokenId.toString().should.equal(tokenId.toString());
            });
        });

        describe('Failure', () => {
            it("try to approve for other's tokens", async () => {
                await token.approve(operator, tokenId, {from: otherUser}).should.be.rejectedWith(EVM_REVERT);
            });
        });
    });

    describe('Transfer actions', () => {
        describe('Success', () => {
            describe('Transfer own tokens', () => {
                let result;
                let balance;
                const tokenId = 1;
                beforeEach(async () => {
                    result = await token.transferFrom(deployer, otherUser, tokenId, {from: deployer});
                });

                it('Check balances', async () => {
                    balance = await token.balanceOf(deployer);
                    balance.toString().should.equal((initialBalance - 1).toString());

                    balance = await token.balanceOf(otherUser);
                    balance.toString().should.equal('1');
                });

                it('Transfer event emitted', async () => {
                    const log = result.logs[0];
                    log.event.should.equal('Transfer');
                    const event = log.args;
                    event.from.should.equal(deployer);
                    event.to.should.equal(otherUser);
                    event.tokenId.toString().should.equal(tokenId.toString());
                });
            });

            describe('Transfer approved token', () => {

            });

            describe('Transfer tokens as operator(setApprovalForAll)', () => {

            });
        });
    });
});
