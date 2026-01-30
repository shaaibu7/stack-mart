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