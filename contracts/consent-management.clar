;; Consent Management Contract
;; Tracks approvals for data sharing

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map consents
  { consent-id: (string-ascii 36) }
  {
    patient-id: (string-ascii 36),
    provider-id: (string-ascii 36),
    purpose: (string-ascii 200),
    granted-by: principal,
    granted-at: uint,
    expires-at: uint,
    revoked: bool
  }
)

;; Define patient-consents map for easier lookup
(define-map patient-consents
  { patient-id: (string-ascii 36), consent-id: (string-ascii 36) }
  { exists: bool }
)

;; Define error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_EXPIRED (err u103))
(define-constant ERR_REVOKED (err u104))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Grant consent
(define-public (grant-consent
    (consent-id (string-ascii 36))
    (patient-id (string-ascii 36))
    (provider-id (string-ascii 36))
    (purpose (string-ascii 200))
    (expires-at uint)
  )
  (let (
    (existing-consent (map-get? consents { consent-id: consent-id }))
  )
    (asserts! (is-none existing-consent) ERR_ALREADY_EXISTS)
    (asserts! (> expires-at block-height) ERR_EXPIRED)

    (map-set consents
      { consent-id: consent-id }
      {
        patient-id: patient-id,
        provider-id: provider-id,
        purpose: purpose,
        granted-by: tx-sender,
        granted-at: block-height,
        expires-at: expires-at,
        revoked: false
      }
    )

    ;; Add to patient-consents map for lookup
    (map-set patient-consents
      { patient-id: patient-id, consent-id: consent-id }
      { exists: true }
    )

    (ok true)
  )
)

;; Get consent information
(define-read-only (get-consent (consent-id (string-ascii 36)))
  (map-get? consents { consent-id: consent-id })
)

;; Check if a consent belongs to a patient
(define-read-only (is-patient-consent (patient-id (string-ascii 36)) (consent-id (string-ascii 36)))
  (default-to false (get exists (map-get? patient-consents { patient-id: patient-id, consent-id: consent-id })))
)

;; Verify consent validity
(define-read-only (verify-consent (consent-id (string-ascii 36)))
  (let (
    (consent (map-get? consents { consent-id: consent-id }))
  )
    (match consent
      consent-data (and
                     (not (get revoked consent-data))
                     (>= (get expires-at consent-data) block-height)
                   )
      false
    )
  )
)

;; Revoke consent
(define-public (revoke-consent (consent-id (string-ascii 36)))
  (let (
    (existing-consent (unwrap! (map-get? consents { consent-id: consent-id }) ERR_NOT_FOUND))
  )
    (asserts! (or
                (is-admin)
                (is-eq tx-sender (get granted-by existing-consent))
              )
              ERR_UNAUTHORIZED)

    (map-set consents
      { consent-id: consent-id }
      (merge existing-consent { revoked: true })
    )
    (ok true)
  )
)

;; Extend consent expiration
(define-public (extend-consent (consent-id (string-ascii 36)) (new-expiry uint))
  (let (
    (existing-consent (unwrap! (map-get? consents { consent-id: consent-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get granted-by existing-consent)) ERR_UNAUTHORIZED)
    (asserts! (not (get revoked existing-consent)) ERR_REVOKED)
    (asserts! (> new-expiry block-height) ERR_EXPIRED)
    (asserts! (> new-expiry (get expires-at existing-consent)) ERR_EXPIRED)

    (map-set consents
      { consent-id: consent-id }
      (merge existing-consent { expires-at: new-expiry })
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
