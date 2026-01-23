;; SIP-010 Fungible Token Standard Implementation
;; A basic fungible token contract following the SIP-010 standard

;; Token trait implementation
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))

;; Token configuration
(define-constant token-name "StackMart Token")
(define-constant token-symbol "SMT")
(define-constant token-decimals u6)
(define-constant token-uri (some u"https://stackmart.io/token-metadata.json"))

;; Total supply (1 billion tokens with 6 decimals)
(define-constant total-supply u1000000000000000)

;; Data variables
(define-data-var token-total-supply uint total-supply)

;; Data maps
(define-map token-balances principal uint)
(define-map token-allowances {owner: principal, spender: principal} uint)

;; Initialize contract with total supply to contract owner
(map-set token-balances contract-owner total-supply)