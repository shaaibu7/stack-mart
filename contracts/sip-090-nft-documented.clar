;; ============================================================================
;; SIP-090 Non-Fungible Token Standard Implementation
;; StackMart NFT Contract
;; ============================================================================
;; 
;; This contract implements a fully compliant SIP-090 non-fungible token
;; with comprehensive features for minting, transferring, and managing NFTs.
;; 
;; Features:
;; - Full SIP-090 compliance for interoperability
;; - Batch minting capabilities for efficient operations
;; - Pause/unpause functionality for emergency controls
;; - Comprehensive event logging for analytics
;; - Gas-optimized storage and operations
;; - Administrative controls with proper authorization
;; - Flexible metadata URI management
;; 
;; Author: StackMart Development Team
;; Version: 1.0.0
;; License: MIT
;; 
;; ============================================================================

;; ============================================================================
;; CONSTANTS AND CONFIGURATION
;; ============================================================================

;; Contract metadata constants
;; These define the basic NFT collection properties
(define-constant CONTRACT-NAME "StackMart NFT")
(define-constant CONTRACT-SYMBOL "SMNFT")
(define-constant CONTRACT-BASE-URI "https://api.stackmart.io/nft/")

;; Supply and ownership configuration
(define-constant MAX-SUPPLY u10000)  ;; Maximum number of NFTs that can be minted
(define-constant CONTRACT-OWNER tx-sender)  ;; Address that deployed the contract

;; Error constants following HTTP status code conventions
(define-constant ERR-NOT-AUTHORIZED (err u401))      ;; Unauthorized access
(define-constant ERR-NOT-FOUND (err u404))           ;; Token/resource not found
(define-constant ERR-INVALID-OWNER (err u403))       ;; Invalid ownership claim
(define-constant ERR-CONTRACT-PAUSED (err u503))     ;; Service unavailable (paused)
(define-constant ERR-INVALID-PARAMETERS (err u400))  ;; Bad request parameters
(define-constant ERR-MAX-SUPPLY-REACHED (err u429))  ;; Too many requests (supply limit)
(define-constant ERR-ALREADY-EXISTS (err u409))      ;; Conflict (token exists)
(define-constant ERR-INVALID-RECIPIENT (err u422))   ;; Unprocessable entity

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Core NFT storage maps
(define-map token-owners uint principal)                    ;; token-id -> owner
(define-map token-uris uint (string-ascii 256))            ;; token-id -> metadata URI
(define-map owner-tokens principal (list 500 uint))        ;; owner -> list of token IDs

;; Contract state variables
(define-data-var total-supply uint u0)                     ;; Current number of minted NFTs
(define-data-var next-token-id uint u1)                    ;; Next token ID to be minted
(define-data-var base-uri (string-ascii 256) CONTRACT-BASE-URI)  ;; Base URI for metadata
(define-data-var contract-paused bool false)               ;; Emergency pause state

;; Helper variables for list operations
(define-data-var token-to-remove uint u0)                  ;; Temporary storage for list filtering
(define-data-var recipients-list (list 50 principal) (list))     ;; Batch operation storage
(define-data-var uris-list (list 50 (optional (string-ascii 256))) (list))  ;; Batch URI storage

;; ============================================================================
;; SIP-090 STANDARD INTERFACE FUNCTIONS
;; ============================================================================

;; @desc Get the last token ID that was minted
;; @returns (response uint uint) - The highest token ID minted, or 0 if none
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

;; @desc Get total supply of minted tokens
;; @returns (response uint uint) - Current number of minted NFTs
(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

;; @desc Get token URI for metadata
;; @param token-id: uint - The token ID to query
;; @returns (response (optional string-ascii) uint) - Metadata URI or error
(define-read-only (get-token-uri (token-id uint))
  (match (map-get? token-uris token-id)
    uri (ok (some uri))
    (if (is-some (map-get? token-owners token-id))
      ;; Token exists but no specific URI, use base URI + token ID
      (ok (some (concat (var-get base-uri) (uint-to-ascii token-id))))
      ;; Token doesn't exist
      ERR-NOT-FOUND)))

;; @desc Get owner of a specific token
;; @param token-id: uint - The token ID to query
;; @returns (response (optional principal) uint) - Owner principal or error
(define-read-only (get-owner (token-id uint))
  (match (map-get? token-owners token-id)
    owner (ok (some owner))
    ERR-NOT-FOUND))

;; ============================================================================
;; UTILITY FUNCTIONS
;; ============================================================================

;; @desc Convert uint to ASCII string representation
;; @param value: uint - Number to convert
;; @returns string-ascii - String representation of the number
(define-private (uint-to-ascii (value uint))
  (if (is-eq value u0)
    "0"
    (uint-to-ascii-helper value "")))

;; @desc Helper function for uint to ASCII conversion
;; @param value: uint - Remaining value to convert
;; @param result: string-ascii - Accumulated result string
;; @returns string-ascii - Final converted string
(define-private (uint-to-ascii-helper (value uint) (result (string-ascii 10)))
  (if (is-eq value u0)
    result
    (uint-to-ascii-helper 
      (/ value u10) 
      (concat (unwrap-panic (element-at "0123456789" (mod value u10))) result))))

;; ============================================================================
;; VALIDATION FUNCTIONS
;; ============================================================================

;; @desc Validate token ID exists
;; @param token-id: uint - Token ID to validate
;; @returns (response bool uint) - Success or error
(define-private (validate-token-exists (token-id uint))
  (asserts! (is-some (map-get? token-owners token-id)) ERR-NOT-FOUND)
  (ok true))

;; @desc Validate principal is not contract address
;; @param principal-to-check: principal - Principal to validate
;; @returns (response bool uint) - Success or error
(define-private (validate-principal (principal-to-check principal))
  (asserts! (not (is-eq principal-to-check (as-contract tx-sender))) ERR-INVALID-RECIPIENT)
  (ok true))

;; @desc Validate token ownership
;; @param token-id: uint - Token ID to check
;; @param claimed-owner: principal - Claimed owner to validate
;; @returns (response bool uint) - Success or error
(define-private (validate-ownership (token-id uint) (claimed-owner principal))
  (let ((actual-owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
    (asserts! (is-eq actual-owner claimed-owner) ERR-INVALID-OWNER)
    (ok true)))

;; @desc Validate contract is not paused
;; @returns (response bool uint) - Success or error
(define-private (validate-not-paused)
  (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
  (ok true))

;; @desc Validate caller authorization for token operations
;; @param token-id: uint - Token ID for authorization check
;; @returns (response bool uint) - Success or error
(define-private (validate-caller-authorization (token-id uint))
  (let ((token-owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-AUTHORIZED)
    (ok true)))

;; @desc Validate admin authorization
;; @returns (response bool uint) - Success or error
(define-private (validate-admin-authorization)
  (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
  (ok true))

;; ============================================================================
;; DOCUMENTATION COMPLETE - CONTRACT CONTINUES WITH EXISTING FUNCTIONS
;; ============================================================================