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
(define-constant err-contract-paused (err u108))
(define-constant err-amount-too-large (err u109))

;; Constants for amount limits
(define-constant maximum-payment-amount u1000000000000) ;; 1M STX
(define-constant minimum-payment-amount u1000) ;; 0.001 STX

;; Data Variables
(define-data-var gateway-fee uint u10) ;; 1% default fee
(define-data-var total-transactions uint u0)
(define-data-var total-subscriptions uint u0)
(define-data-var total-refunds uint u0)
(define-data-var contract-paused bool false)

;; Enhanced payments map with metadata
(define-map payments
    { payment-id: uint }
    {
        sender: principal,
        recipient: principal,
        amount: uint,
        status: (string-ascii 20),
        timestamp: uint,
        payment-type: (string-ascii 20),
        refunded: bool,
        metadata: (optional (string-ascii 256))
    }
)

;; Payment status tracking
(define-map payment-status-transitions
    { current: (string-ascii 20) }
    { allowed: (list 10 (string-ascii 20)) }
)

;; Initialize status transitions
(map-set payment-status-transitions
    { current: "pending" }
    { allowed: (list "completed" "failed" "expired") }
)

(map-set payment-status-transitions
    { current: "completed" }
    { allowed: (list "refunded") }
)

;; Enhanced Private Functions
(define-private (validate-payment-status (payment-id uint) (expected-status (string-ascii 20)))
    (match (map-get? payments { payment-id: payment-id })
        payment (is-eq (get status payment) expected-status)
        false
    )
)

(define-private (validate-amount (amount uint))
    (and
        (>= amount minimum-payment-amount)
        (<= amount maximum-payment-amount)
    )
)

(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get gateway-fee)) u1000)
)

;; Admin Functions
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set contract-paused (not (var-get contract-paused))))
    )
)

;; Enhanced process-payment function
(define-public (process-payment 
    (recipient principal) 
    (amount uint)
    (metadata (optional (string-ascii 256))))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (validate-amount amount) err-invalid-amount)
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
                            refunded: false,
                            metadata: metadata
                        }
                    )
                    (var-set total-transactions (+ payment-id u1))
                    (ok payment-id)
                )
                err-invalid-amount
            )
        )
    )
)

;; Rest of the existing contract code...
