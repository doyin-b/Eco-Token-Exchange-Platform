;; Eco Token Exchange Platform
;; Enables the issuance, verification, and trading of environmental tokens
;; Supports initiative registration, validation, and transparent exchange

;; Define SIP-010 fungible token trait locally instead of importing
;; This avoids dependency on external contracts during development
(define-trait sip-010-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 256))) (response bool uint))

    ;; Get the token balance of a specified principal
    (get-balance (principal) (response uint uint))

    ;; Get the total supply for the token
    (get-total-supply () (response uint uint))

    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))

    ;; Get the token symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the number of decimals used
    (get-decimals () (response uint uint))

    ;; Get the URI for token metadata
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Initiative categories
(define-data-var initiative-categories (list 10 (string-ascii 64)) 
  (list 
    "renewable-energy" 
    "reforestation" 
    "methane-capture" 
    "energy-efficiency" 
    "carbon-capture"
  )
)

;; Environmental initiatives
(define-map eco-initiatives
  { initiative-id: uint }
  {
    title: (string-utf8 128),
    details: (string-utf8 1024),
    region: (string-utf8 128),
    manager: principal,
    category: (string-ascii 64),
    launch-date: uint,
    completion-date: uint,
    total-tokens: uint,
    available-tokens: uint,
    retired-tokens: uint,
    validated: bool,
    validation-data: (optional (buff 256)),
    state: (string-ascii 32),  ;; active, completed, suspended
    registry-link: (string-utf8 256),
    registered-at: uint
  }
)

;; Initiative validations
(define-map initiative-validations
  { initiative-id: uint, validation-id: uint }
  {
    validator: principal,
    timestamp: uint,
    tokens-issued: uint,
    report-link: (string-utf8 256),
    approach: (string-ascii 64),
    validation-start: uint,
    validation-end: uint
  }
)

;; Token lots
(define-map token-lots
  { lot-id: uint }
  {
    initiative-id: uint,
    vintage: uint,
    amount: uint,
    available: uint,
    unit-price: uint,
    minted-at: uint,
    lot-state: (string-ascii 32)  ;; available, sold, retired
  }
)

;; User token holdings
(define-map token-holdings
  { holder: principal, vintage: uint, initiative-id: uint }
  { balance: uint }
)

;; Withdrawn tokens
(define-map withdrawn-tokens
  { withdrawal-id: uint }
  {
    holder: principal,
    initiative-id: uint,
    lot-id: uint,
    amount: uint,
    withdrawal-purpose: (string-utf8 256),
    recipient: (optional principal),
    timestamp: uint,
    certificate-link: (optional (string-utf8 256))
  }
)

;; Approved validators
(define-map approved-validators
  { validator: principal }
  {
    organization: (string-utf8 128),
    qualifications: (string-utf8 256),
    approved-at: uint,
    approved-by: principal,
    validator-state: (string-ascii 32)
  }
)

;; Next available IDs
(define-data-var next-initiative-id uint u0)
(define-data-var next-lot-id uint u0)
(define-data-var next-withdrawal-id uint u0)
(define-map next-validation-id { initiative-id: uint } { id: uint })

;; Check if initiative category is valid
(define-private (is-valid-initiative-category (category (string-ascii 64)))
  (contains category (var-get initiative-categories))
)

;; Helper function to check if a list contains a value
(define-private (contains (value (string-ascii 64)) (my-list (list 10 (string-ascii 64))))
  (is-some (index-of my-list value))
)

;; Input validation helpers
(define-private (is-valid-initiative-id (initiative-id uint))
  (is-some (map-get? eco-initiatives { initiative-id: initiative-id }))
)

(define-private (is-valid-lot-id (lot-id uint))
  (is-some (map-get? token-lots { lot-id: lot-id }))
)

(define-private (is-valid-withdrawal-id (withdrawal-id uint))
  (is-some (map-get? withdrawn-tokens { withdrawal-id: withdrawal-id }))
)

(define-private (validate-string-input (input (string-utf8 1024)) (min-len uint) (max-len uint))
  (and (>= (len input) min-len) (<= (len input) max-len))
)

(define-private (validate-ascii-input (input (string-ascii 64)) (min-len uint) (max-len uint))
  (and (>= (len input) min-len) (<= (len input) max-len))
)

(define-private (validate-url-input (input (string-utf8 256)))
  (and (> (len input) u0) (<= (len input) u256))
)

;; Register a new environmental initiative
(define-public (register-initiative
                (title (string-utf8 128))
                (details (string-utf8 1024))
                (region (string-utf8 128))
                (category (string-ascii 64))
                (launch-date uint)
                (completion-date uint)
                (registry-link (string-utf8 256)))
  (let
    ((initiative-id (var-get next-initiative-id)))
    
    ;; Validate inputs
    (asserts! (validate-string-input title u1 u128) (err u"Invalid title length"))
    (asserts! (validate-string-input details u1 u1024) (err u"Invalid details length"))
    (asserts! (validate-string-input region u1 u128) (err u"Invalid region length"))
    (asserts! (validate-ascii-input category u1 u64) (err u"Invalid category length"))
    (asserts! (validate-url-input registry-link) (err u"Invalid registry link"))
    (asserts! (is-valid-initiative-category category) (err u"Invalid initiative category"))
    (asserts! (< launch-date completion-date) (err u"End date must be after launch date"))
    (asserts! (> launch-date block-height) (err u"Launch date must be in the future"))
    
    ;; Create the initiative record
    (map-set eco-initiatives
      { initiative-id: initiative-id }
      {
        title: title,
        details: details,
        region: region,
        manager: tx-sender,
        category: category,
        launch-date: launch-date,
        completion-date: completion-date,
        total-tokens: u0,
        available-tokens: u0,
        retired-tokens: u0,
        validated: false,
        validation-data: none,
        state: "pending",
        registry-link: registry-link,
        registered-at: block-height
      }
    )
    
    ;; Initialize validation counter
    (map-set next-validation-id
      { initiative-id: initiative-id }
      { id: u0 }
    )
    
    ;; Increment initiative ID counter
    (var-set next-initiative-id (+ initiative-id u1))
    
    (ok initiative-id)
  )
)

;; Validate an initiative and issue environmental tokens
(define-public (validate-initiative
                (initiative-id uint)
                (tokens-issued uint)
                (report-link (string-utf8 256))
                (approach (string-ascii 64))
                (validation-start uint)
                (validation-end uint)
                (validation-data (buff 256)))
  (let
    ((initiative (unwrap! (map-get? eco-initiatives { initiative-id: initiative-id }) (err u"Initiative not found")))
     (validation-counter (unwrap! (map-get? next-validation-id { initiative-id: initiative-id }) 
                                   (err u"Counter not found")))
     (validation-id (get id validation-counter)))
    
    ;; Validate inputs
    (asserts! (is-valid-initiative-id initiative-id) (err u"Invalid initiative ID"))
    (asserts! (validate-url-input report-link) (err u"Invalid report link"))
    (asserts! (validate-ascii-input approach u1 u64) (err u"Invalid approach length"))
    (asserts! (is-approved-validator tx-sender) (err u"Not approved as validator"))
    (asserts! (is-eq (get state initiative) "pending") (err u"Initiative not in pending state"))
    (asserts! (<= validation-start validation-end) (err u"Invalid validation period"))
    (asserts! (> tokens-issued u0) (err u"Tokens issued must be greater than zero"))
    (asserts! (<= tokens-issued u1000000000) (err u"Tokens issued exceeds maximum limit"))
    (asserts! (> (len validation-data) u0) (err u"Validation data cannot be empty"))
    
    ;; Create validation record
    (map-set initiative-validations
      { initiative-id: initiative-id, validation-id: validation-id }
      {
        validator: tx-sender,
        timestamp: block-height,
        tokens-issued: tokens-issued,
        report-link: report-link,
        approach: approach,
        validation-start: validation-start,
        validation-end: validation-end
      }
    )
    
    ;; Update initiative with validation data
    (map-set eco-initiatives
      { initiative-id: initiative-id }
      (merge initiative 
        { 
          validated: true, 
          validation-data: (some validation-data),
          state: "active",
          total-tokens: (+ (get total-tokens initiative) tokens-issued),
          available-tokens: (+ (get available-tokens initiative) tokens-issued)
        }
      )
    )
    
    ;; Increment validation counter
    (map-set next-validation-id
      { initiative-id: initiative-id }
      { id: (+ validation-id u1) }
    )
    
    (ok validation-id)
  )
)

;; Check if sender is an approved validator
(define-private (is-approved-validator (validator principal))
  (match (map-get? approved-validators { validator: validator })
    validator-data (and 
                    (is-eq (get validator-state validator-data) "active")
                    true)
    false
  )
)

;; Approve a validator (admin only)
(define-public (approve-validator 
                (validator principal)
                (organization (string-utf8 128))
                (qualifications (string-utf8 256)))
  (begin
    ;; Check if sender is admin
    (asserts! (is-admin) (err u"Only admin can approve validators"))
    
    ;; Validate inputs
    (asserts! (not (is-eq validator tx-sender)) (err u"Cannot approve yourself as validator"))
    (asserts! (validate-string-input organization u1 u128) (err u"Invalid organization length"))
    (asserts! (validate-string-input qualifications u1 u256) (err u"Invalid qualifications length"))
    
    ;; Register validator
    (map-set approved-validators
      { validator: validator }
      {
        organization: organization,
        qualifications: qualifications,
        approved-at: block-height,
        approved-by: tx-sender,
        validator-state: "active"
      }
    )
    
    (ok true)
  )
)

;; Admin check - would be implemented properly in a real contract
(define-private (is-admin)
  ;; Simplified check
  true
)

;; Create a lot of environmental tokens for sale
(define-public (create-token-lot
                (initiative-id uint)
                (vintage uint)
                (amount uint)
                (unit-price uint))
  (let
    ((initiative (unwrap! (map-get? eco-initiatives { initiative-id: initiative-id }) (err u"Initiative not found")))
     (lot-id (var-get next-lot-id)))
    
    ;; Validate inputs
    (asserts! (is-valid-initiative-id initiative-id) (err u"Invalid initiative ID"))
    (asserts! (is-eq tx-sender (get manager initiative)) (err u"Only initiative manager can create lots"))
    (asserts! (get validated initiative) (err u"Initiative must be validated first"))
    (asserts! (is-eq (get state initiative) "active") (err u"Initiative must be active"))
    (asserts! (>= (get available-tokens initiative) amount) (err u"Not enough available tokens"))
    (asserts! (> amount u0) (err u"Amount must be greater than zero"))
    (asserts! (<= amount u1000000000) (err u"Amount exceeds maximum limit"))
    (asserts! (> unit-price u0) (err u"Price must be greater than zero"))
    (asserts! (<= unit-price u1000000000000) (err u"Price exceeds maximum limit"))
    (asserts! (>= vintage u2020) (err u"Vintage must be 2020 or later"))
    (asserts! (<= vintage u2100) (err u"Vintage cannot exceed year 2100"))
    
    ;; Create the lot
    (map-set token-lots
      { lot-id: lot-id }
      {
        initiative-id: initiative-id,
        vintage: vintage,
        amount: amount,
        available: amount,
        unit-price: unit-price,
        minted-at: block-height,
        lot-state: "available"
      }
    )
    
    ;; Update initiative available tokens
    (map-set eco-initiatives
      { initiative-id: initiative-id }
      (merge initiative { available-tokens: (- (get available-tokens initiative) amount) })
    )
    
    ;; Increment lot ID counter
    (var-set next-lot-id (+ lot-id u1))
    
    (ok lot-id)
  )
)

;; Buy environmental tokens from a lot
(define-public (buy-eco-tokens (lot-id uint) (amount uint))
  (let
    ((lot (unwrap! (map-get? token-lots { lot-id: lot-id }) (err u"Lot not found")))
     (initiative (unwrap! (map-get? eco-initiatives { initiative-id: (get initiative-id lot) }) 
                      (err u"Initiative not found")))
     (total-cost (* amount (get unit-price lot)))
     (holding-key { holder: tx-sender, vintage: (get vintage lot), initiative-id: (get initiative-id lot) })
     (current-holding (default-to { balance: u0 } (map-get? token-holdings holding-key))))
    
    ;; Validate inputs
    (asserts! (is-valid-lot-id lot-id) (err u"Invalid lot ID"))
    (asserts! (> amount u0) (err u"Amount must be greater than zero"))
    (asserts! (<= amount u1000000000) (err u"Amount exceeds maximum limit"))
    (asserts! (is-eq (get lot-state lot) "available") (err u"Lot not available"))
    (asserts! (>= (get available lot) amount) (err u"Not enough tokens available in lot"))
    
    ;; Transfer STX for purchase - use asserts! instead of try!
    (asserts! (is-ok (stx-transfer? total-cost tx-sender (get manager initiative))) 
              (err u"STX transfer failed"))
    
    ;; Update lot available tokens
    (map-set token-lots
      { lot-id: lot-id }
      (merge lot 
        { 
          available: (- (get available lot) amount),
          lot-state: (if (is-eq (- (get available lot) amount) u0) "sold" "available")
        }
      )
    )
    
    ;; Update buyer's token holding
    (map-set token-holdings
      holding-key
      { balance: (+ (get balance current-holding) amount) }
    )
    
    (ok true)
  )
)

;; Withdraw environmental tokens
(define-public (withdraw-tokens 
                (initiative-id uint) 
                (vintage uint) 
                (amount uint)
                (withdrawal-purpose (string-utf8 256))
                (recipient (optional principal)))
  (let
    ((holding-key { holder: tx-sender, vintage: vintage, initiative-id: initiative-id })
     (current-holding (unwrap! (map-get? token-holdings holding-key) (err u"No tokens owned")))
     (initiative (unwrap! (map-get? eco-initiatives { initiative-id: initiative-id }) (err u"Initiative not found")))
     (withdrawal-id (var-get next-withdrawal-id)))
    
    ;; Validate inputs
    (asserts! (is-valid-initiative-id initiative-id) (err u"Invalid initiative ID"))
    (asserts! (> amount u0) (err u"Amount must be greater than zero"))
    (asserts! (<= amount u1000000000) (err u"Amount exceeds maximum limit"))
    (asserts! (validate-string-input withdrawal-purpose u1 u256) (err u"Invalid withdrawal purpose"))
    (asserts! (>= vintage u2020) (err u"Invalid vintage year"))
    (asserts! (>= (get balance current-holding) amount) (err u"Not enough tokens to withdraw"))
    
    ;; Validate recipient if present
    (asserts! (match recipient
                recipient-principal (not (is-eq recipient-principal tx-sender))
                true) 
              (err u"Recipient cannot be the same as the sender"))
    
    ;; Update user's holding
    (map-set token-holdings
      holding-key
      { balance: (- (get balance current-holding) amount) }
    )
    
    ;; Update initiative withdrawn tokens
    (map-set eco-initiatives
      { initiative-id: initiative-id }
      (merge initiative { retired-tokens: (+ (get retired-tokens initiative) amount) })
    )
    
    ;; Record withdrawal
    (map-set withdrawn-tokens
      { withdrawal-id: withdrawal-id }
      {
        holder: tx-sender,
        initiative-id: initiative-id,
        lot-id: u0, ;; Not tracking specific lot in this simplified version
        amount: amount,
        withdrawal-purpose: withdrawal-purpose,
        recipient: recipient,
        timestamp: block-height,
        certificate-link: none
      }
    )
    
    ;; Increment withdrawal ID counter
    (var-set next-withdrawal-id (+ withdrawal-id u1))
    
    (ok withdrawal-id)
  )
)

;; Transfer tokens to another user
(define-public (transfer-tokens
                (initiative-id uint)
                (vintage uint)
                (recipient principal)
                (amount uint))
  (let
    ((sender-key { holder: tx-sender, vintage: vintage, initiative-id: initiative-id })
     (recipient-key { holder: recipient, vintage: vintage, initiative-id: initiative-id })
     (sender-holding (unwrap! (map-get? token-holdings sender-key) (err u"No tokens owned")))
     (recipient-holding (default-to { balance: u0 } (map-get? token-holdings recipient-key))))
    
    ;; Validate inputs
    (asserts! (is-valid-initiative-id initiative-id) (err u"Invalid initiative ID"))
    (asserts! (> amount u0) (err u"Amount must be greater than zero"))
    (asserts! (<= amount u1000000000) (err u"Amount exceeds maximum limit"))
    (asserts! (>= vintage u2020) (err u"Invalid vintage year"))
    (asserts! (not (is-eq recipient tx-sender)) (err u"Cannot transfer to yourself"))
    (asserts! (>= (get balance sender-holding) amount) (err u"Not enough tokens to transfer"))
    
    ;; Update sender's holding
    (map-set token-holdings
      sender-key
      { balance: (- (get balance sender-holding) amount) }
    )
    
    ;; Update recipient's holding
    (map-set token-holdings
      recipient-key
      { balance: (+ (get balance recipient-holding) amount) }
    )
    
    (ok true)
  )
)

;; Generate withdrawal certificate (admin only)
(define-public (generate-withdrawal-certificate
                (withdrawal-id uint)
                (certificate-link (string-utf8 256)))
  (let
    ((withdrawal (unwrap! (map-get? withdrawn-tokens { withdrawal-id: withdrawal-id }) 
                         (err u"Withdrawal record not found"))))
    
    ;; Validate inputs
    (asserts! (is-valid-withdrawal-id withdrawal-id) (err u"Invalid withdrawal ID"))
    (asserts! (validate-url-input certificate-link) (err u"Invalid certificate link"))
    (asserts! (is-admin) (err u"Only admin can generate certificates"))
    (asserts! (is-none (get certificate-link withdrawal)) (err u"Certificate already generated"))
    
    ;; Update withdrawal record
    (map-set withdrawn-tokens
      { withdrawal-id: withdrawal-id }
      (merge withdrawal { certificate-link: (some certificate-link) })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get initiative details
(define-read-only (get-initiative-details (initiative-id uint))
  (ok (unwrap! (map-get? eco-initiatives { initiative-id: initiative-id }) (err u"Initiative not found")))
)

;; Get lot details
(define-read-only (get-lot-details (lot-id uint))
  (ok (unwrap! (map-get? token-lots { lot-id: lot-id }) (err u"Lot not found")))
)

;; Get user token holding
(define-read-only (get-token-holding (holder principal) (initiative-id uint) (vintage uint))
  (ok (default-to 
        { balance: u0 } 
        (map-get? token-holdings { holder: holder, vintage: vintage, initiative-id: initiative-id })
      )
  )
)

;; Get withdrawal details
(define-read-only (get-withdrawal-details (withdrawal-id uint))
  (ok (unwrap! (map-get? withdrawn-tokens { withdrawal-id: withdrawal-id }) (err u"Withdrawal not found")))
)