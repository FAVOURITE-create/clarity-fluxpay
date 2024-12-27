import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that payment processing works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const amount = 1000;

        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'process-payment', [
                types.principal(wallet1.address),
                types.uint(amount)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[0].events.expectSTXTransferEvent(
            990, // amount - 1% fee
            deployer.address,
            wallet1.address
        );
        block.receipts[0].events.expectSTXTransferEvent(
            10, // fee
            deployer.address,
            deployer.address
        );
    }
});

Clarinet.test({
    name: "Ensure that only owner can update fee",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'update-fee', [
                types.uint(20)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectErr(types.uint(100)); // err-owner-only

        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'update-fee', [
                types.uint(20)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Ensure payment details can be retrieved",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'process-payment', [
                types.principal(wallet1.address),
                types.uint(1000)
            ], deployer.address)
        ]);

        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'get-payment-details', [
                types.uint(0)
            ], deployer.address)
        ]);

        const payment = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(payment['status'], "completed");
        assertEquals(payment['amount'], types.uint(1000));
    }
});

Clarinet.test({
    name: "Ensure payment verification works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'process-payment', [
                types.principal(wallet1.address),
                types.uint(1000)
            ], deployer.address)
        ]);

        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'verify-payment', [
                types.uint(0)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk().expectAscii("completed");
    }
});