// Enhanced test file with new test cases
Clarinet.test({
    name: "Ensure payment with metadata works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const amount = 1000;
        const metadata = "Test payment metadata";

        let block = chain.mineBlock([
            Tx.contractCall('flux_pay', 'process-payment', [
                types.principal(wallet1.address),
                types.uint(amount),
                types.some(types.ascii(metadata))
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
        // Additional assertions...
    }
});

// Rest of existing tests...
