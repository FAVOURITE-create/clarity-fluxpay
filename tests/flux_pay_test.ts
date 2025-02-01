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
    name: "Ensure subscription creation and processing works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const amount = 1000;
        const frequency = 10; // blocks

        // Create subscription
        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'create-subscription', [
                types.principal(wallet1.address),
                types.uint(amount),
                types.uint(frequency)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
        const subscriptionId = 0;

        // Verify subscription details
        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'get-subscription-details', [
                types.uint(subscriptionId)
            ], deployer.address)
        ]);

        const subscription = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(subscription['status'], "active");
        assertEquals(subscription['amount'], types.uint(1000));
        assertEquals(subscription['frequency'], types.uint(10));

        // Mine blocks to trigger payment
        chain.mineEmptyBlock(frequency);

        // Process subscription payment
        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'process-subscription-payment', [
                types.uint(subscriptionId)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[0].events.expectSTXTransferEvent(
            990,
            deployer.address,
            wallet1.address
        );
    }
});

Clarinet.test({
    name: "Ensure subscription cancellation works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        // Create subscription
        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'create-subscription', [
                types.principal(wallet1.address),
                types.uint(1000),
                types.uint(10)
            ], deployer.address)
        ]);

        // Cancel subscription
        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'cancel-subscription', [
                types.uint(0)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk().expectBool(true);

        // Verify cancelled status
        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'get-subscription-details', [
                types.uint(0)
            ], deployer.address)
        ]);

        const subscription = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(subscription['status'], "cancelled");
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
