;; FluxPay - Payment Gateway Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-payment (err u101))
(define-constant err-payment-not-found (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-subscription (err u104))
(define-constant err-subscription-not-found (err u105))
(define-constant err-refund-not-allowed (err u106))
(define-constant err-invalid-status (err u107))

;; Data Variables
(define-data-var gateway-fee uint u10) ;; 1% default fee
(define-data-var total-transactions uint u0)
(define-data-var total-subscriptions uint u0)
(define-data-var total-refunds uint u0)

;; Data Maps
(define-map payments
    { payment-id: uint }
    {
        sender: principal,
        recipient: principal,
        amount: uint,
        status: (string-ascii 20),
        timestamp: uint,
        payment-type: (string-ascii 20),
        refunded: bool
    }
)

(define-map refunds
    { refund-id: uint }
    {
        payment-id: uint,
        amount: uint,
        timestamp: uint,
        status: (string-ascii 20)
    }
)

;; Rest of the existing maps...

;; Private Functions
(define-private (validate-payment-status (payment-id uint) (expected-status (string-ascii 20)))
    (match (map-get? payments { payment-id: payment-id })
        payment (is-eq (get status payment) expected-status)
        false
    )
)

;; Enhanced process-payment function
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
                        timestamp: block-height,
                        payment-type: "one-time",
                        refunded: false
                    }
                )
                (var-set total-transactions (+ payment-id u1))
                (ok payment-id)
            )
            err-invalid-amount
        )
    )
)

;; New refund functionality
(define-public (refund-payment (payment-id uint))
    (match (map-get? payments { payment-id: payment-id })
        payment
        (let
            (
                (refund-id (var-get total-refunds))
                (amount (get amount payment))
                (recipient (get recipient payment))
                (sender (get sender payment))
            )
            (asserts! (validate-payment-status payment-id "completed") err-invalid-status)
            (asserts! (not (get refunded payment)) err-refund-not-allowed)
            (begin
                (try! (stx-transfer? amount recipient sender))
                (map-set payments
                    { payment-id: payment-id }
                    (merge payment { 
                        status: "refunded",
                        refunded: true
                    })
                )
                (map-set refunds
                    { refund-id: refund-id }
                    {
                        payment-id: payment-id,
                        amount: amount,
                        timestamp: block-height,
                        status: "completed"
                    }
                )
                (var-set total-refunds (+ refund-id u1))
                (ok refund-id)
            )
        )
        err-payment-not-found
    )
)

;; New read-only functions
(define-read-only (get-refund-details (refund-id uint))
    (ok (map-get? refunds { refund-id: refund-id }))
)

;; Rest of the existing contract code...
