;; Patient Identity Contract
;; Manages secure healthcare identifiers

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map patients
  { patient-id: (string-ascii 36) }
  {
    owner: principal,
    name: (string-ascii 100),
    dob: (string-ascii 10),
    active: bool,
    created-at: uint
  }
)

;; Define error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_FOUND (err u102))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new patient
(define-public (register-patient
    (patient-id (string-ascii 36))
    (name (string-ascii 100))
    (dob (string-ascii 10))
  )
  (let (
    (existing-patient (map-get? patients { patient-id: patient-id }))
  )
    (asserts! (is-none existing-patient) ERR_ALREADY_REGISTERED)

    (map-set patients
      { patient-id: patient-id }
      {
        owner: tx-sender,
        name: name,
        dob: dob,
        active: true,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Get patient information (public)
(define-read-only (get-patient (patient-id (string-ascii 36)))
  (map-get? patients { patient-id: patient-id })
)

;; Update patient information
(define-public (update-patient
    (patient-id (string-ascii 36))
    (name (string-ascii 100))
    (dob (string-ascii 10))
  )
  (let (
    (existing-patient (unwrap! (map-get? patients { patient-id: patient-id }) ERR_NOT_FOUND))
  )
    (asserts! (or (is-admin) (is-eq tx-sender (get owner existing-patient))) ERR_UNAUTHORIZED)

    (map-set patients
      { patient-id: patient-id }
      (merge existing-patient {
        name: name,
        dob: dob
      })
    )
    (ok true)
  )
)

;; Deactivate patient
(define-public (deactivate-patient (patient-id (string-ascii 36)))
  (let (
    (existing-patient (unwrap! (map-get? patients { patient-id: patient-id }) ERR_NOT_FOUND))
  )
    (asserts! (or (is-admin) (is-eq tx-sender (get owner existing-patient))) ERR_UNAUTHORIZED)

    (map-set patients
      { patient-id: patient-id }
      (merge existing-patient { active: false })
    )
    (ok true)
  )
)

;; Reactivate patient (admin only)
(define-public (reactivate-patient (patient-id (string-ascii 36)))
  (let (
    (existing-patient (unwrap! (map-get? patients { patient-id: patient-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-admin) ERR_UNAUTHORIZED)

    (map-set patients
      { patient-id: patient-id }
      (merge existing-patient { active: true })
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

