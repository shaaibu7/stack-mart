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
;; Define the fungible token
(define-fungible-token smt-token total-supply)

;; Mint function (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-mint? smt-token amount recipient))
    (print {action: "mint", recipient: recipient, amount: amount})
    (ok true)))
;; Burn function
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (or (is-eq owner tx-sender) (is-eq owner contract-caller)) err-not-token-owner)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-burn? smt-token amount owner))
    (print {action: "burn", owner: owner, amount: amount})
    (ok true)))
;; Get allowance
(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? token-allowances {owner: owner, spender: spender}))))

;; Approve function
(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (map-set token-allowances {owner: tx-sender, spender: spender} amount)
    (print {action: "approve", owner: tx-sender, spender: spender, amount: amount})
    (ok true)))
;; Transfer from function (for approved spending)
(define-public (transfer-from (amount uint) (owner principal) (recipient principal) (memo (optional (buff 34))))
  (let ((allowance (default-to u0 (map-get? token-allowances {owner: owner, spender: tx-sender}))))
    (asserts! (>= allowance amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-transfer? smt-token amount owner recipient))
    (map-set token-allowances {owner: owner, spender: tx-sender} (- allowance amount))
    (print {action: "transfer-from", owner: owner, recipient: recipient, amount: amount, memo: memo})
    (ok true)))
;; Increase allowance
(define-public (increase-allowance (spender principal) (amount uint))
  (let ((current-allowance (default-to u0 (map-get? token-allowances {owner: tx-sender, spender: spender}))))
    (asserts! (> amount u0) err-invalid-amount)
    (map-set token-allowances {owner: tx-sender, spender: spender} (+ current-allowance amount))
    (print {action: "increase-allowance", owner: tx-sender, spender: spender, amount: amount})
    (ok true)))
;; Decrease allowance
(define-public (decrease-allowance (spender principal) (amount uint))
  (let ((current-allowance (default-to u0 (map-get? token-allowances {owner: tx-sender, spender: spender}))))
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= current-allowance amount) err-insufficient-balance)
    (map-set token-allowances {owner: tx-sender, spender: spender} (- current-allowance amount))
    (print {action: "decrease-allowance", owner: tx-sender, spender: spender, amount: amount})
    (ok true)))
;; Revoke allowance (set to zero)
(define-public (revoke-allowance (spender principal))
  (begin
    (map-delete token-allowances {owner: tx-sender, spender: spender})
    (print {action: "revoke-allowance", owner: tx-sender, spender: spender})
    (ok true)))
;; Batch transfer function
(define-public (batch-transfer (transfers (list 200 {recipient: principal, amount: uint, memo: (optional (buff 34))})))
  (begin
    (asserts! (> (len transfers) u0) err-invalid-amount)
    (fold check-and-transfer transfers (ok true))))
;; Helper function for batch transfer
(define-private (check-and-transfer (transfer-data {recipient: principal, amount: uint, memo: (optional (buff 34))}) (previous-result (response bool uint)))
  (match previous-result
    success (transfer (get amount transfer-data) tx-sender (get recipient transfer-data) (get memo transfer-data))
    error (err error)))
;; Pause/unpause functionality
(define-data-var contract-paused bool false)

;; Check if contract is paused
(define-read-only (is-paused)
  (var-get contract-paused))

;; Pause contract (owner only)
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (print {action: "pause-contract"})
    (ok true)))
;; Unpause contract (owner only)
(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (print {action: "unpause-contract"})
    (ok true)))
;; Blacklist functionality
(define-map blacklisted-addresses principal bool)

;; Check if address is blacklisted
(define-read-only (is-blacklisted (address principal))
  (default-to false (map-get? blacklisted-addresses address)))

;; Add address to blacklist (owner only)
(define-public (blacklist-address (address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set blacklisted-addresses address true)
    (print {action: "blacklist-address", address: address})
    (ok true)))
;; Remove address from blacklist (owner only)
(define-public (unblacklist-address (address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete blacklisted-addresses address)
    (print {action: "unblacklist-address", address: address})
    (ok true)))