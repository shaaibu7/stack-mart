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