// Existing test imports...

Clarinet.test({
    name: "Ensure payment refund works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const amount = 1000;

        // Process payment
        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'process-payment', [
                types.principal(wallet1.address),
                types.uint(amount)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
        const paymentId = 0;

        // Refund payment
        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'refund-payment', [
                types.uint(paymentId)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();
        block.receipts[0].events.expectSTXTransferEvent(
            amount,
            wallet1.address,
            deployer.address
        );

        // Verify refund status
        block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'get-payment-details', [
                types.uint(paymentId)
            ], deployer.address)
        ]);

        const payment = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(payment['status'], "refunded");
        assertEquals(payment['refunded'], types.bool(true));
    }
});

// Rest of existing tests...
