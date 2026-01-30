;; SIP-090 Non-Fungible Token Standard Implementation
;; StackMart NFT Contract
;; 
;; This contract implements a fully compliant SIP-090 non-fungible token
;; with comprehensive features for minting, transferring, and managing NFTs.

;; ============================================================================
;; CONSTANTS AND CONFIGURATION
;; ============================================================================

;; Contract metadata constants
(define-constant CONTRACT-NAME "StackMart NFT")
(define-constant CONTRACT-SYMBOL "SMNFT")
(define-constant CONTRACT-BASE-URI "https://api.stackmart.io/nft/")

;; Maximum supply limit
(define-constant MAX-SUPPLY u10000)

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Error constants following SIP-090 standards
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-OWNER (err u403))
(define-constant ERR-CONTRACT-PAUSED (err u503))
(define-constant ERR-INVALID-PARAMETERS (err u400))
(define-constant ERR-MAX-SUPPLY-REACHED (err u429))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-RECIPIENT (err u422))

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Map to track token ownership
(define-map token-owners uint principal)

;; Map to track token metadata URIs
(define-map token-uris uint (string-ascii 256))

;; Map to track tokens owned by each principal
(define-map owner-tokens principal (list 500 uint))

;; Contract state variables
(define-data-var total-supply uint u0)
(define-data-var next-token-id uint u1)
(define-data-var base-uri (string-ascii 256) CONTRACT-BASE-URI)
(define-data-var contract-paused bool false)

;; ============================================================================
;; SIP-090 STANDARD INTERFACE FUNCTIONS
;; ============================================================================

;; Get the last token ID that was minted
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

;; Get total supply of minted tokens
(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

;; Get token URI for metadata
(define-read-only (get-token-uri (token-id uint))
  (match (map-get? token-uris token-id)
    uri (ok (some uri))
    (if (is-some (map-get? token-owners token-id))
      ;; Token exists but no specific URI, use base URI + token ID
      (ok (some (concat (var-get base-uri) (uint-to-ascii token-id))))
      ;; Token doesn't exist
      ERR-NOT-FOUND)))

;; Helper function to convert uint to ascii
(define-private (uint-to-ascii (value uint))
  (if (is-eq value u0)
    "0"
    (uint-to-ascii-helper value "")))

(define-private (uint-to-ascii-helper (value uint) (result (string-ascii 10)))
  (if (is-eq value u0)
    result
    (uint-to-ascii-helper 
      (/ value u10) 
      (concat (unwrap-panic (element-at "0123456789" (mod value u10))) result))))
;; Get owner of a specific token
(define-read-only (get-owner (token-id uint))
  (match (map-get? token-owners token-id)
    owner (ok (some owner))
    ERR-NOT-FOUND))

;; Get contract information
(define-read-only (get-contract-info)
  (ok {
    name: CONTRACT-NAME,
    symbol: CONTRACT-SYMBOL,
    base-uri: (var-get base-uri),
    total-supply: (var-get total-supply),
    max-supply: MAX-SUPPLY
  }))
;; ============================================================================
;; MINTING FUNCTIONS
;; ============================================================================

;; Mint a new NFT to a recipient
(define-public (mint (recipient principal) (metadata-uri (optional (string-ascii 256))))
  (let ((token-id (var-get next-token-id))
        (current-supply (var-get total-supply)))
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    ;; Check if max supply reached
    (asserts! (< current-supply MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
    ;; Check if caller is authorized (contract owner for now)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    ;; Check if token already exists (shouldn't happen with proper ID generation)
    (asserts! (is-none (map-get? token-owners token-id)) ERR-ALREADY-EXISTS)
    
    ;; Set token owner
    (map-set token-owners token-id recipient)
    
    ;; Set metadata URI if provided
    (match metadata-uri
      uri (map-set token-uris token-id uri)
      true)
    
    ;; Update owner's token list
    (let ((current-tokens (default-to (list) (map-get? owner-tokens recipient))))
      (map-set owner-tokens recipient (unwrap! (as-max-len? (append current-tokens token-id) u500) ERR-INVALID-PARAMETERS)))
    
    ;; Update counters
    (var-set next-token-id (+ token-id u1))
    (var-set total-supply (+ current-supply u1))
    
    ;; Emit mint event
    (print {
      type: "nft_mint_event",
      token-contract: (as-contract tx-sender),
      token-id: token-id,
      recipient: recipient,
      metadata-uri: metadata-uri
    })
    
    (ok token-id)))
;; ============================================================================
;; TRANSFER FUNCTIONS
;; ============================================================================

;; Transfer NFT from sender to recipient (SIP-090 standard)
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((current-owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
    ;; Check if contract is paused
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    ;; Check if sender is the actual owner
    (asserts! (is-eq sender current-owner) ERR-INVALID-OWNER)
    ;; Check if caller is authorized (must be the owner)
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    ;; Check for valid recipient
    (asserts! (not (is-eq sender recipient)) ERR-INVALID-PARAMETERS)
    
    ;; Update token ownership
    (map-set token-owners token-id recipient)
    
    ;; Update sender's token list
    (let ((sender-tokens (default-to (list) (map-get? owner-tokens sender))))
      (map-set owner-tokens sender (filter-token-from-list sender-tokens token-id)))
    
    ;; Update recipient's token list
    (let ((recipient-tokens (default-to (list) (map-get? owner-tokens recipient))))
      (map-set owner-tokens recipient (unwrap! (as-max-len? (append recipient-tokens token-id) u500) ERR-INVALID-PARAMETERS)))
    
    ;; Emit transfer event
    (print {
      type: "nft_transfer_event",
      token-contract: (as-contract tx-sender),
      token-id: token-id,
      sender: sender,
      recipient: recipient
    })
    
    (ok true)))

;; Helper function to remove token from owner's list
(define-private (filter-token-from-list (token-list (list 500 uint)) (token-to-remove uint))
  (filter is-not-target-token token-list))

(define-private (is-not-target-token (token-id uint))
  (not (is-eq token-id token-to-remove)))

;; We need to define token-to-remove as a data variable for the filter to work
(define-data-var token-to-remove uint u0)

;; Updated helper function using data variable
(define-private (filter-token-from-list-v2 (token-list (list 500 uint)) (token-to-remove uint))
  (begin
    (var-set token-to-remove token-to-remove)
    (filter is-not-target-token-v2 token-list)))

(define-private (is-not-target-token-v2 (token-id uint))
  (not (is-eq token-id (var-get token-to-remove))))
;; ============================================================================
;; VALIDATION FUNCTIONS
;; ============================================================================

;; Validate token ID exists
(define-private (validate-token-exists (token-id uint))
  (asserts! (is-some (map-get? token-owners token-id)) ERR-NOT-FOUND)
  (ok true))

;; Validate principal is not contract address
(define-private (validate-principal (principal-to-check principal))
  (asserts! (not (is-eq principal-to-check (as-contract tx-sender))) ERR-INVALID-RECIPIENT)
  (ok true))

;; Validate token ownership
(define-private (validate-ownership (token-id uint) (claimed-owner principal))
  (let ((actual-owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
    (asserts! (is-eq actual-owner claimed-owner) ERR-INVALID-OWNER)
    (ok true)))

;; Validate contract is not paused
(define-private (validate-not-paused)
  (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
  (ok true))

;; Validate caller authorization for token operations
(define-private (validate-caller-authorization (token-id uint))
  (let ((token-owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-AUTHORIZED)
    (ok true)))

;; Validate admin authorization
(define-private (validate-admin-authorization)
  (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
  (ok true))
;; ============================================================================
;; ADMINISTRATIVE FUNCTIONS
;; ============================================================================

;; Update base URI for metadata (owner only)
(define-public (set-base-uri (new-base-uri (string-ascii 256)))
  (begin
    (try! (validate-admin-authorization))
    (var-set base-uri new-base-uri)
    (print {
      type: "base_uri_updated",
      old-uri: (var-get base-uri),
      new-uri: new-base-uri
    })
    (ok true)))

;; Set custom metadata URI for specific token (owner only)
(define-public (set-token-uri (token-id uint) (metadata-uri (string-ascii 256)))
  (begin
    (try! (validate-admin-authorization))
    (try! (validate-token-exists token-id))
    (map-set token-uris token-id metadata-uri)
    (print {
      type: "token_uri_updated",
      token-id: token-id,
      new-uri: metadata-uri
    })
    (ok true)))

;; Get tokens owned by a specific principal
(define-read-only (get-tokens-by-owner (owner principal))
  (ok (default-to (list) (map-get? owner-tokens owner))))

;; Check if a principal owns a specific token
(define-read-only (is-token-owner (token-id uint) (principal-to-check principal))
  (match (map-get? token-owners token-id)
    owner (ok (is-eq owner principal-to-check))
    (ok false)))
;; ============================================================================
;; PAUSE/UNPAUSE FUNCTIONALITY
;; ============================================================================

;; Pause the contract (owner only)
(define-public (pause-contract)
  (begin
    (try! (validate-admin-authorization))
    (var-set contract-paused true)
    (print {
      type: "contract_paused",
      paused-by: tx-sender,
      timestamp: burn-block-height
    })
    (ok true)))

;; Unpause the contract (owner only)
(define-public (unpause-contract)
  (begin
    (try! (validate-admin-authorization))
    (var-set contract-paused false)
    (print {
      type: "contract_unpaused",
      unpaused-by: tx-sender,
      timestamp: burn-block-height
    })
    (ok true)))

;; Check if contract is paused
(define-read-only (is-paused)
  (ok (var-get contract-paused)))

;; Get contract status
(define-read-only (get-contract-status)
  (ok {
    paused: (var-get contract-paused),
    owner: CONTRACT-OWNER,
    total-supply: (var-get total-supply),
    max-supply: MAX-SUPPLY,
    next-token-id: (var-get next-token-id)
  }))
;; ============================================================================
;; BATCH OPERATIONS
;; ============================================================================

;; Batch mint multiple NFTs to recipients
(define-public (batch-mint (recipients (list 50 principal)) (metadata-uris (list 50 (optional (string-ascii 256)))))
  (let ((recipients-count (len recipients))
        (uris-count (len metadata-uris)))
    ;; Validate inputs
    (asserts! (> recipients-count u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-eq recipients-count uris-count) ERR-INVALID-PARAMETERS)
    (try! (validate-admin-authorization))
    (try! (validate-not-paused))
    
    ;; Check if we have enough supply left
    (let ((current-supply (var-get total-supply)))
      (asserts! (<= (+ current-supply recipients-count) MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED))
    
    ;; Process batch mint
    (fold batch-mint-helper (zip recipients metadata-uris) (ok (list)))
    ))

;; Helper function for batch minting
(define-private (batch-mint-helper 
  (recipient-data {recipient: principal, metadata-uri: (optional (string-ascii 256))}) 
  (previous-result (response (list 50 uint) uint)))
  (match previous-result
    success-list 
      (match (mint (get recipient recipient-data) (get metadata-uri recipient-data))
        token-id (ok (unwrap! (as-max-len? (append success-list token-id) u50) ERR-INVALID-PARAMETERS))
        error (err error))
    error (err error)))

;; Zip two lists together for batch operations
(define-private (zip (list-a (list 50 principal)) (list-b (list 50 (optional (string-ascii 256)))))
  (map create-pair-from-index (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49)))

;; Helper to create pairs from index
(define-private (create-pair-from-index (index uint))
  {
    recipient: (unwrap-panic (element-at recipients-list index)),
    metadata-uri: (unwrap-panic (element-at uris-list index))
  })

;; We need data variables for the zip operation
(define-data-var recipients-list (list 50 principal) (list))
(define-data-var uris-list (list 50 (optional (string-ascii 256))) (list))
;; ============================================================================
;; ADDITIONAL QUERY FUNCTIONS
;; ============================================================================

;; Get token count owned by a principal
(define-read-only (get-token-count-by-owner (owner principal))
  (ok (len (default-to (list) (map-get? owner-tokens owner)))))

;; Check if token exists
(define-read-only (token-exists (token-id uint))
  (ok (is-some (map-get? token-owners token-id))))

;; Get all contract metadata in one call
(define-read-only (get-all-metadata)
  (ok {
    name: CONTRACT-NAME,
    symbol: CONTRACT-SYMBOL,
    base-uri: (var-get base-uri),
    total-supply: (var-get total-supply),
    max-supply: MAX-SUPPLY,
    next-token-id: (var-get next-token-id),
    paused: (var-get contract-paused),
    owner: CONTRACT-OWNER
  }))

;; Get token info (owner + URI)
(define-read-only (get-token-info (token-id uint))
  (match (map-get? token-owners token-id)
    owner (ok {
      token-id: token-id,
      owner: owner,
      metadata-uri: (match (map-get? token-uris token-id)
        uri (some uri)
        (some (concat (var-get base-uri) (uint-to-ascii token-id))))
    })
    ERR-NOT-FOUND))

;; Get multiple token info at once
(define-read-only (get-tokens-info (token-ids (list 20 uint)))
  (ok (map get-single-token-info token-ids)))

(define-private (get-single-token-info (token-id uint))
  (match (map-get? token-owners token-id)
    owner {
      token-id: token-id,
      owner: (some owner),
      metadata-uri: (match (map-get? token-uris token-id)
        uri (some uri)
        (some (concat (var-get base-uri) (uint-to-ascii token-id))))
    }
    {
      token-id: token-id,
      owner: none,
      metadata-uri: none
    }))