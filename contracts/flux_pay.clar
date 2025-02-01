;; FluxPay - Payment Gateway Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-payment (err u101))
(define-constant err-payment-not-found (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-subscription (err u104))
(define-constant err-subscription-not-found (err u105))

;; Data Variables
(define-data-var gateway-fee uint u10) ;; 1% default fee
(define-data-var total-transactions uint u0)
(define-data-var total-subscriptions uint u0)

;; Data Maps
(define-map payments
    { payment-id: uint }
    {
        sender: principal,
        recipient: principal,
        amount: uint,
        status: (string-ascii 20),
        timestamp: uint
    }
)

(define-map transaction-history
    principal
    (list 50 uint)
)

(define-map subscriptions
    { subscription-id: uint }
    {
        subscriber: principal,
        recipient: principal,
        amount: uint,
        frequency: uint,
        next-payment: uint,
        status: (string-ascii 20)
    }
)

(define-map subscriber-subscriptions
    principal
    (list 20 uint)
)

;; Private Functions
(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get gateway-fee)) u1000)
)

(define-private (add-subscription-to-subscriber (subscriber principal) (subscription-id uint))
    (match (map-get? subscriber-subscriptions subscriber)
        existing-list (map-set subscriber-subscriptions 
            subscriber
            (unwrap-panic (as-max-len? (append existing-list subscription-id) u20)))
        (map-set subscriber-subscriptions
            subscriber
            (list subscription-id))
    )
)

;; Public Functions 
(define-public (process-payment (recipient principal) (amount uint))
    (let
        (
            (payment-id (var-get total-transactions))
            (fee (calculate-fee amount))
            (final-amount (- amount fee))
        )
        (if (> amount u0)
            (begin
                (try! (stx-transfer? final-amount tx-sender recipient))
                (try! (stx-transfer? fee tx-sender contract-owner))
                (map-set payments
                    { payment-id: payment-id }
                    {
                        sender: tx-sender,
                        recipient: recipient,
                        amount: amount,
                        status: "completed",
                        timestamp: block-height
                    }
                )
                (var-set total-transactions (+ payment-id u1))
                (ok payment-id)
            )
            err-invalid-amount
        )
    )
)

(define-public (create-subscription (recipient principal) (amount uint) (frequency uint))
    (let
        (
            (subscription-id (var-get total-subscriptions))
            (next-payment (+ block-height frequency))
        )
        (if (and (> amount u0) (> frequency u0))
            (begin
                (map-set subscriptions
                    { subscription-id: subscription-id }
                    {
                        subscriber: tx-sender,
                        recipient: recipient,
                        amount: amount,
                        frequency: frequency,
                        next-payment: next-payment,
                        status: "active"
                    }
                )
                (add-subscription-to-subscriber tx-sender subscription-id)
                (var-set total-subscriptions (+ subscription-id u1))
                (ok subscription-id)
            )
            err-invalid-subscription
        )
    )
)

(define-public (process-subscription-payment (subscription-id uint))
    (match (map-get? subscriptions { subscription-id: subscription-id })
        subscription
        (let
            (
                (amount (get amount subscription))
                (subscriber (get subscriber subscription))
                (recipient (get recipient subscription))
                (frequency (get frequency subscription))
                (next-payment (get next-payment subscription))
            )
            (if (>= block-height next-payment)
                (begin
                    (try! (process-payment recipient amount))
                    (map-set subscriptions
                        { subscription-id: subscription-id }
                        (merge subscription { next-payment: (+ block-height frequency) })
                    )
                    (ok true)
                )
                (ok false)
            )
        )
        err-subscription-not-found
    )
)

(define-public (cancel-subscription (subscription-id uint))
    (match (map-get? subscriptions { subscription-id: subscription-id })
        subscription
        (if (is-eq (get subscriber subscription) tx-sender)
            (begin
                (map-set subscriptions
                    { subscription-id: subscription-id }
                    (merge subscription { status: "cancelled" })
                )
                (ok true)
            )
            err-owner-only
        )
        err-subscription-not-found
    )
)

(define-public (update-fee (new-fee uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set gateway-fee new-fee)
            (ok true)
        )
        err-owner-only
    )
)

;; Read-only Functions
(define-read-only (get-payment-details (payment-id uint))
    (match (map-get? payments { payment-id: payment-id })
        payment (ok payment)
        err-payment-not-found
    )
)

(define-read-only (get-subscription-details (subscription-id uint))
    (match (map-get? subscriptions { subscription-id: subscription-id })
        subscription (ok subscription)
        err-subscription-not-found
    )
)

(define-read-only (get-subscriber-subscriptions (subscriber principal))
    (match (map-get? subscriber-subscriptions subscriber)
        subscriptions (ok subscriptions)
        (ok (list))
    )
)

(define-read-only (get-current-fee)
    (ok (var-get gateway-fee))
)

(define-read-only (get-total-transactions)
    (ok (var-get total-transactions))
)

(define-read-only (verify-payment (payment-id uint))
    (match (map-get? payments { payment-id: payment-id })
        payment (ok (get status payment))
        err-payment-not-found
    )
)
