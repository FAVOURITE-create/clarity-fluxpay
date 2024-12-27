;; FluxPay - Payment Gateway Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-payment (err u101))
(define-constant err-payment-not-found (err u102))
(define-constant err-invalid-amount (err u103))

;; Data Variables
(define-data-var gateway-fee uint u10) ;; 1% default fee
(define-data-var total-transactions uint u0)

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

;; Private Functions
(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get gateway-fee)) u1000)
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

(define-public (update-fee (new-fee uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set gateway-fee new-fee)
            (ok true)
        )
        err-owner-only
    )
)

(define-read-only (get-payment-details (payment-id uint))
    (match (map-get? payments { payment-id: payment-id })
        payment (ok payment)
        err-payment-not-found
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