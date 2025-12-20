;; StackMart marketplace scaffold

(define-data-var next-id uint u1)

(define-constant MAX_ROYALTY_BIPS u1000) ;; 10% in basis points
(define-constant BPS_DENOMINATOR u10000)
(define-constant ERR_BAD_ROYALTY (err u400))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_NOT_OWNER (err u403))
(define-constant ERR_NFT_TRANSFER_FAILED (err u500))
(define-constant ERR_ESCROW_NOT_FOUND (err u404))
(define-constant ERR_INVALID_STATE (err u400))
(define-constant ERR_NOT_BUYER (err u403))
(define-constant ERR_NOT_SELLER (err u403))
(define-constant ERR_TIMEOUT_NOT_REACHED (err u400))

;; Escrow timeout: 144 blocks (approximately 1 day assuming 10 min blocks)
;; Note: Using burn-block-height for timeout calculation
(define-constant ESCROW_TIMEOUT_BLOCKS u144)

(define-map listings
  { id: uint }
  { seller: principal
  , price: uint
  , royalty-bips: uint
  , royalty-recipient: principal
  , nft-contract: (optional principal)
  , token-id: (optional uint)
  , license-terms: (optional (string-ascii 500))
  })

;; Escrow state: pending, delivered, confirmed, disputed, released, cancelled
(define-map escrows
  { listing-id: uint }
  { buyer: principal
  , amount: uint
  , created-at-block: uint
  , state: (string-ascii 20)
  , timeout-block: uint
  })

(define-read-only (get-next-id)
  (ok (var-get next-id)))

(define-read-only (get-listing (id uint))
  (match (map-get? listings { id: id })
    listing (ok listing)
    ERR_NOT_FOUND))

(define-read-only (get-listing-with-nft (id uint))
  (match (map-get? listings { id: id })
    listing (ok listing)
    ERR_NOT_FOUND))

(define-read-only (get-escrow-status (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow (ok escrow)
    ERR_ESCROW_NOT_FOUND))

;; Verify NFT ownership using SIP-009 standard (get-owner function)
;; Note: NFT verification temporarily simplified - will be enhanced with proper trait support
(define-private (verify-nft-ownership (nft-contract principal) (token-id uint) (owner principal))
  ;; TODO: Implement proper NFT ownership verification with SIP-009 trait
  ;; For now, return true to allow listing creation (should be replaced with actual verification)
  true)

;; Legacy function - kept for backward compatibility (no NFT)
(define-public (create-listing (price uint) (royalty-bips uint) (royalty-recipient principal))
  (begin
    (asserts! (<= royalty-bips MAX_ROYALTY_BIPS) ERR_BAD_ROYALTY)
    (let ((id (var-get next-id)))
      (map-set listings
        { id: id }
        { seller: tx-sender
        , price: price
        , royalty-bips: royalty-bips
        , royalty-recipient: royalty-recipient
        , nft-contract: none
        , token-id: none
        , license-terms: none })
      (var-set next-id (+ id u1))
      (ok id))))

;; Create listing with NFT and license terms
(define-public (create-listing-with-nft
    (nft-contract principal)
    (token-id uint)
    (price uint)
    (royalty-bips uint)
    (royalty-recipient principal)
    (license-terms (string-ascii 500)))
  (begin
    (asserts! (<= royalty-bips MAX_ROYALTY_BIPS) ERR_BAD_ROYALTY)
    ;; Verify seller owns the NFT
    (asserts! (verify-nft-ownership nft-contract token-id tx-sender) ERR_NOT_OWNER)
    (let ((id (var-get next-id)))
      (map-set listings
        { id: id }
        { seller: tx-sender
        , price: price
        , royalty-bips: royalty-bips
        , royalty-recipient: royalty-recipient
        , nft-contract: (some nft-contract)
        , token-id: (some token-id)
        , license-terms: (some license-terms) })
      (var-set next-id (+ id u1))
      (ok id))))

;; Legacy immediate purchase (kept for backward compatibility)
(define-public (buy-listing (id uint))
  (match (map-get? listings { id: id })
    listing
      (let (
            (price (get price listing))
            (royalty-bips (get royalty-bips listing))
            (seller (get seller listing))
            (royalty-recipient (get royalty-recipient listing))
            (nft-contract-opt (get nft-contract listing))
            (token-id-opt (get token-id listing))
            (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
            (seller-share (- price royalty))
           )
        (begin
          ;; Transfer NFT if present (SIP-009 transfer function)
          ;; Note: Seller must authorize this contract to transfer on their behalf
          ;; TODO: Implement proper NFT transfer with SIP-009 trait support
          (match nft-contract-opt
            nft-contract-principal
              (match token-id-opt
                token-id-value
                  ;; NFT transfer temporarily disabled - requires trait implementation
                  true
                true)
            true)
          ;; Transfer payments
          (if (> royalty u0)
            (try! (stx-transfer? royalty tx-sender royalty-recipient))
            true)
          (try! (stx-transfer? seller-share tx-sender seller))
          (map-delete listings { id: id })
          (ok true)))
    ERR_NOT_FOUND))

;; Create escrow for listing purchase
;; Note: In Clarity, holding STX in contract requires the contract to receive funds first
;; For now, we track escrow state. Actual STX transfer happens on release.
(define-public (buy-listing-escrow (id uint))
  (match (map-get? listings { id: id })
    listing
      (begin
        ;; Check escrow doesn't already exist
        (asserts! (is-none (map-get? escrows { listing-id: id })) ERR_INVALID_STATE)
        (let (
              (price (get price listing))
             )
          (begin
            ;; Create escrow record
            ;; Note: STX should be transferred to contract address separately
            ;; Timeout mechanism can be added later with proper block height function
            (map-set escrows
              { listing-id: id }
              { buyer: tx-sender
              , amount: price
              , created-at-block: u0
              , state: "pending"
              , timeout-block: u0 })
            (ok true))))
    ERR_NOT_FOUND))

;; Seller confirms delivery
(define-public (confirm-delivery (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_SELLER)
            (asserts! (is-eq (get state escrow) "pending") ERR_INVALID_STATE)
            ;; Transfer NFT if present
            (let ((nft-contract-opt (get nft-contract listing))
                  (token-id-opt (get token-id listing))
                  (buyer (get buyer escrow)))
              (begin
                ;; TODO: Implement proper NFT transfer with SIP-009 trait support
                (match nft-contract-opt
                  nft-contract-principal
                    (match token-id-opt
                      token-id-value
                        ;; NFT transfer temporarily disabled - requires trait implementation
                        true
                      true)
                  true)
                ;; Update escrow state to delivered
                (map-set escrows
                  { listing-id: listing-id }
                  { buyer: buyer
                  , amount: (get amount escrow)
                  , created-at-block: (get created-at-block escrow)
                  , state: "delivered"
                  , timeout-block: (get timeout-block escrow) })
                (ok true))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Buyer confirms receipt and releases escrow
(define-public (confirm-receipt (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            (asserts! (is-eq tx-sender (get buyer escrow)) ERR_NOT_BUYER)
            (asserts! (is-eq (get state escrow) "delivered") ERR_INVALID_STATE)
            ;; Release escrow payments
            (let (
                  (price (get amount escrow))
                  (royalty-bips (get royalty-bips listing))
                  (seller (get seller listing))
                  (royalty-recipient (get royalty-recipient listing))
                  (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                  (seller-share (- price royalty))
                 )
              (begin
                ;; Transfer payments from escrow
                ;; Note: In a full implementation, STX would be transferred from contract-held escrow
                ;; For now, this is a placeholder - actual transfer requires contract to hold funds
                (if (> royalty u0)
                  (try! (stx-transfer? royalty tx-sender royalty-recipient))
                  true)
                (try! (stx-transfer? seller-share tx-sender seller))
                ;; Update escrow state
                (map-set escrows
                  { listing-id: listing-id }
                  { buyer: (get buyer escrow)
                  , amount: price
                  , created-at-block: (get created-at-block escrow)
                  , state: "confirmed"
                  , timeout-block: (get timeout-block escrow) })
                ;; Remove listing
                (map-delete listings { id: listing-id })
                (ok true))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Release escrow after timeout or manual release
(define-public (release-escrow (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (let (
                (state (get state escrow))
               )
            (begin
              ;; Can release if: state is "delivered" (buyer can release after delivery)
              ;; Timeout check can be added later with proper block height function
              (asserts! (is-eq state "delivered") ERR_TIMEOUT_NOT_REACHED)
              ;; Only buyer or seller can release after timeout
              (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller listing))) ERR_NOT_OWNER)
              ;; If delivered and timeout, release to seller (seller fulfilled, buyer didn't confirm)
              ;; If pending and timeout, refund to buyer
              (let (
                    (price (get amount escrow))
                    (seller (get seller listing))
                    (buyer-addr (get buyer escrow))
                    (timeout-block (get timeout-block escrow))
                   )
                (begin
                  (if (is-eq state "delivered")
                    ;; Seller delivered, buyer didn't confirm - release to seller
                    (let (
                          (royalty-bips (get royalty-bips listing))
                          (royalty-recipient (get royalty-recipient listing))
                          (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                          (seller-share (- price royalty))
                         )
                      (begin
                        ;; Note: In full implementation, transfer from contract-held escrow
                        (if (> royalty u0)
                          (try! (stx-transfer? royalty tx-sender royalty-recipient))
                          true)
                        (try! (stx-transfer? seller-share tx-sender seller))))
                    ;; Pending and timeout - refund to buyer
                    (try! (stx-transfer? price tx-sender buyer-addr)))
                  ;; Update escrow state
                  (map-set escrows
                    { listing-id: listing-id }
                    { buyer: buyer-addr
                    , amount: price
                    , created-at-block: (get created-at-block escrow)
                    , state: "released"
                    , timeout-block: timeout-block })
                  ;; Remove listing if released
                  (if (is-eq state "delivered")
                    (map-delete listings { id: listing-id })
                    true)
                  (ok true)))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Cancel escrow (only if pending and by buyer or seller)
(define-public (cancel-escrow (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            (asserts! (is-eq (get state escrow) "pending") ERR_INVALID_STATE)
            (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller listing))) ERR_NOT_OWNER)
            ;; Refund to buyer
            (let ((price (get amount escrow))
                  (buyer-addr (get buyer escrow)))
              (begin
                ;; Note: In full implementation, transfer from contract-held escrow
                (try! (stx-transfer? price tx-sender buyer-addr))
                ;; Update escrow state
                (map-set escrows
                  { listing-id: listing-id }
                  { buyer: buyer-addr
                  , amount: price
                  , created-at-block: (get created-at-block escrow)
                  , state: "cancelled"
                  , timeout-block: (get timeout-block escrow) })
                (ok true))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

