;; SP-010 Token Contract
;; SIP-010 Compliant Fungible Token Implementation

;; Contract metadata
(define-constant CONTRACT-NAME "SP-010")
(define-constant CONTRACT-SYMBOL "SP010")
(define-constant CONTRACT-DECIMALS u6)
(define-constant CONTRACT-URI "https://example.com/sp010-metadata.json")

;; Initial supply (1 million tokens with 6 decimals)
(define-constant INITIAL-SUPPLY u1000000000000)

;; Data storage
;; Map to track token balances for each principal
(define-map balances principal uint)

;; Variable to track total token supply
(define-data-var total-supply uint u0)
;; Error constants following SIP-010 standards
(define-constant ERR-INSUFFICIENT-BALANCE (err u1))
(define-constant ERR-INVALID-PRINCIPAL (err u2))
(define-constant ERR-UNAUTHORIZED (err u3))
(define-constant ERR-INVALID-AMOUNT (err u4))
(define-constant ERR-SELF-TRANSFER (err u5))
;; SIP-010 Metadata Functions

;; Get token name
(define-read-only (get-name)
  (ok CONTRACT-NAME))
;; Get token symbol
(define-read-only (get-symbol)
  (ok CONTRACT-SYMBOL))
;; Get token decimals
(define-read-only (get-decimals)
  (ok CONTRACT-DECIMALS))
;; Get token URI for metadata
(define-read-only (get-token-uri)
  (ok (some CONTRACT-URI)))