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