# FluxPay

A decentralized payment gateway built on Stacks blockchain that enables secure cryptocurrency transactions and subscription payments.

## Features

- Process one-time cryptocurrency payments
- Subscription payment system with recurring payments
- Track payment and subscription status
- Support for multiple recipients
- Payment verification system
- Transaction history
- Fee management

## Getting Started

1. Clone the repository
2. Install dependencies with `clarinet install`
3. Run tests with `clarinet test`

## Contract Functions

### Payment Functions
- `process-payment`: Process a new payment transaction
- `verify-payment`: Verify payment status
- `get-payment-details`: Get details of a specific payment
- `get-transaction-history`: Get transaction history for an address

### Subscription Functions
- `create-subscription`: Create a new recurring payment subscription
- `process-subscription-payment`: Process a subscription payment
- `cancel-subscription`: Cancel an active subscription
- `get-subscription-details`: Get details of a specific subscription
- `get-subscriber-subscriptions`: Get all subscriptions for a subscriber

### Administrative Functions
- `update-fee`: Update gateway fee (admin only)
- `get-current-fee`: Get current gateway fee

## Subscription System

The subscription system allows users to:
- Create recurring payment schedules
- Set payment frequency in blocks
- Automatically process payments at specified intervals
- Cancel subscriptions at any time
- Track subscription status and payment history
