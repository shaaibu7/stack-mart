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

;; SIP-010 Standard Functions

;; Get token name
(define-read-only (get-name)
  (ok token-name))

;; Get token symbol  
(define-read-only (get-symbol)
  (ok token-symbol))

;; Get token decimals
(define-read-only (get-decimals)
  (ok token-decimals))

;; Get token balance of a principal
(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? token-balances who))))

;; Get total supply
(define-read-only (get-total-supply)
  (ok (var-get token-total-supply)))

;; Get token URI
(define-read-only (get-token-uri)
  (ok token-uri))
;; Transfer function
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) err-not-token-owner)
    (asserts! (> amount u0) err-invalid-amount)
    (let ((from-balance (default-to u0 (map-get? token-balances from))))
      (asserts! (>= from-balance amount) err-insufficient-balance)
      (try! (ft-transfer? smt-token amount from to))
      (print {action: "transfer", from: from, to: to, amount: amount, memo: memo})
      (ok true))))