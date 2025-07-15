;; Budget Creation Contract
;; Handles creation and management of organizational budgets

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-PERIOD (err u106))

;; Data Variables
(define-data-var next-budget-id uint u1)
(define-data-var next-category-id uint u1)

;; Data Maps
(define-map budgets
  { budget-id: uint }
  {
    organization: (string-ascii 100),
    creator: principal,
    total-amount: uint,
    start-period: uint,
    end-period: uint,
    status: (string-ascii 20),
    created-at: uint,
    approved-at: (optional uint),
    approver: (optional principal)
  }
)

(define-map budget-categories
  { budget-id: uint, category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    allocated-amount: uint,
    priority: uint,
    created-at: uint
  }
)

(define-map organization-budgets
  { organization: (string-ascii 100), period: uint }
  { budget-id: uint }
)

(define-map budget-approvers
  { approver: principal }
  { can-approve: bool, max-approval-amount: uint }
)

;; Read-only functions
(define-read-only (get-budget (budget-id uint))
  (map-get? budgets { budget-id: budget-id })
)

(define-read-only (get-budget-category (budget-id uint) (category-id uint))
  (map-get? budget-categories { budget-id: budget-id, category-id: category-id })
)

(define-read-only (get-organization-budget (organization (string-ascii 100)) (period uint))
  (match (map-get? organization-budgets { organization: organization, period: period })
    budget-data (get-budget (get budget-id budget-data))
    none
  )
)

(define-read-only (is-budget-active (budget-id uint))
  (match (get-budget budget-id)
    budget-data
      (and
        (is-eq (get status budget-data) "active")
        (>= block-height (get start-period budget-data))
        (<= block-height (get end-period budget-data))
      )
    false
  )
)

(define-read-only (can-approve-budget (approver principal) (budget-amount uint))
  (match (map-get? budget-approvers { approver: approver })
    approver-data
      (and
        (get can-approve approver-data)
        (<= budget-amount (get max-approval-amount approver-data))
      )
    false
  )
)

;; Public functions
(define-public (create-budget (organization (string-ascii 100)) (total-amount uint) (start-period uint) (end-period uint))
  (let
    (
      (budget-id (var-get next-budget-id))
      (caller tx-sender)
    )
    (asserts! (> (len organization) u0) ERR-INVALID-INPUT)
    (asserts! (> total-amount u0) ERR-INVALID-INPUT)
    (asserts! (< start-period end-period) ERR-INVALID-PERIOD)
    (asserts! (> end-period block-height) ERR-INVALID-PERIOD)

    (map-set budgets
      { budget-id: budget-id }
      {
        organization: organization,
        creator: caller,
        total-amount: total-amount,
        start-period: start-period,
        end-period: end-period,
        status: "draft",
        created-at: block-height,
        approved-at: none,
        approver: none
      }
    )

    (var-set next-budget-id (+ budget-id u1))
    (ok budget-id)
  )
)

(define-public (add-budget-category (budget-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (allocated-amount uint) (priority uint))
  (let
    (
      (budget-data (unwrap! (get-budget budget-id) ERR-NOT-FOUND))
      (category-id (var-get next-category-id))
    )
    (asserts! (is-eq tx-sender (get creator budget-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status budget-data) "draft") ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> allocated-amount u0) ERR-INVALID-INPUT)
    (asserts! (<= priority u10) ERR-INVALID-INPUT)

    (map-set budget-categories
      { budget-id: budget-id, category-id: category-id }
      {
        name: name,
        description: description,
        allocated-amount: allocated-amount,
        priority: priority,
        created-at: block-height
      }
    )

    (var-set next-category-id (+ category-id u1))
    (ok category-id)
  )
)

(define-public (submit-for-approval (budget-id uint))
  (let
    (
      (budget-data (unwrap! (get-budget budget-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator budget-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status budget-data) "draft") ERR-NOT-AUTHORIZED)

    (map-set budgets
      { budget-id: budget-id }
      (merge budget-data { status: "pending-approval" })
    )

    (ok true)
  )
)

(define-public (approve-budget (budget-id uint))
  (let
    (
      (budget-data (unwrap! (get-budget budget-id) ERR-NOT-FOUND))
      (caller tx-sender)
    )
    (asserts! (can-approve-budget caller (get total-amount budget-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status budget-data) "pending-approval") ERR-NOT-AUTHORIZED)

    (map-set budgets
      { budget-id: budget-id }
      (merge budget-data {
        status: "approved",
        approved-at: (some block-height),
        approver: (some caller)
      })
    )

    (map-set organization-budgets
      { organization: (get organization budget-data), period: (get start-period budget-data) }
      { budget-id: budget-id }
    )

    (ok true)
  )
)

(define-public (activate-budget (budget-id uint))
  (let
    (
      (budget-data (unwrap! (get-budget budget-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq (get status budget-data) "approved") ERR-NOT-AUTHORIZED)
    (asserts! (>= block-height (get start-period budget-data)) ERR-INVALID-PERIOD)

    (map-set budgets
      { budget-id: budget-id }
      (merge budget-data { status: "active" })
    )

    (ok true)
  )
)

(define-public (close-budget (budget-id uint))
  (let
    (
      (budget-data (unwrap! (get-budget budget-id) ERR-NOT-FOUND))
    )
    (asserts! (or
      (is-eq tx-sender (get creator budget-data))
      (is-eq tx-sender CONTRACT-OWNER)
    ) ERR-NOT-AUTHORIZED)
    (asserts! (or
      (is-eq (get status budget-data) "active")
      (>= block-height (get end-period budget-data))
    ) ERR-NOT-AUTHORIZED)

    (map-set budgets
      { budget-id: budget-id }
      (merge budget-data { status: "closed" })
    )

    (ok true)
  )
)

(define-public (set-budget-approver (approver principal) (can-approve bool) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set budget-approvers
      { approver: approver }
      { can-approve: can-approve, max-approval-amount: max-amount }
    )

    (ok true)
  )
)

(define-public (update-budget-category (budget-id uint) (category-id uint) (allocated-amount uint) (priority uint))
  (let
    (
      (budget-data (unwrap! (get-budget budget-id) ERR-NOT-FOUND))
      (category-data (unwrap! (get-budget-category budget-id category-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator budget-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status budget-data) "draft") ERR-NOT-AUTHORIZED)
    (asserts! (> allocated-amount u0) ERR-INVALID-INPUT)
    (asserts! (<= priority u10) ERR-INVALID-INPUT)

    (map-set budget-categories
      { budget-id: budget-id, category-id: category-id }
      (merge category-data {
        allocated-amount: allocated-amount,
        priority: priority
      })
    )

    (ok true)
  )
)
