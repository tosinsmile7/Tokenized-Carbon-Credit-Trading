;; Project Verification Contract
;; Validates carbon reduction initiatives

(define-data-var admin principal tx-sender)

;; Project status: 0 = pending, 1 = verified, 2 = rejected
(define-map projects
  { project-id: uint }
  {
    owner: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    location: (string-utf8 100),
    methodology: (string-utf8 100),
    status: uint,
    verification-date: uint,
    verified-by: principal
  }
)

(define-map verifiers
  { verifier: principal }
  { is-authorized: bool }
)

(define-data-var next-project-id uint u1)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-PROJECT-NOT-FOUND u101)
(define-constant ERR-ALREADY-VERIFIED u102)

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set admin new-admin))
  )
)

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set verifiers { verifier: verifier } { is-authorized: true }))
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set verifiers { verifier: verifier } { is-authorized: false }))
  )
)

;; Project registration and verification
(define-public (register-project
    (name (string-utf8 100))
    (description (string-utf8 500))
    (location (string-utf8 100))
    (methodology (string-utf8 100)))
  (let
    ((project-id (var-get next-project-id)))
    (map-set projects
      { project-id: project-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        location: location,
        methodology: methodology,
        status: u0,
        verification-date: u0,
        verified-by: tx-sender
      }
    )
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-public (verify-project (project-id uint))
  (let
    ((project (unwrap! (map-get? projects { project-id: project-id }) (err ERR-PROJECT-NOT-FOUND)))
     (is-verifier (default-to { is-authorized: false } (map-get? verifiers { verifier: tx-sender }))))

    ;; Check if caller is authorized verifier
    (asserts! (get is-authorized is-verifier) (err ERR-NOT-AUTHORIZED))

    ;; Check if project is not already verified
    (asserts! (is-eq (get status project) u0) (err ERR-ALREADY-VERIFIED))

    ;; Update project status to verified
    (ok (map-set projects
      { project-id: project-id }
      (merge project {
        status: u1,
        verification-date: block-height,
        verified-by: tx-sender
      })
    ))
  )
)

(define-public (reject-project (project-id uint))
  (let
    ((project (unwrap! (map-get? projects { project-id: project-id }) (err ERR-PROJECT-NOT-FOUND)))
     (is-verifier (default-to { is-authorized: false } (map-get? verifiers { verifier: tx-sender }))))

    ;; Check if caller is authorized verifier
    (asserts! (get is-authorized is-verifier) (err ERR-NOT-AUTHORIZED))

    ;; Check if project is not already verified or rejected
    (asserts! (is-eq (get status project) u0) (err ERR-ALREADY-VERIFIED))

    ;; Update project status to rejected
    (ok (map-set projects
      { project-id: project-id }
      (merge project {
        status: u2,
        verification-date: block-height,
        verified-by: tx-sender
      })
    ))
  )
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (is-project-verified (project-id uint))
  (let ((project (default-to
          { status: u0 }
          (map-get? projects { project-id: project-id }))))
    (is-eq (get status project) u1))
)

(define-read-only (is-verifier (address principal))
  (default-to
    false
    (get is-authorized (map-get? verifiers { verifier: address })))
)
