;; Treatment Authorization Contract
;; Manages approvals for procedures

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map authorizations
  { auth-id: (string-ascii 36) }
  {
    patient-id: (string-ascii 36),
    provider-id: (string-ascii 36),
    treatment-code: (string-ascii 20),
    description: (string-ascii 200),
    insurance-policy-id: (string-ascii 36),
    authorized-by: principal,
    authorized-at: uint,
    expires-at: uint,
    status: (string-ascii 20) ;; "pending", "approved", "denied", "completed"
  }
)

;; Define patient-authorizations map for easier lookup
(define-map patient-authorizations
  { patient-id: (string-ascii 36), auth-id: (string-ascii 36) }
  { exists: bool }
)

;; Define error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_EXPIRED (err u103))
(define-constant ERR_INVALID_STATUS (err u104))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Request treatment authorization
(define-public (request-authorization
    (auth-id (string-ascii 36))
    (patient-id (string-ascii 36))
    (provider-id (string-ascii 36))
    (treatment-code (string-ascii 20))
    (description (string-ascii 200))
    (insurance-policy-id (string-ascii 36))
    (expires-at uint)
  )
  (let (
    (existing-auth (map-get? authorizations { auth-id: auth-id }))
  )
    (asserts! (is-none existing-auth) ERR_ALREADY_EXISTS)
    (asserts! (> expires-at block-height) ERR_EXPIRED)

    (map-set authorizations
      { auth-id: auth-id }
      {
        patient-id: patient-id,
        provider-id: provider-id,
        treatment-code: treatment-code,
        description: description,
        insurance-policy-id: insurance-policy-id,
        authorized-by: tx-sender,
        authorized-at: block-height,
        expires-at: expires-at,
        status: "pending"
      }
    )

    ;; Add to patient-authorizations map for lookup
    (map-set patient-authorizations
      { patient-id: patient-id, auth-id: auth-id }
      { exists: true }
    )

    (ok true)
  )
)

;; Get authorization information
(define-read-only (get-authorization (auth-id (string-ascii 36)))
  (map-get? authorizations { auth-id: auth-id })
)

;; Check if an authorization belongs to a patient
(define-read-only (is-patient-authorization (patient-id (string-ascii 36)) (auth-id (string-ascii 36)))
  (default-to false (get exists (map-get? patient-authorizations { patient-id: patient-id, auth-id: auth-id })))
)

;; Update authorization status
(define-public (update-authorization-status
    (auth-id (string-ascii 36))
    (new-status (string-ascii 20))
  )
  (let (
    (existing-auth (unwrap! (map-get? authorizations { auth-id: auth-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (or
                (is-eq new-status "approved")
                (is-eq new-status "denied")
                (is-eq new-status "completed")
              )
              ERR_INVALID_STATUS)

    (map-set authorizations
      { auth-id: auth-id }
      (merge existing-auth { status: new-status })
    )
    (ok true)
  )
)

;; Verify authorization validity
(define-read-only (verify-authorization (auth-id (string-ascii 36)))
  (let (
    (auth (map-get? authorizations { auth-id: auth-id }))
  )
    (match auth
      auth-data (and
                  (is-eq (get status auth-data) "approved")
                  (>= (get expires-at auth-data) block-height)
                )
      false
    )
  )
)

;; Extend authorization expiration
(define-public (extend-authorization (auth-id (string-ascii 36)) (new-expiry uint))
  (let (
    (existing-auth (unwrap! (map-get? authorizations { auth-id: auth-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (> new-expiry block-height) ERR_EXPIRED)
    (asserts! (> new-expiry (get expires-at existing-auth)) ERR_EXPIRED)

    (map-set authorizations
      { auth-id: auth-id }
      (merge existing-auth { expires-at: new-expiry })
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

