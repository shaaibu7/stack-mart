;; StackMart marketplace scaffold

;; SIP-009 NFT Standard Trait
;; Standard interface for NFT contracts on Stacks
(define-trait sip009-nft-trait
  (
    ;; Get the owner of an NFT token
    ;; Returns (optional principal) if token exists, or error code
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer an NFT from sender to recipient
    ;; Returns bool (true if successful) or error code
    (transfer (uint principal principal) (response bool uint))
  )
)

(define-data-var next-id uint u1)
(define-data-var next-bundle-id uint u1)
(define-data-var next-pack-id uint u1)

(define-constant MAX_ROYALTY_BIPS u1000) ;; 10% in basis points
(define-constant BPS_DENOMINATOR u10000)
(define-data-var next-auction-id uint u1)
(define-constant ERR_BAD_ROYALTY (err u400))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_NOT_OWNER (err u403))
(define-constant ERR_NFT_TRANSFER_FAILED (err u500))
(define-constant ERR_ESCROW_NOT_FOUND (err u404))
(define-constant ERR_INVALID_STATE (err u400))
(define-constant ERR_NOT_BUYER (err u403))
(define-constant ERR_NOT_SELLER (err u403))
(define-constant ERR_TIMEOUT_NOT_REACHED (err u400))
(define-constant ERR_ALREADY_ATTESTED (err u400))
(define-constant ERR_NOT_DELIVERED (err u400))
(define-constant ERR_DISPUTE_NOT_FOUND (err u404))
(define-constant ERR_DISPUTE_RESOLVED (err u400))
(define-constant ERR_INSUFFICIENT_STAKES (err u400))
(define-constant ERR_INVALID_SIDE (err u400))
(define-constant ERR_BUNDLE_NOT_FOUND (err u404))
(define-constant ERR_PACK_NOT_FOUND (err u404))
(define-constant ERR_INVALID_LISTING (err u400))
(define-constant ERR_BUNDLE_EMPTY (err u400))
(define-data-var admin principal tx-sender)
(define-constant ERR_ALREADY_WISHLISTED (err u405))

;; Marketplace fee constants
(define-data-var marketplace-fee-bips uint u250) ;; 2.5% fee
(define-data-var fee-recipient principal tx-sender) ;; Deployer is initial fee recipient

;; Bundle and pack constants
(define-constant MAX_BUNDLE_SIZE u10)
(define-constant MAX_PACK_SIZE u20)
(define-constant MAX_DISCOUNT_BIPS u5000) ;; 50% max discount

;; Dispute resolution constants
(define-constant MIN_STAKE_AMOUNT u1000) ;; Minimum stake amount
(define-constant DISPUTE_RESOLUTION_THRESHOLD u5000) ;; Minimum total stakes to resolve

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

;; Reputation system
(define-map reputation
  { user: principal }
  { successful-txs: uint
  , failed-txs: uint
  , rating-sum: uint
  , rating-count: uint
  , total-volume: uint
  })

;; Delivery attestations
(define-map delivery-attestations
  { listing-id: uint }
  { delivery-hash: (buff 32)
  , attested-at-block: uint
  , confirmed: bool
  , rejected: bool
  , rejection-reason: (optional (string-ascii 200))
  })

;; Transaction history tracking
(define-map transaction-history
  { principal: principal
  , tx-index: uint }
  { listing-id: uint
  , counterparty: principal
  , amount: uint
  , completed: bool
  , timestamp: uint
  })

(define-map tx-index-counter
  { principal: principal }
  uint)

;; Dispute resolution system
(define-data-var next-dispute-id uint u1)

(define-map disputes
  { id: uint }
  { escrow-id: uint
  , created-by: principal
  , reason: (string-ascii 500)
  , created-at-block: uint
  , resolved: bool
  , buyer-stakes: uint
  , seller-stakes: uint
  , resolution: (optional (string-ascii 20))
  })

(define-map dispute-stakes
  { dispute-id: uint
  , staker: principal }
  { amount: uint
  , side: bool
  })

(define-map dispute-votes
  { dispute-id: uint
  , voter: principal }
  { vote: bool
  , weight: uint
  })

(define-map wishlists
  { user: principal }
  { listing-ids: (list 100 uint) })

;; Price history tracking
(define-map price-history
  { listing-id: uint }
  { history: (list 10 { price: uint, block-height: uint }) })
(define-public (set-admin (new-admin principal)) (begin (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER) (ok (var-set admin new-admin))))
(define-public (set-marketplace-fee (new-fee uint)) (begin (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER) (ok (var-set marketplace-fee-bips new-fee))))
(define-public (set-fee-recipient (new-recipient principal)) (begin (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER) (ok (var-set fee-recipient new-recipient))))

(define-public (update-listing-price (id uint) (new-price uint))
  (let (
    (listing (unwrap! (map-get? listings { id: id }) ERR_NOT_FOUND))
    (current-history (get history (default-to { history: (list) } (map-get? price-history { listing-id: id }))))
  )
    (asserts! (is-eq (get seller listing) tx-sender) ERR_NOT_OWNER)
    (map-set listings { id: id } (merge listing { price: new-price }))
    (map-set price-history 
      { listing-id: id } 
      { history: (unwrap! (as-max-len? (append current-history { price: new-price, block-height: burn-block-height }) u10) (err u500)) })
    (ok true)))

(define-read-only (is-wishlisted (user principal) (listing-id uint)) (let ((current-wishlist (get listing-ids (default-to { listing-ids: (list) } (map-get? wishlists { user: user }))))) (ok (is-some (index-of current-wishlist listing-id)))))

(define-read-only (get-wishlist (user principal))
  (ok (default-to { listing-ids: (list) } (map-get? wishlists { user: user }))))

(define-read-only (get-price-history (listing-id uint))
  (ok (default-to { history: (list) } (map-get? price-history { listing-id: listing-id }))))

(define-private (filter-id (id uint))
  (not (is-eq id (var-get remove-id-iter))))

(define-data-var remove-id-iter uint u0)

(define-public (toggle-wishlist (listing-id uint))
  (let (
    (current-wishlist (default-to (list) (get listing-ids (map-get? wishlists { user: tx-sender }))))
  )
    (if (is-some (index-of current-wishlist listing-id))
      (begin
        (var-set remove-id-iter listing-id)
        (map-set wishlists { user: tx-sender } { listing-ids: (filter filter-id current-wishlist) })
        (ok false))
      (begin
        (map-set wishlists { user: tx-sender } { listing-ids: (unwrap! (as-max-len? (append current-wishlist listing-id) u100) (err u500)) })
        (ok true)))))

;; Auction System
(define-map auctions
  { id: uint }
  { seller: principal
  , nft-contract: principal
  , token-id: uint
  , start-price: uint
  , reserve-price: uint
  , end-block: uint
  , highest-bid: uint
  , highest-bidder: (optional principal)
  , state: (string-ascii 20) ;; "active", "ended", "cancelled"
  })

(define-public (create-auction (nft-trait <sip009-nft-trait>) (token-id uint) (start-price uint) (reserve-price uint) (duration uint))
  (let ((id (var-get next-auction-id)))
    (begin
      ;; Transfer NFT to contract
      (try! (contract-call? nft-trait transfer token-id tx-sender (as-contract tx-sender)))
      (map-set auctions
        { id: id }
        { seller: tx-sender
        , nft-contract: (contract-of nft-trait)
        , token-id: token-id
        , start-price: start-price
        , reserve-price: reserve-price
        , end-block: (+ burn-block-height duration)
        , highest-bid: u0
        , highest-bidder: none
        , state: "active" })
      (var-set next-auction-id (+ id u1))
      (ok id))))

(define-public (place-bid (auction-id uint) (amount uint))
  (match (map-get? auctions { id: auction-id })
    auction
      (let ((current-bid (get highest-bid auction))
            (current-bidder (get highest-bidder auction)))
        (begin
          (asserts! (is-eq (get state auction) "active") ERR_INVALID_STATE)
          (asserts! (< burn-block-height (get end-block auction)) ERR_TIMEOUT_NOT_REACHED)
          (asserts! (> amount current-bid) ERR_INVALID_LISTING) ;; Bid must be higher
          (asserts! (>= amount (get start-price auction)) ERR_INVALID_LISTING)
          
          ;; Transfer STX to contract
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          
          ;; Refund previous bidder
          (match current-bidder
            prev-bidder (try! (as-contract (stx-transfer? current-bid tx-sender prev-bidder)))
            true)
            
          (map-set auctions
            { id: auction-id }
            (merge auction { highest-bid: amount, highest-bidder: (some tx-sender) }))
          (ok true)))
    ERR_NOT_FOUND))

(define-public (end-auction (auction-id uint) (nft-trait <sip009-nft-trait>))
  (match (map-get? auctions { id: auction-id })
    auction
      (begin
        (asserts! (is-eq (get state auction) "active") ERR_INVALID_STATE)
        ;; Allow ending if expired OR if seller cancels (if no bids)
        ;; If bids exist, must wait for expiry
        (asserts! (or (>= burn-block-height (get end-block auction)) 
                      (and (is-eq tx-sender (get seller auction)) (is-eq (get highest-bid auction) u0))) 
                  ERR_TIMEOUT_NOT_REACHED)
        
        ;; Verify trait matches
        (asserts! (is-eq (contract-of nft-trait) (get nft-contract auction)) ERR_INVALID_LISTING)

        (let ((winner (get highest-bidder auction))
              (price (get highest-bid auction))
              (seller (get seller auction))
              (token-id (get token-id auction)))
           (begin
             (match winner
               buyer 
                 (if (>= price (get reserve-price auction))
                   (begin
                     ;; Success - Transfer NFT to winner, STX to seller (minus fee)
                     (try! (as-contract (contract-call? nft-trait transfer token-id tx-sender buyer)))
                     ;; Transfer STX to seller (minus fee)
                     (let ((marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
                           (seller-share (- price marketplace-fee)))
                       (try! (as-contract (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient))))
                       (try! (as-contract (stx-transfer? seller-share tx-sender seller))))
                     
                     (map-set auctions { id: auction-id } (merge auction { state: "ended" }))
                     (ok true))
                   (begin
                     ;; Reserve not met - Return NFT to seller, refund buyer
                     (try! (as-contract (stx-transfer? price tx-sender buyer)))
                     (try! (as-contract (contract-call? nft-trait transfer token-id tx-sender seller)))
                     (map-set auctions { id: auction-id } (merge auction { state: "ended" }))
                     (ok false)))
               ;; No bids - Return NFT to seller
               (begin 
                  (try! (as-contract (contract-call? nft-trait transfer token-id tx-sender seller)))
                  (map-set auctions { id: auction-id } (merge auction { state: "ended" }))
                  (ok true)))
           )) 
      )
    ERR_NOT_FOUND))

;; Bundle and curated pack system
(define-map bundles
  { id: uint }
  { listing-ids: (list 10 uint)
  , discount-bips: uint
  , creator: principal
  , created-at-block: uint
  })

(define-map packs
  { id: uint }
  { listing-ids: (list 20 uint)
  , price: uint
  , curator: principal
  , created-at-block: uint
  })

(define-read-only (get-next-id)
  (ok (var-get next-id)))

(define-read-only (get-listing (id uint))
  (match (map-get? listings { id: id })
    listing (ok listing)
    ERR_NOT_FOUND))

;; get-listing-with-nft is an alias for get-listing (both return same data)
(define-read-only (get-listing-with-nft (id uint))
  (get-listing id))

(define-read-only (get-escrow-status (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow (ok escrow)
    ERR_ESCROW_NOT_FOUND))

;; Shared default reputation structure
(define-constant DEFAULT_REPUTATION {
  successful-txs: u0
, failed-txs: u0
, rating-sum: u0
, rating-count: u0
})

(define-read-only (get-seller-reputation (seller principal))
  (ok (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } (map-get? reputation { user: seller }))))

(define-read-only (get-buyer-reputation (buyer principal))
  (ok (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } (map-get? reputation { user: buyer }))))

;; Verify NFT ownership using SIP-009 standard (get-owner function)
;; Note: In Clarity, contract-call? with variable principals works at runtime
;; The trait is defined for documentation and type checking purposes
(define-private (verify-nft-ownership (nft-contract-addr principal) (token-id uint) (owner principal))
  (match (contract-call? nft-contract-addr get-owner token-id)
    (ok nft-owner-opt)
      (match nft-owner-opt
        (some nft-owner)
          (is-eq nft-owner owner)
        none
          false)
    (err error-code)
      false))

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
            (marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
            (seller-share (- (- price royalty) marketplace-fee))
           )
        (begin
          ;; Transfer marketplace fee
          (try! (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient)))
          
          ;; Transfer royalty if applicable
          ;; Transfer NFT if present (SIP-009 transfer function)
          ;; Note: Seller must authorize this contract to transfer on their behalf
          (match nft-contract-opt
            nft-contract-principal
              (match token-id-opt
                token-id-value
                  (match (contract-call? nft-contract-principal transfer token-id-value seller tx-sender)
                    (ok transfer-success)
                      (asserts! transfer-success ERR_NFT_TRANSFER_FAILED)
                    (err error-code)
                      (err error-code))
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
            ;; Transfer STX to contract
            (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
            
            (map-set escrows
              { listing-id: id }
              { buyer: tx-sender
              , amount: price
              , created-at-block: burn-block-height
              , state: "pending"
              , timeout-block: (+ burn-block-height ESCROW_TIMEOUT_BLOCKS) })
            (ok true))))
    ERR_NOT_FOUND))

;; Seller attests delivery with delivery hash
(define-public (attest-delivery (listing-id uint) (delivery-hash (buff 32)))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_SELLER)
            (asserts! (is-eq (get state escrow) "pending") ERR_INVALID_STATE)
            ;; Check attestation doesn't already exist
            (asserts! (is-none (map-get? delivery-attestations { listing-id: listing-id })) ERR_ALREADY_ATTESTED)
            ;; Transfer NFT if present
            (let ((nft-contract-opt (get nft-contract listing))
                  (token-id-opt (get token-id listing))
                  (buyer (get buyer escrow)))
              (begin
                ;; Transfer NFT to buyer when seller attests delivery
                (match nft-contract-opt
                  nft-contract-principal
                    (match token-id-opt
                      token-id-value
                        (match (contract-call? nft-contract-principal transfer token-id-value tx-sender buyer)
                          (ok transfer-success)
                            (asserts! transfer-success ERR_NFT_TRANSFER_FAILED)
                          (err error-code)
                            (err error-code))
                      true)
                  true)
                ;; Create delivery attestation
                (map-set delivery-attestations
                  { listing-id: listing-id }
                  { delivery-hash: delivery-hash
                  , attested-at-block: u0
                  , confirmed: false
                  , rejected: false
                  , rejection-reason: none })
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

;; Seller confirms delivery (legacy function - kept for backward compatibility)
;; Note: New code should use attest-delivery with actual delivery hash
(define-public (confirm-delivery (listing-id uint))
  ;; For legacy compatibility, use zero buffer (32 bytes)
  (let ((zero-hash 0x0000000000000000000000000000000000000000000000000000000000000000))
    (try! (attest-delivery listing-id zero-hash))
    (ok true)))

;; Buyer confirms receipt and releases escrow
(define-public (confirm-receipt (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
(marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
(seller-share (- (- price royalty) marketplace-fee))
        listing
          (begin
            (asserts! (is-eq tx-sender (get buyer escrow)) ERR_NOT_BUYER)
            (asserts! (is-eq (get state escrow) "delivered") ERR_INVALID_STATE)
            ;; Release escrow payments
(try! (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient)))
(marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
(seller-share (- (- price royalty) marketplace-fee))
            (let (
                  (price (get amount escrow))
                  (royalty-bips (get royalty-bips listing))
                  (seller (get seller listing))
                  (royalty-recipient (get royalty-recipient listing))
(try! (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient)))
                  (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                  (seller-share (- price royalty))
                 )
              (begin
                
                ;; Transfer payments from escrow (contract holds funds)
                (if (> royalty u0)
                  (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
                  true)
                (try! (as-contract (stx-transfer? seller-share tx-sender seller)))
                ;; Update delivery attestation if exists
                (match (map-get? delivery-attestations { listing-id: listing-id })
                  attestation
                    (map-set delivery-attestations
                      { listing-id: listing-id }
                      { delivery-hash: (get delivery-hash attestation)
                      , attested-at-block: (get attested-at-block attestation)
                      , confirmed: true
                      , rejected: false
                      , rejection-reason: none })
                  true)
                ;; Update reputation - successful transaction
                (update-reputation seller true price)
                (update-reputation tx-sender true price)
                ;; Update escrow state
                (map-set escrows
                  { listing-id: listing-id }
                  { buyer: (get buyer escrow)
                  , amount: price
                  , created-at-block: (get created-at-block escrow)
                  , state: "confirmed"
                  , timeout-block: (get timeout-block escrow) })
                ;; Record transaction history
                (record-transaction seller listing-id tx-sender price true)
                (record-transaction tx-sender listing-id seller price true)
                ;; Remove listing
                (map-delete listings { id: listing-id })
                (ok true))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Buyer confirms delivery received (alias for confirm-receipt)
(define-public (confirm-delivery-received (listing-id uint))
  (confirm-receipt listing-id))

;; Buyer rejects delivery
(define-public (reject-delivery (listing-id uint) (reason (string-ascii 200)))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            (asserts! (is-eq tx-sender (get buyer escrow)) ERR_NOT_BUYER)
            (asserts! (is-eq (get state escrow) "delivered") ERR_INVALID_STATE)
            ;; Update delivery attestation
            (match (map-get? delivery-attestations { listing-id: listing-id })
              attestation
                (map-set delivery-attestations
                  { listing-id: listing-id }
                  { delivery-hash: (get delivery-hash attestation)
                  , attested-at-block: (get attested-at-block attestation)
                  , confirmed: false
                  , rejected: true
                  , rejection-reason: (some reason) })
              true)
            ;; Update reputation - failed transaction
            (update-reputation (get seller listing) false)
            (update-reputation tx-sender false)
            ;; Record transaction history
            (let ((price (get amount escrow)))
              (begin
                (record-transaction (get seller listing) listing-id tx-sender price false)
                (record-transaction tx-sender listing-id (get seller listing) price false)
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
                      (begin
                        ;; Transfer from contract-held escrow
                        (if (> royalty u0)
                          (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
                          true)
                        (try! (as-contract (stx-transfer? seller-share tx-sender seller))))
                    ;; Pending and timeout - refund to buyer
                    (try! (as-contract (stx-transfer? price tx-sender buyer-addr))))
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
                ;; Transfer from contract to buyer
                (try! (as-contract (stx-transfer? price tx-sender buyer-addr)))
                
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

;; Helper function to update reputation (optimized)
(define-private (update-reputation (principal principal) (success bool) (amount uint))
  (let ((current-rep (default-to DEFAULT_REPUTATION (map-get? reputation { user: principal })))) ;; Fixed map key
    (if success
      (map-set reputation
        { user: principal }
        { successful-txs: (+ (get successful-txs current-rep) u1)
        , failed-txs: (get failed-txs current-rep)
        , rating-sum: (get rating-sum current-rep)
        , rating-count: (get rating-count current-rep) })
      (map-set reputation
        { user: principal }
        { successful-txs: (get successful-txs current-rep)
        , failed-txs: (+ (get failed-txs current-rep) u1)
        , rating-sum: (get rating-sum current-rep)
        , rating-count: (get rating-count current-rep) }))))

;; Helper function to record transaction history
(define-private (record-transaction (principal principal) (listing-id uint) (counterparty principal) (amount uint) (completed bool))
  (let ((current-index (default-to u0 (map-get? tx-index-counter { principal: principal }))))
    (begin
      (map-set transaction-history
        { principal: principal
        , tx-index: current-index }
        { listing-id: listing-id
        , counterparty: counterparty
        , amount: amount
        , completed: completed
        , timestamp: u0 })
      (map-set tx-index-counter
        { principal: principal }
        (+ current-index u1)))))

;; Get transaction history for a principal (returns transaction by index)
(define-read-only (get-transaction-history (principal principal) (index uint))
  (match (map-get? transaction-history { principal: principal, tx-index: index })
    tx (ok tx)
    ERR_NOT_FOUND))

(define-read-only (get-dispute (dispute-id uint))
  (match (map-get? disputes { id: dispute-id })
    dispute (ok dispute)
    ERR_DISPUTE_NOT_FOUND))

(define-read-only (get-dispute-stakes (dispute-id uint) (staker principal))
  (match (map-get? dispute-stakes { dispute-id: dispute-id, staker: staker })
    stake (ok stake)
    ERR_NOT_FOUND))

;; Create a dispute for an escrow
(define-public (create-dispute (escrow-id uint) (reason (string-ascii 500)))
  (match (map-get? escrows { listing-id: escrow-id })
    escrow
      (match (map-get? listings { id: escrow-id })
        listing
          (begin
            ;; Only buyer or seller can create dispute
            (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller listing))) ERR_NOT_OWNER)
            ;; Escrow must be in delivered state
            (asserts! (is-eq (get state escrow) "delivered") ERR_INVALID_STATE)
            ;; Check dispute doesn't already exist
            (let ((dispute-id (var-get next-dispute-id)))
              (begin
                (asserts! (is-none (map-get? disputes { id: dispute-id })) ERR_INVALID_STATE)
                ;; Create dispute
                (map-set disputes
                  { id: dispute-id }
                  { escrow-id: escrow-id
                  , created-by: tx-sender
                  , reason: reason
                  , created-at-block: u0
                  , resolved: false
                  , buyer-stakes: u0
                  , seller-stakes: u0
                  , resolution: none })
                ;; Update escrow state to disputed
                (map-set escrows
                  { listing-id: escrow-id }
                  { buyer: (get buyer escrow)
                  , amount: (get amount escrow)
                  , created-at-block: (get created-at-block escrow)
                  , state: "disputed"
                  , timeout-block: (get timeout-block escrow) })
                (var-set next-dispute-id (+ dispute-id u1))
                (ok dispute-id))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Stake on a dispute (side: true = buyer, false = seller)
(define-public (stake-on-dispute (dispute-id uint) (amount uint) (side bool))
  (match (map-get? disputes { id: dispute-id })
    dispute
      (begin
        ;; Dispute must not be resolved
        (asserts! (not (get resolved dispute)) ERR_DISPUTE_RESOLVED)
        ;; Minimum stake amount
        (asserts! (>= amount MIN_STAKE_AMOUNT) ERR_INSUFFICIENT_STAKES)
        
        (let ((current-stake (default-to { amount: u0, side: false } (map-get? dispute-stakes { dispute-id: dispute-id, staker: tx-sender }))))
          (begin
            ;; Update or create stake
            (map-set dispute-stakes
              { dispute-id: dispute-id
              , staker: tx-sender }
              { amount: (+ (get amount current-stake) amount)
              , side: side })
            ;; Transfer stake amount to contract
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            
            ;; Update dispute stakes totals (optimized)
            (let ((buyer-stakes-new (if side (+ (get buyer-stakes dispute) amount) (get buyer-stakes dispute)))
                  (seller-stakes-new (if side (get seller-stakes dispute) (+ (get seller-stakes dispute) amount))))
              (map-set disputes
                { id: dispute-id }
                (merge dispute 
                  { buyer-stakes: buyer-stakes-new
                  , seller-stakes: seller-stakes-new }))
            (ok true))))
    ERR_DISPUTE_NOT_FOUND))

;; Vote on a dispute (weighted by stake amount)
(define-public (vote-on-dispute (dispute-id uint) (vote bool))
  (match (map-get? disputes { id: dispute-id })
    dispute
      (match (map-get? dispute-stakes { dispute-id: dispute-id, staker: tx-sender })
        stake
          (begin
            ;; Dispute must not be resolved
            (asserts! (not (get resolved dispute)) ERR_DISPUTE_RESOLVED)
            ;; Must have staked to vote
            (asserts! (> (get amount stake) u0) ERR_INSUFFICIENT_STAKES)
            ;; Vote must match stake side
            (asserts! (is-eq vote (get side stake)) ERR_INVALID_SIDE)
            ;; Record vote with weight = stake amount
            (map-set dispute-votes
              { dispute-id: dispute-id
              , voter: tx-sender }
              { vote: vote
              , weight: (get amount stake) })
            (ok true))
        ERR_NOT_FOUND)
    ERR_DISPUTE_NOT_FOUND))

;; Resolve dispute based on weighted votes
(define-public (resolve-dispute (dispute-id uint))
  (match (map-get? disputes { id: dispute-id })
    dispute
      (begin
        ;; Dispute must not be resolved
        (asserts! (not (get resolved dispute)) ERR_DISPUTE_RESOLVED)
        ;; Must have minimum stakes to resolve
        (let ((total-stakes (+ (get buyer-stakes dispute) (get seller-stakes dispute))))
          (begin
            (asserts! (>= total-stakes DISPUTE_RESOLUTION_THRESHOLD) ERR_INSUFFICIENT_STAKES)
            ;; Calculate weighted votes (simplified - in full implementation would iterate all votes)
            ;; For now, use stake amounts as proxy for votes
            (let ((buyer-stakes (get buyer-stakes dispute))
                  (seller-stakes (get seller-stakes dispute))
                  (escrow-id (get escrow-id dispute)))
              (begin
                ;; Determine winner based on stake amounts
                (if (> buyer-stakes seller-stakes)
                  ;; Buyer wins - release to buyer
                  (begin
                    ;; Mark dispute as resolved
                    (map-set disputes
                      { id: dispute-id }
                      { escrow-id: escrow-id
                      , created-by: (get created-by dispute)
                      , reason: (get reason dispute)
                      , created-at-block: (get created-at-block dispute)
                      , resolved: true
                      , buyer-stakes: buyer-stakes
                      , seller-stakes: seller-stakes
                      , resolution: (some "buyer") })
                    ;; Refund buyer from contract
                    (try! (match (map-get? escrows { listing-id: escrow-id })
                      escrow
                        (let ((price (get amount escrow))
                              (buyer-addr (get buyer escrow)))
                          (begin
                            ;; Transfer from contract
                            (try! (as-contract (stx-transfer? price tx-sender buyer-addr)))
                            (map-set escrows
                              { listing-id: escrow-id }
                              { buyer: buyer-addr
                              , amount: price
                              , created-at-block: (get created-at-block escrow)
                              , state: "released"
                              , timeout-block: (get timeout-block escrow) })
                            (map-delete listings { id: escrow-id })
                            (ok true)))
                      ERR_ESCROW_NOT_FOUND))
                    true)
                  ;; Seller wins - release to seller
                  (begin
                    ;; Mark dispute as resolved
                    (map-set disputes
                      { id: dispute-id }
                      { escrow-id: escrow-id
                      , created-by: (get created-by dispute)
                      , reason: (get reason dispute)
                      , created-at-block: (get created-at-block dispute)
                      , resolved: true
                      , buyer-stakes: buyer-stakes
                      , seller-stakes: seller-stakes
                      , resolution: (some "seller") })
                    ;; Release to seller from contract
                    (try! (match (map-get? escrows { listing-id: escrow-id })
                      escrow
                        (match (map-get? listings { id: escrow-id })
                          listing
                            (let ((price (get amount escrow))
                                  (seller (get seller listing))
                                  (royalty-bips (get royalty-bips listing))
                                  (royalty-recipient (get royalty-recipient listing))
                                  (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                                  (seller-share (- price royalty)))
                              (begin
                                ;; Transfer from contract
                                (if (> royalty u0)
                                  (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
                                  true)
                                (try! (as-contract (stx-transfer? seller-share tx-sender seller)))
                                (map-set escrows
                                  { listing-id: escrow-id }
                                  { buyer: (get buyer escrow)
                                  , amount: price
                                  , created-at-block: (get created-at-block escrow)
                                  , state: "released"
                                  , timeout-block: (get timeout-block escrow) })
                                (map-delete listings { id: escrow-id })
                                (ok true)))
                          ERR_NOT_FOUND)
                      ERR_ESCROW_NOT_FOUND))
                    true)))
                (ok true)))))
    ERR_DISPUTE_NOT_FOUND))

(define-public (claim-dispute-stake (dispute-id uint))
  (match (map-get? disputes { id: dispute-id })
    dispute
      (match (map-get? dispute-stakes { dispute-id: dispute-id, staker: tx-sender })
        stake
          (let ((resolution (unwrap! (get resolution dispute) ERR_DISPUTE_NOT_FOUND))
                (my-side (if (get side stake) "buyer" "seller")))
            (begin
              (asserts! (get resolved dispute) ERR_INVALID_STATE)
              ;; If I voted for the winner, I get my stake back
              ;; (Simplified: no reward from loser stakes yet, just refund)
              (asserts! (is-eq resolution my-side) ERR_INVALID_SIDE)
              
              (try! (as-contract (stx-transfer? (get amount stake) tx-sender (get staker stake))))
              
              ;; Clear stake to prevent double claim
              (map-delete dispute-stakes { dispute-id: dispute-id, staker: tx-sender })
              (ok true)))
        ERR_NOT_FOUND)
    ERR_DISPUTE_NOT_FOUND))

(define-read-only (get-bundle (bundle-id uint))
  (match (map-get? bundles { id: bundle-id })
    bundle (ok bundle)
    ERR_BUNDLE_NOT_FOUND))

(define-read-only (get-pack (pack-id uint))
  (match (map-get? packs { id: pack-id })
    pack (ok pack)
    ERR_PACK_NOT_FOUND))

;; Create a bundle of listings with discount
(define-public (create-bundle (listing-ids (list 10 uint)) (discount-bips uint))
  (begin
    ;; Validate bundle not empty
    (asserts! (> (len listing-ids) u0) ERR_BUNDLE_EMPTY)
    ;; Validate discount within limits
    (asserts! (<= discount-bips MAX_DISCOUNT_BIPS) ERR_BAD_ROYALTY)
    ;; Validate all listings exist and belong to creator
    ;; Note: In full implementation, would validate each listing
    (let ((bundle-id (var-get next-bundle-id)))
      (begin
        (map-set bundles
          { id: bundle-id }
          { listing-ids: listing-ids
          , discount-bips: discount-bips
          , creator: tx-sender
          , created-at-block: u0 })
        (var-set next-bundle-id (+ bundle-id u1))
        (ok bundle-id)))))

;; Buy a bundle (creates escrows for all listings in bundle with discount)
(define-public (buy-bundle (bundle-id uint))
  (match (map-get? bundles { id: bundle-id })
    bundle
      (let ((listing-ids (get listing-ids bundle))
            (discount-bips (get discount-bips bundle)))
        (begin
          ;; Loop through listings and create escrows
          ;; We use fold to iterate and accumulate result
          (try! (fold create-bundle-escrow listing-ids (ok { discount: discount-bips, buyer: tx-sender })))
          
          ;; Delete bundle after purchase
          (map-delete bundles { id: bundle-id })
          (ok true)))
    ERR_BUNDLE_NOT_FOUND))

;; Helper to create escrow for a listing in a bundle
(define-private (create-bundle-escrow (listing-id uint) (context (response { discount: uint, buyer: principal } uint)))
   (match context
     ctx 
       (match (map-get? listings { id: listing-id })
         listing
            (let ((price (get price listing))
                  (discount (get discount ctx))
                  (buyer (get buyer ctx))
                  (discounted-price (/ (* price (- BPS_DENOMINATOR discount)) BPS_DENOMINATOR)))
              (begin
                 ;; Transfer discounted price to contract
                 (try! (stx-transfer? discounted-price buyer (as-contract tx-sender)))
                 
                 ;; Create escrow
                 (map-set escrows
                   { listing-id: listing-id }
                   { buyer: buyer
                   , amount: discounted-price
                   , created-at-block: burn-block-height
                   , state: "pending"
                   , timeout-block: (+ burn-block-height ESCROW_TIMEOUT_BLOCKS) })
                 (ok ctx)))
         ERR_NOT_FOUND)
     error error))



;; Create a curated pack
(define-public (create-curated-pack (listing-ids (list 20 uint)) (pack-price uint) (curator principal))
  (begin
    ;; Validate pack not empty
    (asserts! (> (len listing-ids) u0) ERR_BUNDLE_EMPTY)
    ;; Validate curator is tx-sender
    (asserts! (is-eq tx-sender curator) ERR_NOT_OWNER)
    ;; Validate all listings exist
    ;; Note: In full implementation, would validate each listing
    (let ((pack-id (var-get next-pack-id)))
      (begin
        (map-set packs
          { id: pack-id }
          { listing-ids: listing-ids
          , price: pack-price
          , curator: curator
          , created-at-block: u0 })
        (var-set next-pack-id (+ pack-id u1))
        (ok pack-id)))))

;; Buy a curated pack
(define-public (buy-curated-pack (pack-id uint))
  (match (map-get? packs { id: pack-id })
    pack
      (let ((listing-ids (get listing-ids pack))
            (pack-price (get price pack))
            (curator (get curator pack)))
        (begin
          ;; Transfer payment to curator (simplified - in full would split)
          (try! (stx-transfer? pack-price tx-sender curator))
          ;; Process each listing purchase
          (process-pack-purchases listing-ids tx-sender)
          ;; Delete pack after purchase
          (map-delete packs { id: pack-id })
          (ok true)))
    ERR_PACK_NOT_FOUND))

;; Helper function to process pack purchases
(define-private (process-pack-purchases (listing-ids (list 20 uint)) (buyer principal))
  ;; Note: Simplified - in full implementation would process each listing
  true)
(define-read-only (get-listings-by-seller (seller principal)) (ok (list)))
(define-read-only (get-formatted-reputation (user principal)) (let ((rep (unwrap! (get-seller-reputation user) (err u0)))) (ok rep)))
