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
;; Balance and Supply Query Functions

;; Get balance for a principal (returns 0 if never held tokens)
(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? balances who))))
;; Get total supply of tokens
(define-read-only (get-total-supply)
  (ok (var-get total-supply)))
;; Transfer Helper Functions

;; Validate transfer parameters
(define-private (validate-transfer (amount uint) (sender principal) (recipient principal))
  (begin
    ;; Check for zero amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check for self-transfer
    (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
    ;; Additional validation for principal validity (basic check)
    (asserts! (is-standard sender) ERR-INVALID-PRINCIPAL)
    (asserts! (is-standard recipient) ERR-INVALID-PRINCIPAL)
    (ok true)))
;; Check if sender has sufficient balance for transfer
(define-private (check-balance (amount uint) (sender principal))
  (let ((sender-balance (default-to u0 (map-get? balances sender))))
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (ok sender-balance)))
;; Update balances atomically for transfer
(define-private (update-balances (amount uint) (sender principal) (recipient principal) (sender-balance uint))
  (let ((new-sender-balance (- sender-balance amount))
        (recipient-balance (default-to u0 (map-get? balances recipient)))
        (new-recipient-balance (+ recipient-balance amount)))
    ;; Update sender balance
    (if (is-eq new-sender-balance u0)
      (map-delete balances sender)
      (map-set balances sender new-sender-balance))
    ;; Update recipient balance
    (map-set balances recipient new-recipient-balance)
    (ok true)))
;; Main Transfer Function

;; Transfer tokens from sender to recipient
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Validate caller is the sender
    (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
    ;; Validate transfer parameters
    (try! (validate-transfer amount sender recipient))
    ;; Check sufficient balance
    (let ((sender-balance (try! (check-balance amount sender))))
      ;; Update balances
      (try! (update-balances amount sender recipient sender-balance))
      ;; Emit transfer event
      (emit-transfer-event amount sender recipient)
      ;; Return success
      (ok true))))
;; Event Emission Functions

;; Emit transfer event following SIP-010 specification
(define-private (emit-transfer-event (amount uint) (sender principal) (recipient principal))
  (print {
    type: "ft_transfer_event",
    token-contract: (as-contract tx-sender),
    amount: amount,
    sender: sender,
    recipient: recipient
  }))
;; Emit mint event following SIP-010 specification
(define-private (emit-mint-event (amount uint) (recipient principal))
  (print {
    type: "ft_mint_event",
    token-contract: (as-contract tx-sender),
    amount: amount,
    recipient: recipient
  }))
;; Minting Functions

;; Private mint function for creating new tokens
(define-private (mint (amount uint) (recipient principal))
  (let ((recipient-balance (default-to u0 (map-get? balances recipient)))
        (new-recipient-balance (+ recipient-balance amount))
        (current-supply (var-get total-supply))
        (new-supply (+ current-supply amount)))
    ;; Update recipient balance
    (map-set balances recipient new-recipient-balance)
    ;; Update total supply
    (var-set total-supply new-supply)
    ;; Emit mint event
    (emit-mint-event amount recipient)
    (ok true)))
;; Contract Initialization

;; Initialize contract with initial token supply to deployer
(begin
  (try! (mint INITIAL-SUPPLY tx-sender)))
;; Safe Arithmetic Functions

;; Safe addition with overflow protection
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (asserts! (>= result a) (err u999)) ;; Overflow check
    (ok result)))

;; Safe subtraction with underflow protection  
(define-private (safe-sub (a uint) (b uint))
  (asserts! (>= a b) (err u998)) ;; Underflow check
  (ok (- a b)))