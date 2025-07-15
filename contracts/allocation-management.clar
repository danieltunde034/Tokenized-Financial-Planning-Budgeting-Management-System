;; Allocation Management Contract
;; Manages budget allocations and fund distribution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-BUDGET-LOCKED (err u105))

;; Data Variables
(define-data-var next-allocation-id uint u1)
(define-data-var next-request-id uint u1)

;; Data Maps
(define-map allocations
  { allocation-id: uint }
  {
    budget-id: uint,
    category-id: uint,
    allocated-amount: uint,
    spent-amount: uint,
    reserved-amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    last-updated: uint
  }
)

(define-map allocation-requests
  { request-id: uint }
  {
    allocation-id: uint,
    requester: principal,
    requested-amount: uint,
    purpose: (string-ascii 200),
    status: (string-ascii 20),
    created-at: uint,
    approved-at: (optional uint),
    approver: (optional principal)
  }
)

(define-map budget-allocations
  { budget-id: uint, category-id: uint }
  { allocation-id: uint }
)

(define-map spending-records
  { allocation-id: uint, record-id: uint }
  {
    amount: uint,
    description: (string-ascii 200),
    spender: principal,
    timestamp: uint,
    transaction-ref: (optional (buff 32))
  }
)

(define-map allocation-managers
  { manager: principal }
  { can-approve: bool, max-approval-amount: uint }
)

;; Data Variables for record tracking
(define-data-var next-record-id uint u1)

;; Read-only functions
(define-read-only (get-allocation (allocation-id uint))
  (map-get? allocations { allocation-id: allocation-id })
)

(define-read-only (get-allocation-request (request-id uint))
  (map-get? allocation-requests { request-id: request-id })
)

(define-read-only (get-budget-allocation (budget-id uint) (category-id uint))
  (match (map-get? budget-allocations { budget-id: budget-id, category-id: category-id })
    allocation-data (get-allocation (get allocation-id allocation-data))
    none
  )
)

(define-read-only (get-available-funds (allocation-id uint))
  (match (get-allocation allocation-id)
    allocation-data
      (some (- (- (get allocated-amount allocation-data) (get spent-amount allocation-data)) (get reserved-amount allocation-data)))
    none
  )
)

(define-read-only (get-spending-record (allocation-id uint) (record-id uint))
  (map-get? spending-records { allocation-id: allocation-id, record-id: record-id })
)

(define-read-only (can-approve-allocation (manager principal) (amount uint))
  (match (map-get? allocation-managers { manager: manager })
    manager-data
      (and
        (get can-approve manager-data)
        (<= amount (get max-approval-amount manager-data))
      )
    false
  )
)

;; Public functions
(define-public (create-allocation (budget-id uint) (category-id uint) (allocated-amount uint))
  (let
    (
      (allocation-id (var-get next-allocation-id))
    )
    (asserts! (> allocated-amount u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? budget-allocations { budget-id: budget-id, category-id: category-id })) ERR-INVALID-INPUT)

    (map-set allocations
      { allocation-id: allocation-id }
      {
        budget-id: budget-id,
        category-id: category-id,
        allocated-amount: allocated-amount,
        spent-amount: u0,
        reserved-amount: u0,
        status: "active",
        created-at: block-height,
        last-updated: block-height
      }
    )

    (map-set budget-allocations
      { budget-id: budget-id, category-id: category-id }
      { allocation-id: allocation-id }
    )

    (var-set next-allocation-id (+ allocation-id u1))
    (ok allocation-id)
  )
)

(define-public (request-allocation (allocation-id uint) (requested-amount uint) (purpose (string-ascii 200)))
  (let
    (
      (allocation-data (unwrap! (get-allocation allocation-id) ERR-NOT-FOUND))
      (request-id (var-get next-request-id))
      (available-funds (unwrap! (get-available-funds allocation-id) ERR-NOT-FOUND))
    )
    (asserts! (> requested-amount u0) ERR-INVALID-INPUT)
    (asserts! (<= requested-amount available-funds) ERR-INSUFFICIENT-FUNDS)
    (asserts! (is-eq (get status allocation-data) "active") ERR-BUDGET-LOCKED)
    (asserts! (> (len purpose) u0) ERR-INVALID-INPUT)

    (map-set allocation-requests
      { request-id: request-id }
      {
        allocation-id: allocation-id,
        requester: tx-sender,
        requested-amount: requested-amount,
        purpose: purpose,
        status: "pending",
        created-at: block-height,
        approved-at: none,
        approver: none
      }
    )

    ;; Reserve the requested amount
    (map-set allocations
      { allocation-id: allocation-id }
      (merge allocation-data {
        reserved-amount: (+ (get reserved-amount allocation-data) requested-amount),
        last-updated: block-height
      })
    )

    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (approve-allocation-request (request-id uint))
  (let
    (
      (request-data (unwrap! (get-allocation-request request-id) ERR-NOT-FOUND))
      (allocation-data (unwrap! (get-allocation (get allocation-id request-data)) ERR-NOT-FOUND))
    )
    (asserts! (can-approve-allocation tx-sender (get requested-amount request-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) "pending") ERR-INVALID-INPUT)

    (map-set allocation-requests
      { request-id: request-id }
      (merge request-data {
        status: "approved",
        approved-at: (some block-height),
        approver: (some tx-sender)
      })
    )

    ;; Move from reserved to spent
    (map-set allocations
      { allocation-id: (get allocation-id request-data) }
      (merge allocation-data {
        spent-amount: (+ (get spent-amount allocation-data) (get requested-amount request-data)),
        reserved-amount: (- (get reserved-amount allocation-data) (get requested-amount request-data)),
        last-updated: block-height
      })
    )

    (ok true)
  )
)

(define-public (reject-allocation-request (request-id uint))
  (let
    (
      (request-data (unwrap! (get-allocation-request request-id) ERR-NOT-FOUND))
      (allocation-data (unwrap! (get-allocation (get allocation-id request-data)) ERR-NOT-FOUND))
    )
    (asserts! (can-approve-allocation tx-sender (get requested-amount request-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) "pending") ERR-INVALID-INPUT)

    (map-set allocation-requests
      { request-id: request-id }
      (merge request-data { status: "rejected" })
    )

    ;; Release reserved amount
    (map-set allocations
      { allocation-id: (get allocation-id request-data) }
      (merge allocation-data {
        reserved-amount: (- (get reserved-amount allocation-data) (get requested-amount request-data)),
        last-updated: block-height
      })
    )

    (ok true)
  )
)

(define-public (record-spending (allocation-id uint) (amount uint) (description (string-ascii 200)) (transaction-ref (optional (buff 32))))
  (let
    (
      (allocation-data (unwrap! (get-allocation allocation-id) ERR-NOT-FOUND))
      (record-id (var-get next-record-id))
    )
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status allocation-data) "active") ERR-BUDGET-LOCKED)

    (map-set spending-records
      { allocation-id: allocation-id, record-id: record-id }
      {
        amount: amount,
        description: description,
        spender: tx-sender,
        timestamp: block-height,
        transaction-ref: transaction-ref
      }
    )

    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

(define-public (update-allocation-amount (allocation-id uint) (new-amount uint))
  (let
    (
      (allocation-data (unwrap! (get-allocation allocation-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-amount u0) ERR-INVALID-INPUT)
    (asserts! (>= new-amount (+ (get spent-amount allocation-data) (get reserved-amount allocation-data))) ERR-INSUFFICIENT-FUNDS)

    (map-set allocations
      { allocation-id: allocation-id }
      (merge allocation-data {
        allocated-amount: new-amount,
        last-updated: block-height
      })
    )

    (ok true)
  )
)

(define-public (freeze-allocation (allocation-id uint))
  (let
    (
      (allocation-data (unwrap! (get-allocation allocation-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set allocations
      { allocation-id: allocation-id }
      (merge allocation-data {
        status: "frozen",
        last-updated: block-height
      })
    )

    (ok true)
  )
)

(define-public (unfreeze-allocation (allocation-id uint))
  (let
    (
      (allocation-data (unwrap! (get-allocation allocation-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status allocation-data) "frozen") ERR-INVALID-INPUT)

    (map-set allocations
      { allocation-id: allocation-id }
      (merge allocation-data {
        status: "active",
        last-updated: block-height
      })
    )

    (ok true)
  )
)

(define-public (set-allocation-manager (manager principal) (can-approve bool) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set allocation-managers
      { manager: manager }
      { can-approve: can-approve, max-approval-amount: max-amount }
    )

    (ok true)
  )
)
