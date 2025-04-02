;; Insurance Verification Contract
;; Validates coverage and eligibility

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map insurance-policies
  { policy-id: (string-ascii 36) }
  {
    patient-id: (string-ascii 36),
    provider: (string-ascii 100),
    policy-number: (string-ascii 50),
    coverage-start: uint,
    coverage-end: uint,
    active: bool
  }
)

;; Define patient-policies map for easier lookup
(define-map patient-policies
  { patient-id: (string-ascii 36), policy-id: (string-ascii 36) }
  { exists: bool }
)

;; Define error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_EXPIRED (err u103))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Add insurance policy
(define-public (add-insurance-policy
    (policy-id (string-ascii 36))
    (patient-id (string-ascii 36))
    (provider (string-ascii 100))
    (policy-number (string-ascii 50))
    (coverage-start uint)
    (coverage-end uint)
  )
  (let (
    (existing-policy (map-get? insurance-policies { policy-id: policy-id }))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (is-none existing-policy) ERR_ALREADY_EXISTS)
    (asserts! (< coverage-start coverage-end) ERR_EXPIRED)

    (map-set insurance-policies
      { policy-id: policy-id }
      {
        patient-id: patient-id,
        provider: provider,
        policy-number: policy-number,
        coverage-start: coverage-start,
        coverage-end: coverage-end,
        active: true
      }
    )

    ;; Add to patient-policies map for lookup
    (map-set patient-policies
      { patient-id: patient-id, policy-id: policy-id }
      { exists: true }
    )

    (ok true)
  )
)

;; Get insurance policy information
(define-read-only (get-insurance-policy (policy-id (string-ascii 36)))
  (map-get? insurance-policies { policy-id: policy-id })
)

;; Check if a policy belongs to a patient
(define-read-only (is-patient-policy (patient-id (string-ascii 36)) (policy-id (string-ascii 36)))
  (default-to false (get exists (map-get? patient-policies { patient-id: patient-id, policy-id: policy-id })))
)

;; Verify insurance coverage
(define-read-only (verify-coverage (policy-id (string-ascii 36)))
  (let (
    (policy (map-get? insurance-policies { policy-id: policy-id }))
  )
    (match policy
      policy-data (and
                    (get active policy-data)
                    (>= (get coverage-end policy-data) block-height)
                  )
      false
    )
  )
)

;; Update insurance policy
(define-public (update-insurance-policy
    (policy-id (string-ascii 36))
    (provider (string-ascii 100))
    (policy-number (string-ascii 50))
    (coverage-start uint)
    (coverage-end uint)
  )
  (let (
    (existing-policy (unwrap! (map-get? insurance-policies { policy-id: policy-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (< coverage-start coverage-end) ERR_EXPIRED)

    (map-set insurance-policies
      { policy-id: policy-id }
      (merge existing-policy {
        provider: provider,
        policy-number: policy-number,
        coverage-start: coverage-start,
        coverage-end: coverage-end
      })
    )
    (ok true)
  )
)

;; Deactivate insurance policy
(define-public (deactivate-policy (policy-id (string-ascii 36)))
  (let (
    (existing-policy (unwrap! (map-get? insurance-policies { policy-id: policy-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)

    (map-set insurance-policies
      { policy-id: policy-id }
      (merge existing-policy { active: false })
    )
    (ok true)
  )
)

;; Reactivate insurance policy
(define-public (reactivate-policy (policy-id (string-ascii 36)))
  (let (
    (existing-policy (unwrap! (map-get? insurance-policies { policy-id: policy-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)

    (map-set insurance-policies
      { policy-id: policy-id }
      (merge existing-policy { active: true })
    )
    (ok true)
  )
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

