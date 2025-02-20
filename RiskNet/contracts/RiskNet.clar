;; RiskNet Smart Contract

;; Contract constants
(define-constant SYSTEM_OWNER tx-sender)
(define-constant ERR_ACCESS_DENIED (err u1))
(define-constant ERR_FUNDING_REQUIRED (err u2))
(define-constant ERR_INVALID_REQUEST (err u3))
(define-constant ERR_PREVIOUS_PARTICIPATION (err u4))
(define-constant ERR_DEADLINE_PASSED (err u5))
(define-constant ERR_SEQUENTIAL_UPDATE (err u6))

;; Manual Block Height Tracking
(define-data-var ledger_position uint u0)
(define-data-var recent_submitter principal tx-sender)

;; Block Height Update Function
(define-public (increment_ledger_position)
    (begin
        ;; Prevent multiple updates by the same sender in quick succession
        (asserts! 
            (not (is-eq (var-get recent_submitter) tx-sender)) 
            ERR_SEQUENTIAL_UPDATE
        )

        ;; Update block height
        (var-set ledger_position 
            (+ (var-get ledger_position) u1)
        )

        ;; Record last updater
        (var-set recent_submitter tx-sender)

        (ok (var-get ledger_position))
    )
)

;; Storage for insurance pool
(define-map protection_pool 
    {participant: principal} 
    {
        deposit_amount: uint,
        protection_active: bool,
        enrollment_block: uint
    }
)

;; Storage for claims
(define-map incident_log
    {incident_id: uint}
    {
        affected_service: principal,
        compensation_amount: uint,
        ballot_count: uint,
        approval_count: uint,
        resolution_complete: bool,
        filing_block: uint,
        ballot_deadline: uint
    }
)

;; Track votes for each member on each claim
(define-map ballot_record
    {participant: principal, incident_id: uint}
    {ballot_cast: bool}
)

;; Track total pool funds and next claim ID
(define-data-var reserve_balance uint u0)
(define-data-var incident_counter uint u1)

;; Voting period constants
(define-constant DECISION_WINDOW u144) ;; Approximately 24 hours 
(define-constant COVERAGE_DURATION u1440) ;; Approximately 10 days

;; Member contribution function
(define-public (deposit_funds (payment_amount uint))
    (let 
        (
            (current_position (var-get ledger_position))
        )
        (begin
            ;; Ensure minimum contribution
            (asserts! (> payment_amount u0) ERR_FUNDING_REQUIRED)

            ;; Transfer STX to contract
            (try! (stx-transfer? payment_amount tx-sender (as-contract tx-sender)))

            ;; Update pool mapping
            (map-set protection_pool 
                {participant: tx-sender} 
                {
                    deposit_amount: payment_amount,
                    protection_active: true,
                    enrollment_block: current_position
                }
            )

            ;; Increment total pool funds
            (var-set reserve_balance 
                (+ (var-get reserve_balance) payment_amount)
            )

            (ok true)
        )
    )
)

;; Submit claim function
(define-public (report_incident 
    (affected_service principal) 
    (compensation_amount uint)
)
    (let 
        (
            (incident_id (var-get incident_counter))
            (current_position (var-get ledger_position))
            (participant_record 
                (unwrap! 
                    (map-get? protection_pool {participant: tx-sender}) 
                    ERR_ACCESS_DENIED
                )
            )
            (decision_deadline (+ current_position DECISION_WINDOW))
        )

        ;; Ensure member has active coverage
        (asserts! (get protection_active participant_record) ERR_ACCESS_DENIED)

        ;; Ensure claim is submitted within coverage period
        (asserts! 
            (<= 
                (- current_position (get enrollment_block participant_record)) 
                COVERAGE_DURATION
            ) 
            ERR_DEADLINE_PASSED
        )

        ;; Create claim
        (map-set incident_log 
            {incident_id: incident_id}
            {
                affected_service: affected_service,
                compensation_amount: compensation_amount,
                ballot_count: u0,
                approval_count: u0,
                resolution_complete: false,
                filing_block: current_position,
                ballot_deadline: decision_deadline
            }
        )

        ;; Increment next claim ID
        (var-set incident_counter (+ incident_id u1))

        (ok incident_id)
    )
)

;; Vote on claim
(define-public (submit_decision 
    (incident_id uint) 
    (approve bool)
)
    (let 
        (
            (current_position (var-get ledger_position))
            (incident_record 
                (unwrap! 
                    (map-get? incident_log {incident_id: incident_id}) 
                    ERR_INVALID_REQUEST
                )
            )
            (participant_record 
                (unwrap! 
                    (map-get? protection_pool {participant: tx-sender}) 
                    ERR_ACCESS_DENIED
                )
            )
        )

        ;; Ensure voting is still open
        (asserts! (< current_position (get ballot_deadline incident_record)) ERR_DEADLINE_PASSED)

        ;; Prevent duplicate voting
        (asserts! 
            (not (default-to false 
                (get ballot_cast (map-get? ballot_record {participant: tx-sender, incident_id: incident_id}))
            )) 
            ERR_PREVIOUS_PARTICIPATION
        )

        ;; Update votes
        (map-set incident_log 
            {incident_id: incident_id}
            (merge incident_record 
                {
                    ballot_count: (+ (get ballot_count incident_record) u1),
                    approval_count: (if approve 
                        (+ (get approval_count incident_record) u1)
                        (get approval_count incident_record)
                    )
                }
            )
        )

        ;; Track individual member votes
        (map-set ballot_record 
            {participant: tx-sender, incident_id: incident_id}
            {ballot_cast: true}
        )

        (ok true)
    )
)

;; Read-only function to get current block height
(define-read-only (get_ledger_position)
    (var-get ledger_position)
)