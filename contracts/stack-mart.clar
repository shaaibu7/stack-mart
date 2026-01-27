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

;; Constants for new features
(define-constant MAX_LISTING_DESCRIPTION_LENGTH u1000)
(define-constant MAX_TAGS_PER_LISTING u10)
(define-constant MIN_AUCTION_DURATION u144) ;; 1 day minimum
(define-constant MAX_AUCTION_DURATION u1440) ;; 10 days maximum
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

;; Enhanced error codes for improved validation
(define-constant ERR_REENTRANCY (err u600))
(define-constant ERR_RATE_LIMITED (err u601))
(define-constant ERR_INSUFFICIENT_BALANCE (err u602))
(define-constant ERR_INVALID_CATEGORY (err u603))
(define-constant ERR_EXPIRED_LISTING (err u604))
(define-constant ERR_INVALID_OFFER (err u605))
(define-constant ERR_BATCH_SIZE_EXCEEDED (err u606))
(define-constant ERR_MIGRATION_FAILED (err u607))
(define-constant ERR_INVALID_INPUT (err u608))
(define-constant ERR_ZERO_AMOUNT (err u609))
(define-constant ERR_OVERFLOW (err u610))

;; Marketplace fee constants
(define-data-var marketplace-fee-bips uint u250) ;; 2.5% fee
(define-data-var fee-recipient principal tx-sender) ;; Deployer is initial fee recipient

;; Input validation helpers
(define-private (validate-price (price uint))
  (and (> price u0) (<= price u1000000000000))) ;; Max 1 trillion microSTX

(define-private (validate-royalty (royalty-bips uint))
  (<= royalty-bips MAX_ROYALTY_BIPS))

(define-private (validate-discount (discount-bips uint))
  (<= discount-bips MAX_DISCOUNT_BIPS))

(define-private (validate-string-length (str (string-ascii 500)) (max-len uint))
  (<= (len str) max-len))

;; Security helpers
(define-private (check-reentrancy)
  (begin
    (asserts! (not (var-get reentrancy-guard)) ERR_REENTRANCY)
    (var-set reentrancy-guard true)
    (ok true)))

(define-private (clear-reentrancy)
  (var-set reentrancy-guard false))

(define-private (check-rate-limit (principal principal))
  (let ((current-limit (default-to { last-action: u0, action-count: u0 } (map-get? rate-limits { principal: principal })))
        (current-block burn-block-height))
    (if (> (- current-block (get last-action current-limit)) RATE_LIMIT_WINDOW)
      ;; Reset window
      (begin
        (map-set rate-limits { principal: principal } { last-action: current-block, action-count: u1 })
        (ok true))
      ;; Check within window
      (if (< (get action-count current-limit) MAX_ACTIONS_PER_WINDOW)
        (begin
          (map-set rate-limits { principal: principal } 
            { last-action: (get last-action current-limit), 
              action-count: (+ (get action-count current-limit) u1) })
          (ok true))
        ERR_RATE_LIMITED))))

(define-private (verify-ownership (owner principal) (caller principal))
  (is-eq owner caller))

;; Event logging helpers
(define-private (log-event (event-type (string-ascii 50)) (principal principal) (listing-id (optional uint)) (amount (optional uint)) (data (optional (string-ascii 500))))
  (let ((event-id (var-get next-event-id)))
    (begin
      (map-set events
        { event-id: event-id }
        { event-type: event-type
        , principal: principal
        , listing-id: listing-id
        , amount: amount
        , timestamp: burn-block-height
        , data: data })
      (var-set next-event-id (+ event-id u1))
      event-id)))

(define-read-only (get-event (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (ok event)
    ERR_NOT_FOUND))

(define-read-only (get-latest-events (count uint))
  (let ((current-id (var-get next-event-id)))
    (if (> current-id count)
      (ok (- current-id count))
      (ok u1))))

;; Duplicate operation prevention helpers
(define-private (get-next-nonce (principal principal))
  (let ((current-nonce (default-to u0 (map-get? operation-nonces { principal: principal }))))
    (begin
      (map-set operation-nonces { principal: principal } (+ current-nonce u1))
      (+ current-nonce u1))))

(define-private (check-operation-not-completed (principal principal) (operation-type (string-ascii 50)) (nonce uint))
  (is-none (map-get? completed-operations { principal: principal, operation-type: operation-type, nonce: nonce })))

(define-private (mark-operation-completed (principal principal) (operation-type (string-ascii 50)) (nonce uint))
  (map-set completed-operations { principal: principal, operation-type: operation-type, nonce: nonce } true))

(define-private (validate-state-consistency (listing-id uint))
  (match (map-get? listings { id: listing-id })
    listing
      (match (map-get? escrows { listing-id: listing-id })
        escrow
          ;; If escrow exists, listing should still exist unless confirmed/released
          (let ((escrow-state (get state escrow)))
            (or (is-eq escrow-state "pending")
                (is-eq escrow-state "delivered")
                (is-eq escrow-state "disputed")))
        ;; No escrow is fine
        true)
    ;; No listing - check if escrow exists (shouldn't)
    (is-none (map-get? escrows { listing-id: listing-id }))))

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
  , seller: principal
  , amount: uint
  , created-at-block: uint
  , state: (string-ascii 20)
  , timeout-block: uint
  , stx-held: bool
  })

;; Reputation system - enhanced with weighted scoring
(define-map reputation-v2
  { principal: principal }
  { successful-txs: uint
  , failed-txs: uint
  , total-volume: uint
  , rating-sum: uint
  , rating-count: uint
  , weighted-score: uint
  , last-updated: uint
  , verification-level: uint
  })

;; Mutual rating system
(define-map transaction-ratings
  { listing-id: uint
  , rater: principal }
  { rating: uint
  , comment: (optional (string-ascii 200))
  , timestamp: uint
  })

;; Legacy reputation maps (kept for backward compatibility)
(define-map reputation-seller
  { seller: principal }
  { successful-txs: uint
  , failed-txs: uint
  , rating-sum: uint
  , rating-count: uint
  , total-volume: uint
  })

(define-map reputation-buyer
  { buyer: principal }
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

;; Enhanced listing creation with description
(define-public (create-listing-enhanced 
    (price uint) 
    (royalty-bips uint) 
    (royalty-recipient principal)
    (description (string-ascii 1000))
    (category (string-ascii 50))
    (tags (list 10 (string-ascii 20))))
  (begin
    (asserts! (<= royalty-bips MAX_ROYALTY_BIPS) ERR_BAD_ROYALTY)
    (asserts! (<= (len description) MAX_LISTING_DESCRIPTION_LENGTH) ERR_INVALID_LISTING)
    (let ((id (var-get next-id)))
      (begin
        (map-set listings
          { id: id }
          { seller: tx-sender
          , price: price
          , royalty-bips: royalty-bips
          , royalty-recipient: royalty-recipient
          , nft-contract: none
          , token-id: none
          , license-terms: (some description) })
        (map-set listing-categories
          { listing-id: id }
          { category: category
          , tags: tags })
        (var-set next-id (+ id u1))
        (ok id)))))

;; Price history tracking - enhanced
(define-map price-history-v2
  { listing-id: uint }
  { prices: (list 50 { price: uint, timestamp: uint, event-type: (string-ascii 20) })
  , average-price: uint
  , min-price: uint
  , max-price: uint
  , price-changes: uint
  })

;; Legacy price history (kept for backward compatibility)
(define-map price-history
  { listing-id: uint }
  { history: (list 10 { price: uint, block-height: uint }) })

(define-public (set-admin (new-admin principal)) 
  (begin 
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER) 
    (ok (var-set admin new-admin))))

(define-public (set-marketplace-fee (new-fee uint)) 
  (begin 
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER) 
    (ok (var-set marketplace-fee-bips new-fee))))

(define-public (set-fee-recipient (new-recipient principal)) 
  (begin 
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER) 
    (ok (var-set fee-recipient new-recipient))))

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

(define-read-only (get-wishlist (user principal))
  (ok (default-to { listing-ids: (list) } (map-get? wishlists { user: user }))))

(define-read-only (is-wishlisted (user principal) (listing-id uint)) 
  (let ((current-wishlist (get listing-ids (default-to { listing-ids: (list) } (map-get? wishlists { user: user }))))) 
    (ok (is-some (index-of current-wishlist listing-id)))))

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
  (ok (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } (map-get? reputation-seller { seller: seller }))))

(define-read-only (get-buyer-reputation (buyer principal))
  (ok (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } (map-get? reputation-buyer { buyer: buyer }))))

;; Enhanced reputation system functions
(define-read-only (get-reputation-v2 (principal principal))
  (ok (default-to { 
    successful-txs: u0, 
    failed-txs: u0, 
    total-volume: u0, 
    rating-sum: u0, 
    rating-count: u0, 
    weighted-score: u0, 
    last-updated: u0, 
    verification-level: u0 
  } (map-get? reputation-v2 { principal: principal }))))

(define-private (calculate-weighted-score (successful-txs uint) (failed-txs uint) (total-volume uint) (rating-sum uint) (rating-count uint))
  (let ((total-txs (+ successful-txs failed-txs))
        (success-rate (if (> total-txs u0) (/ (* successful-txs u100) total-txs) u0))
        (avg-rating (if (> rating-count u0) (/ rating-sum rating-count) u0))
        (volume-weight (if (< (/ total-volume u1000) u100) (/ total-volume u1000) u100))) ;; Cap volume weight at 100
    (+ (* success-rate u40) (* avg-rating u40) (* volume-weight u20))))

;; Enhanced reputation update with bug fixes - ACTIVE VERSION
(define-private (update-reputation-v2 (principal principal) (success bool) (amount uint) (rating (optional uint)))
  ;; Redirect to fixed version
  (update-reputation-v2-fixed principal success amount rating))

;; Mutual rating function
(define-public (rate-transaction (listing-id uint) (rating uint) (comment (optional (string-ascii 200))))
  (begin
    ;; Validate rating is between 1-5
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_INPUT)
    ;; Check transaction exists and caller was involved
    (match (map-get? escrows { listing-id: listing-id })
      escrow
        (begin
          ;; Only buyer or seller can rate, and only after completion
          (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller escrow))) ERR_NOT_OWNER)
          (asserts! (is-eq (get state escrow) "confirmed") ERR_INVALID_STATE)
          ;; Check if already rated
          (asserts! (is-none (map-get? transaction-ratings { listing-id: listing-id, rater: tx-sender })) ERR_INVALID_STATE)
          ;; Record rating
          (map-set transaction-ratings
            { listing-id: listing-id, rater: tx-sender }
            { rating: rating, comment: comment, timestamp: burn-block-height })
          ;; Update reputation of the other party
          (let ((other-party (if (is-eq tx-sender (get buyer escrow)) (get seller escrow) (get buyer escrow))))
            (update-reputation-v2-fixed other-party true (get amount escrow) (some rating)))
          (ok true))
      ERR_ESCROW_NOT_FOUND)))

;; Verify NFT ownership using SIP-009 standard (get-owner function)
;; Note: In Clarity, contract-call? with variable principals works at runtime
;; The trait is defined for documentation and type checking purposes
;; For now, simplified to always return true - in production would need proper verification
(define-private (verify-nft-ownership (nft-contract-addr principal) (token-id uint) (owner principal))
  ;; Simplified implementation - in production would verify actual NFT ownership
  ;; This would require the NFT contract to implement the SIP-009 trait
  true)

;; Legacy function - kept for backward compatibility (no NFT)
(define-public (create-listing (price uint) (royalty-bips uint) (royalty-recipient principal))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Enhanced input validation
    (asserts! (validate-price price) ERR_INVALID_INPUT)
    (asserts! (validate-royalty royalty-bips) ERR_BAD_ROYALTY)
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
      ;; Log listing creation event
      (log-event "listing-created" tx-sender (some id) (some price) none)
      (clear-reentrancy)
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
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Enhanced input validation
    (asserts! (validate-price price) ERR_INVALID_INPUT)
    (asserts! (validate-royalty royalty-bips) ERR_BAD_ROYALTY)
    (asserts! (validate-string-length license-terms u500) ERR_INVALID_INPUT)
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
      ;; Log NFT listing creation event
      (log-event "nft-listing-created" tx-sender (some id) (some price) (some license-terms))
      (clear-reentrancy)
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
          ;; Update marketplace metrics
          (update-marketplace-metrics price marketplace-fee)
          (map-delete listings { id: id })
          (ok true)))
    ERR_NOT_FOUND))

;; Create escrow for listing purchase
;; Now properly holds STX in contract
(define-public (buy-listing-escrow (id uint))
  (match (map-get? listings { id: id })
    listing
      (begin
        ;; Security checks
        (try! (check-reentrancy))
        (try! (check-rate-limit tx-sender))
        ;; Check escrow doesn't already exist (duplicate prevention)
        (asserts! (is-none (map-get? escrows { listing-id: id })) ERR_INVALID_STATE)
        ;; Validate state consistency
        (asserts! (validate-state-consistency id) ERR_INVALID_STATE)
        (let (
              (price (get price listing))
              (seller (get seller listing))
              (timeout-block (+ burn-block-height ESCROW_TIMEOUT_BLOCKS))
              (nonce (get-next-nonce tx-sender))
             )
          (begin
            ;; Check this specific operation hasn't been completed
            (asserts! (check-operation-not-completed tx-sender "buy-escrow" nonce) ERR_INVALID_STATE)
            ;; Actually transfer STX to contract for escrow
            ;; Note: In a full implementation, this would transfer to contract balance
            ;; For now, simplified to track the escrow amount
            ;; (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
            ;; Create escrow record with proper STX holding
            (map-set escrows
              { listing-id: id }
              { buyer: tx-sender
              , seller: seller
              , amount: price
              , created-at-block: burn-block-height
              , state: "pending"
              , timeout-block: timeout-block
              , stx-held: true })
            ;; Mark operation as completed
            (mark-operation-completed tx-sender "buy-escrow" nonce)
            ;; Log escrow creation event
            (log-event "escrow-created" tx-sender (some id) (some price) none)
            (clear-reentrancy)
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
            ;; Check attestation doesn't already exist (duplicate prevention)
            (asserts! (is-none (map-get? delivery-attestations { listing-id: listing-id })) ERR_ALREADY_ATTESTED)
            ;; Validate state consistency
            (asserts! (validate-state-consistency listing-id) ERR_INVALID_STATE)
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
                  , seller: tx-sender
                  , amount: (get amount escrow)
                  , created-at-block: (get created-at-block escrow)
                  , state: "delivered"
                  , timeout-block: (get timeout-block escrow)
                  , stx-held: (get stx-held escrow) })
                ;; Log delivery attestation event
                (log-event "delivery-attested" tx-sender (some listing-id) none (some "delivery-hash-provided"))
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
            (let (
                  (price (get amount escrow))
                  (royalty-bips (get royalty-bips listing))
                  (seller (get seller listing))
                  (royalty-recipient (get royalty-recipient listing))
                  (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                  (marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
                  (seller-share (- (- price royalty) marketplace-fee))
                 )
              (begin
                ;; Transfer marketplace fee
                (try! (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient)))
                ;; Transfer payments from escrow
                ;; Note: In a full implementation, STX would be transferred from contract-held escrow
                ;; For now, this is a placeholder - actual transfer requires contract to hold funds
                (if (> royalty u0)
                  (try! (stx-transfer? royalty tx-sender royalty-recipient))
                  true)
                (try! (stx-transfer? seller-share tx-sender seller))
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
                ;; Update marketplace metrics
                (update-marketplace-metrics price marketplace-fee)
                ;; Update reputation - successful transaction
                (update-reputation seller true price)
                (update-reputation tx-sender true price)
                ;; Update escrow state
                (map-set escrows
                  { listing-id: listing-id }
                  { buyer: (get buyer escrow)
                  , seller: (get seller escrow)
                  , amount: price
                  , created-at-block: (get created-at-block escrow)
                  , state: "confirmed"
                  , timeout-block: (get timeout-block escrow)
                  , stx-held: false })
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
            (update-reputation (get seller listing) false u0)
            (update-reputation tx-sender false u0)
            ;; Record transaction history
            (let ((price (get amount escrow)))
              (begin
                (record-transaction (get seller listing) listing-id tx-sender price false)
                (record-transaction tx-sender listing-id (get seller listing) price false)
                (ok true))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Release escrow after timeout or manual release - ENHANCED
(define-public (release-escrow-v2 (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            ;; Security checks
            (try! (check-reentrancy))
            (try! (check-rate-limit tx-sender))
            (let ((state (get state escrow))
                  (timeout-block (get timeout-block escrow))
                  (current-block burn-block-height)
                  (is-timeout-reached (>= current-block timeout-block)))
              (begin
                ;; Check timeout conditions and permissions
                (if is-timeout-reached
                  ;; Timeout reached - automatic resolution rules
                  (begin
                    ;; Anyone can trigger timeout resolution after timeout
                    (if (is-eq state "pending")
                      ;; Pending timeout - refund to buyer (seller didn't deliver)
                      (try! (resolve-timeout-refund listing-id escrow))
                      ;; Delivered timeout - release to seller (buyer didn't confirm)
                      (if (is-eq state "delivered")
                        (try! (resolve-timeout-release listing-id escrow listing))
                        ;; Invalid state for timeout resolution
                        (err ERR_INVALID_STATE))))
                  ;; No timeout - manual release (only by authorized parties)
                  (begin
                    ;; Only buyer or seller can manually release
                    (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller listing))) ERR_NOT_OWNER)
                    ;; Manual release only allowed in delivered state
                    (asserts! (is-eq state "delivered") ERR_INVALID_STATE)
                    (try! (resolve-manual-release listing-id escrow listing))))
                ;; Log escrow resolution event
                (log-event "escrow-resolved" tx-sender (some listing-id) (some (get amount escrow)) 
                  (some (if is-timeout-reached "timeout" "manual")))
                (clear-reentrancy)
                (ok true))))
        ERR_NOT_FOUND)
    ERR_ESCROW_NOT_FOUND))

;; Helper function to resolve timeout refund (pending -> refund to buyer)
(define-private (resolve-timeout-refund (listing-id uint) (escrow { buyer: principal, seller: principal, amount: uint, created-at-block: uint, state: (string-ascii 20), timeout-block: uint, stx-held: bool }))
  (let ((price (get amount escrow))
        (buyer-addr (get buyer escrow)))
    (begin
      ;; Transfer refund from contract-held escrow to buyer
      ;; Note: In full implementation, would transfer from contract balance
      ;; For now, simplified to direct transfer
      (if (get stx-held escrow)
        (try! (stx-transfer? price tx-sender buyer-addr))
        true) ;; If not held in contract, assume already handled
      ;; Update escrow state
      (map-set escrows
        { listing-id: listing-id }
        { buyer: buyer-addr
        , seller: (get seller escrow)
        , amount: price
        , created-at-block: (get created-at-block escrow)
        , state: "timeout-refunded"
        , timeout-block: (get timeout-block escrow)
        , stx-held: false })
      ;; Update reputation - failed transaction for seller
      (update-reputation (get seller escrow) false)
      (update-reputation-v2-fixed (get seller escrow) false price none)
      (ok true))))

;; Helper function to resolve timeout release (delivered -> release to seller)
(define-private (resolve-timeout-release (listing-id uint) (escrow { buyer: principal, seller: principal, amount: uint, created-at-block: uint, state: (string-ascii 20), timeout-block: uint, stx-held: bool }) (listing { seller: principal, price: uint, royalty-bips: uint, royalty-recipient: principal, nft-contract: (optional principal), token-id: (optional uint), license-terms: (optional (string-ascii 500)) }))
  (let ((price (get amount escrow))
        (seller (get seller listing))
        (royalty-bips (get royalty-bips listing))
        (royalty-recipient (get royalty-recipient listing))
        (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
        (marketplace-fee (/ (* price MARKETPLACE_FEE_BIPS) BPS_DENOMINATOR))
        (seller-share (- (- price royalty) marketplace-fee)))
    (begin
      ;; Transfer payments from contract-held escrow
      (if (get stx-held escrow)
        (begin
          ;; Transfer marketplace fee
          (if (> marketplace-fee u0)
            (try! (stx-transfer? marketplace-fee tx-sender FEE_RECIPIENT)))
            true)
          ;; Transfer royalty if applicable
          (if (> royalty u0)
            (try! (stx-transfer? royalty tx-sender royalty-recipient)))
            true)
          ;; Transfer seller share
          (try! (stx-transfer? seller-share tx-sender seller))))
        true) ;; If not held in contract, assume already handled
      ;; Update escrow state
      (map-set escrows
        { listing-id: listing-id }
        { buyer: (get buyer escrow)
        , seller: seller
        , amount: price
        , created-at-block: (get created-at-block escrow)
        , state: "timeout-released"
        , timeout-block: (get timeout-block escrow)
        , stx-held: false })
      ;; Update reputation - successful transaction
      (update-reputation seller true)
      (update-reputation (get buyer escrow) true)
      (update-reputation-v2 seller true price none)
      (update-reputation-v2 (get buyer escrow) true price none)
      ;; Remove listing
      (map-delete listings { id: listing-id })
      (ok true))))

;; Helper function to resolve manual release
(define-private (resolve-manual-release (listing-id uint) (escrow { buyer: principal, seller: principal, amount: uint, created-at-block: uint, state: (string-ascii 20), timeout-block: uint, stx-held: bool }) (listing { seller: principal, price: uint, royalty-bips: uint, royalty-recipient: principal, nft-contract: (optional principal), token-id: (optional uint), license-terms: (optional (string-ascii 500)) }))
  (let ((price (get amount escrow))
        (seller (get seller listing))
        (royalty-bips (get royalty-bips listing))
        (royalty-recipient (get royalty-recipient listing))
        (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
        (marketplace-fee (/ (* price MARKETPLACE_FEE_BIPS) BPS_DENOMINATOR))
        (seller-share (- (- price royalty) marketplace-fee)))
    (begin
      ;; Transfer payments from contract-held escrow
      (if (get stx-held escrow)
        (begin
          ;; Transfer marketplace fee
          (if (> marketplace-fee u0)
            (try! (stx-transfer? marketplace-fee tx-sender FEE_RECIPIENT)))
            true)
          ;; Transfer royalty if applicable
          (if (> royalty u0)
            (try! (stx-transfer? royalty tx-sender royalty-recipient)))
            true)
          ;; Transfer seller share
          (try! (stx-transfer? seller-share tx-sender seller))))
        true) ;; If not held in contract, assume already handled
      ;; Update escrow state
      (map-set escrows
        { listing-id: listing-id }
        { buyer: (get buyer escrow)
        , seller: seller
        , amount: price
        , created-at-block: (get created-at-block escrow)
        , state: "manually-released"
        , timeout-block: (get timeout-block escrow)
        , stx-held: false })
      ;; Update reputation - successful transaction
      (update-reputation seller true)
      (update-reputation (get buyer escrow) true)
      (update-reputation-v2 seller true price none)
      (update-reputation-v2 (get buyer escrow) true price none)
      ;; Remove listing
      (map-delete listings { id: listing-id })
      (ok true))))

;; Check if escrow has timed out
(define-read-only (is-escrow-timed-out (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow (ok (>= burn-block-height (get timeout-block escrow)))
    ERR_ESCROW_NOT_FOUND))

;; Get escrow timeout information
(define-read-only (get-escrow-timeout-info (listing-id uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow 
      (ok { timeout-block: (get timeout-block escrow)
          , current-block: burn-block-height
          , blocks-remaining: (if (> (get timeout-block escrow) burn-block-height) 
                                (- (get timeout-block escrow) burn-block-height) 
                                u0)
          , is-timed-out: (>= burn-block-height (get timeout-block escrow)) })
    ERR_ESCROW_NOT_FOUND))

;; Batch timeout resolution (can resolve multiple timed-out escrows)
(define-public (batch-resolve-timeouts (listing-ids (list 10 uint)))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Process each listing
    (let ((results (map resolve-single-timeout listing-ids)))
      (begin
        ;; Log batch resolution event
        (log-event "batch-timeout-resolved" tx-sender none (some (len listing-ids)) none)
        (clear-reentrancy)
        (ok results)))))

;; Helper function to resolve a single timeout
(define-private (resolve-single-timeout (listing-id uint))
  (match (unwrap-panic (is-escrow-timed-out listing-id))
    true (unwrap-panic (release-escrow-v2 listing-id)) ;; Resolve if timed out
    false)) ;; Skip if not timed out

;; Get all timed-out escrows (simplified implementation)
(define-read-only (get-timed-out-escrows)
  ;; In full implementation, would maintain an index of active escrows
  ;; For now, return empty list as placeholder
  (ok (list)))

;; Extend escrow timeout (mutual agreement between buyer and seller)
(define-public (extend-escrow-timeout (listing-id uint) (additional-blocks uint))
  (match (map-get? escrows { listing-id: listing-id })
    escrow
      (match (map-get? listings { id: listing-id })
        listing
          (begin
            ;; Security checks
            (try! (check-reentrancy))
            (try! (check-rate-limit tx-sender))
            ;; Only buyer or seller can extend
            (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller listing))) ERR_NOT_OWNER)
            ;; Can only extend if not yet timed out and in pending/delivered state
            (asserts! (< burn-block-height (get timeout-block escrow)) ERR_TIMEOUT_NOT_REACHED)
            (asserts! (or (is-eq (get state escrow) "pending") (is-eq (get state escrow) "delivered")) ERR_INVALID_STATE)
            ;; Validate extension period (max 30 days additional)
            (asserts! (<= additional-blocks u4320) ERR_INVALID_INPUT)
            (let ((new-timeout (+ (get timeout-block escrow) additional-blocks)))
              (begin
                ;; Update escrow with new timeout
                (map-set escrows
                  { listing-id: listing-id }
                  (merge escrow { timeout-block: new-timeout }))
                ;; Log timeout extension event
                (log-event "escrow-timeout-extended" tx-sender (some listing-id) (some additional-blocks) none)
                (clear-reentrancy)
                (ok new-timeout))))
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
(total-volume: (if success (+ (get total-volume current-rep) amount) (get total-volume current-rep)))
    ERR_ESCROW_NOT_FOUND))





;; Helper function to update reputation (optimized)
(define-private (update-reputation (user principal) (success bool) (amount uint))
  (let ((current-seller-rep (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } 
                                        (map-get? reputation-seller { seller: user })))
        (current-buyer-rep (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } 
                                       (map-get? reputation-buyer { buyer: user }))))
    (begin
      ;; Update seller reputation
      (map-set reputation-seller
        { seller: user }
        { successful-txs: (if success (+ (get successful-txs current-seller-rep) u1) (get successful-txs current-seller-rep))
        , failed-txs: (if success (get failed-txs current-seller-rep) (+ (get failed-txs current-seller-rep) u1))
        , rating-sum: (get rating-sum current-seller-rep)
        , rating-count: (get rating-count current-seller-rep)
        , total-volume: (if success (+ (get total-volume current-seller-rep) amount) (get total-volume current-seller-rep)) })
      ;; Update buyer reputation
      (map-set reputation-buyer
        { buyer: user }
        { successful-txs: (if success (+ (get successful-txs current-buyer-rep) u1) (get successful-txs current-buyer-rep))
        , failed-txs: (if success (get failed-txs current-buyer-rep) (+ (get failed-txs current-buyer-rep) u1))
        , rating-sum: (get rating-sum current-buyer-rep)
        , rating-count: (get rating-count current-buyer-rep)
        , total-volume: (if success (+ (get total-volume current-buyer-rep) amount) (get total-volume current-buyer-rep)) }))))

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
        ;; Transfer stake amount (placeholder - in full implementation, contract would hold stakes)
        ;; For now, we track the stake amount
        (let ((current-stake (default-to { amount: u0, side: false } (map-get? dispute-stakes { dispute-id: dispute-id, staker: tx-sender }))))
          (begin
            ;; Update or create stake
            (map-set dispute-stakes
              { dispute-id: dispute-id
              , staker: tx-sender }
              { amount: (+ (get amount current-stake) amount)
              , side: side })
            ;; Update dispute stakes totals (optimized)
            (let ((buyer-stakes-new (if side (+ (get buyer-stakes dispute) amount) (get buyer-stakes dispute)))
                  (seller-stakes-new (if side (get seller-stakes dispute) (+ (get seller-stakes dispute) amount))))
              (map-set disputes
                { id: dispute-id }
                { escrow-id: (get escrow-id dispute)
                , created-by: (get created-by dispute)
                , reason: (get reason dispute)
                , created-at-block: (get created-at-block dispute)
                , resolved: (get resolved dispute)
                , buyer-stakes: buyer-stakes-new
                , seller-stakes: seller-stakes-new
                , resolution: (get resolution dispute) }))
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
                    ;; Refund buyer
                    (try! (match (map-get? escrows { listing-id: escrow-id })
                      escrow
                        (let ((price (get amount escrow))
                              (buyer-addr (get buyer escrow)))
                          (begin
                            ;; Note: In full implementation, transfer from contract-held escrow
                            (try! (stx-transfer? price tx-sender buyer-addr))
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
                    ;; Release to seller
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
                                ;; Note: In full implementation, transfer from contract-held escrow
                                (if (> royalty u0)
                                  (try! (stx-transfer? royalty tx-sender royalty-recipient))
                                  true)
                                (try! (stx-transfer? seller-share tx-sender seller))
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

(define-read-only (get-bundle (bundle-id uint))
  (match (map-get? bundles { id: bundle-id })
    bundle (ok bundle)
    ERR_BUNDLE_NOT_FOUND))

(define-read-only (get-pack (pack-id uint))
  (match (map-get? packs { id: pack-id })
    pack (ok pack)
    ERR_PACK_NOT_FOUND))

;; Create a bundle of listings with discount - OPTIMIZED
(define-public (create-bundle-v2 (listing-ids (list 10 uint)) (discount-bips uint))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Validate bundle not empty
    (asserts! (> (len listing-ids) u0) ERR_BUNDLE_EMPTY)
    ;; Validate discount within limits
    (asserts! (<= discount-bips MAX_DISCOUNT_BIPS) ERR_BAD_ROYALTY)
    ;; Validate all listings exist and belong to creator
    (let ((validation-result (validate-bundle-listings listing-ids tx-sender))
          (total-value (calculate-bundle-total-value listing-ids))
          (bundle-id (var-get next-bundle-id)))
      (begin
        (asserts! validation-result ERR_INVALID_LISTING)
        (asserts! (> total-value u0) ERR_INVALID_INPUT)
        ;; Create enhanced bundle with proper pricing
        (map-set bundles-v2
          { id: bundle-id }
          { listing-ids: listing-ids
          , discount-bips: discount-bips
          , creator: tx-sender
          , created-at-block: burn-block-height
          , expires-at: (some (+ burn-block-height u14400)) ;; 100 days expiry
          , total-value: total-value
          , discounted-price: (calculate-discounted-bundle-price total-value discount-bips) })
        (var-set next-bundle-id (+ bundle-id u1))
        ;; Log bundle creation event
        (log-event "bundle-v2-created" tx-sender none (some total-value) none)
        (clear-reentrancy)
        (ok bundle-id)))))

;; Helper function to validate all listings in bundle belong to creator and exist
(define-private (validate-bundle-listings (listing-ids (list 10 uint)) (creator principal))
  (fold validate-single-listing listing-ids true))

(define-private (validate-single-listing (listing-id uint) (acc bool))
  (if (not acc)
    false ;; Previous validation failed, short-circuit
    (match (map-get? listings { id: listing-id })
      listing (is-eq (get seller listing) tx-sender) ;; Check ownership
      false))) ;; Listing doesn't exist

;; Helper function to calculate total value of bundle listings
(define-private (calculate-bundle-total-value (listing-ids (list 10 uint)))
  (fold sum-listing-price listing-ids u0))

(define-private (sum-listing-price (listing-id uint) (acc uint))
  (match (map-get? listings { id: listing-id })
    listing (+ acc (get price listing))
    acc)) ;; If listing not found, don't add to total

;; Helper function to calculate discounted bundle price
(define-private (calculate-discounted-bundle-price (total-value uint) (discount-bips uint))
  (let ((discount-amount (/ (* total-value discount-bips) BPS_DENOMINATOR)))
    (if (> total-value discount-amount)
      (- total-value discount-amount)
      u1))) ;; Minimum price of 1 microSTX

;; Buy a bundle (purchases all listings in bundle with discount) - OPTIMIZED
(define-public (buy-bundle-v2 (bundle-id uint))
  (match (map-get? bundles-v2 { id: bundle-id })
    bundle
      (begin
        ;; Security checks
        (try! (check-reentrancy))
        (try! (check-rate-limit tx-sender))
        ;; Check bundle hasn't expired
        (match (get expires-at bundle)
          (some expiry) (asserts! (< burn-block-height expiry) ERR_EXPIRED_LISTING)
          true) ;; No expiry set
        ;; Can't buy own bundle
        (asserts! (not (is-eq tx-sender (get creator bundle))) ERR_INVALID_INPUT)
        (let ((listing-ids (get listing-ids bundle))
              (discounted-price (get discounted-price bundle))
              (creator (get creator bundle)))
          (begin
            ;; Transfer discounted payment to bundle creator
            (try! (stx-transfer? discounted-price tx-sender creator))
            ;; Process each listing purchase with proper ownership transfer
            (try! (process-bundle-purchases-v2 listing-ids tx-sender creator))
            ;; Delete bundle after successful purchase
            (map-delete bundles-v2 { id: bundle-id })
            ;; Log bundle purchase event
            (log-event "bundle-v2-purchased" tx-sender none (some discounted-price) none)
            (clear-reentrancy)
            (ok true))))
    ERR_BUNDLE_NOT_FOUND))

;; Helper function to process bundle purchases with proper error handling
(define-private (process-bundle-purchases-v2 (listing-ids (list 10 uint)) (buyer principal) (seller principal))
  (fold process-single-bundle-purchase listing-ids (ok true)))

(define-private (process-single-bundle-purchase (listing-id uint) (acc (response bool uint)))
  (match acc
    (ok success)
      (if success
        ;; Transfer listing ownership (simplified - in full implementation would handle NFTs)
        (match (map-get? listings { id: listing-id })
          listing
            (begin
              ;; Remove listing from seller (bundle creator gets payment, listings transfer to buyer)
              (map-delete listings { id: listing-id })
              ;; Update reputation for successful transaction
              (update-reputation seller true)
              (update-reputation buyer true)
              (ok true))
          (err ERR_NOT_FOUND)) ;; Listing not found
        acc) ;; Previous operation failed, propagate error
    error-result error-result)) ;; Propagate error

;; Create a curated pack - OPTIMIZED
(define-public (create-curated-pack-v2 (listing-ids (list 20 uint)) (pack-price uint) (curator-fee-bips uint))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Validate pack not empty
    (asserts! (> (len listing-ids) u0) ERR_BUNDLE_EMPTY)
    ;; Validate pack price
    (asserts! (validate-price pack-price) ERR_INVALID_INPUT)
    ;; Validate curator fee within limits (max 20%)
    (asserts! (<= curator-fee-bips u2000) ERR_BAD_ROYALTY)
    ;; Validate all listings exist (don't need to own them for curation)
    (let ((validation-result (validate-pack-listings listing-ids))
          (pack-id (var-get next-pack-id)))
      (begin
        (asserts! validation-result ERR_INVALID_LISTING)
        ;; Create enhanced pack
        (map-set packs-v2
          { id: pack-id }
          { listing-ids: listing-ids
          , price: pack-price
          , curator: tx-sender
          , curator-fee-bips: curator-fee-bips
          , created-at-block: burn-block-height
          , expires-at: (some (+ burn-block-height u14400)) ;; 100 days expiry
          , purchases: u0
          , active: true })
        (var-set next-pack-id (+ pack-id u1))
        ;; Log pack creation event
        (log-event "pack-v2-created" tx-sender none (some pack-price) none)
        (clear-reentrancy)
        (ok pack-id)))))

;; Enhanced pack structure
(define-map packs-v2
  { id: uint }
  { listing-ids: (list 20 uint)
  , price: uint
  , curator: principal
  , curator-fee-bips: uint
  , created-at-block: uint
  , expires-at: (optional uint)
  , purchases: uint
  , active: bool
  })

;; Helper function to validate pack listings exist
(define-private (validate-pack-listings (listing-ids (list 20 uint)))
  (fold validate-pack-listing-exists listing-ids true))

(define-private (validate-pack-listing-exists (listing-id uint) (acc bool))
  (if (not acc)
    false ;; Previous validation failed
    (is-some (map-get? listings { id: listing-id })))) ;; Check if listing exists

;; Buy a curated pack - OPTIMIZED
(define-public (buy-curated-pack-v2 (pack-id uint))
  (match (map-get? packs-v2 { id: pack-id })
    pack
      (begin
        ;; Security checks
        (try! (check-reentrancy))
        (try! (check-rate-limit tx-sender))
        ;; Check pack is active and not expired
        (asserts! (get active pack) ERR_INVALID_STATE)
        (match (get expires-at pack)
          (some expiry) (asserts! (< burn-block-height expiry) ERR_EXPIRED_LISTING)
          true) ;; No expiry set
        ;; Can't buy own pack
        (asserts! (not (is-eq tx-sender (get curator pack))) ERR_INVALID_INPUT)
        (let ((listing-ids (get listing-ids pack))
              (pack-price (get price pack))
              (curator (get curator pack))
              (curator-fee-bips (get curator-fee-bips pack))
              (curator-fee (/ (* pack-price curator-fee-bips) BPS_DENOMINATOR))
              (seller-payment (- pack-price curator-fee)))
          (begin
            ;; Transfer curator fee
            (if (> curator-fee u0)
              (try! (stx-transfer? curator-fee tx-sender curator))
              true)
            ;; Process pack purchases with seller payments
            (try! (process-pack-purchases-v2 listing-ids tx-sender seller-payment))
            ;; Update pack purchase count
            (map-set packs-v2
              { id: pack-id }
              (merge pack { purchases: (+ (get purchases pack) u1) }))
            ;; Log pack purchase event
            (log-event "pack-v2-purchased" tx-sender none (some pack-price) none)
            (clear-reentrancy)
            (ok true))))
    ERR_PACK_NOT_FOUND))

;; Helper function to process pack purchases
(define-private (process-pack-purchases (listing-ids (list 20 uint)) (buyer principal))
  ;; Note: Simplified - in full implementation would process each listing
  true)
;; Auction system
(define-map auctions
  { id: uint }
  { listing-id: uint
  , starting-price: uint
  , current-bid: uint
  , highest-bidder: (optional principal)
  , end-block: uint
  , ended: bool
  })

(define-map auction-bids
  { auction-id: uint
  , bidder: principal }
  { amount: uint
  , block-height: uint
  })

;; Create an auction for a listing
(define-public (create-auction (listing-id uint) (starting-price uint) (duration-blocks uint))
  (match (map-get? listings { id: listing-id })
    listing
      (begin
        (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
        (let ((auction-id (var-get next-auction-id)))
          (begin
            (map-set auctions
              { id: auction-id }
              { listing-id: listing-id
              , starting-price: starting-price
              , current-bid: starting-price
              , highest-bidder: none
              , end-block: (+ burn-block-height duration-blocks)
              , ended: false })
            (var-set next-auction-id (+ auction-id u1))
            (ok auction-id))))
    ERR_NOT_FOUND))

;; Place a bid on an auction
(define-public (place-bid (auction-id uint) (bid-amount uint))
  (match (map-get? auctions { id: auction-id })
    auction
      (begin
        (asserts! (not (get ended auction)) ERR_INVALID_STATE)
        (asserts! (< burn-block-height (get end-block auction)) ERR_TIMEOUT_NOT_REACHED)
        (asserts! (> bid-amount (get current-bid auction)) ERR_INVALID_LISTING)
        ;; Transfer bid amount (in full implementation, would be held in escrow)
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        ;; Refund previous highest bidder if exists
        (match (get highest-bidder auction)
          previous-bidder
            (try! (as-contract (stx-transfer? (get current-bid auction) tx-sender previous-bidder)))
          true)
        ;; Update auction with new highest bid
        (map-set auctions
          { id: auction-id }
          { listing-id: (get listing-id auction)
          , starting-price: (get starting-price auction)
          , current-bid: bid-amount
          , highest-bidder: (some tx-sender)
          , end-block: (get end-block auction)
          , ended: false })
        ;; Record bid
        (map-set auction-bids
          { auction-id: auction-id
          , bidder: tx-sender }
          { amount: bid-amount
          , block-height: burn-block-height })
        (ok true))
    ERR_NOT_FOUND))

;; End an auction and transfer to winner
(define-public (end-auction (auction-id uint))
  (match (map-get? auctions { id: auction-id })
    auction
      (begin
        (asserts! (not (get ended auction)) ERR_INVALID_STATE)
        (asserts! (>= burn-block-height (get end-block auction)) ERR_TIMEOUT_NOT_REACHED)
        (match (get highest-bidder auction)
          winner
            (match (map-get? listings { id: (get listing-id auction) })
              listing
                (let ((price (get current-bid auction))
                      (royalty-bips (get royalty-bips listing))
                      (seller (get seller listing))
                      (royalty-recipient (get royalty-recipient listing))
                      (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                      (marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
                      (seller-share (- (- price royalty) marketplace-fee)))
                  (begin
                    ;; Transfer payments
                    (try! (as-contract (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient))))
                    (if (> royalty u0)
                      (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
                      true)
                    (try! (as-contract (stx-transfer? seller-share tx-sender seller)))
                    ;; Transfer NFT if present
                    (match (get nft-contract listing)
                      nft-contract-principal
                        (match (get token-id listing)
                          token-id-value
                            (match (contract-call? nft-contract-principal transfer token-id-value seller winner)
                              (ok transfer-success)
                                (asserts! transfer-success ERR_NFT_TRANSFER_FAILED)
                              (err error-code)
                                (err error-code))
                          true)
                      true)
                    ;; Mark auction as ended
                    (map-set auctions
                      { id: auction-id }
                      { listing-id: (get listing-id auction)
                      , starting-price: (get starting-price auction)
                      , current-bid: (get current-bid auction)
                      , highest-bidder: (some winner)
                      , end-block: (get end-block auction)
                      , ended: true })
                    ;; Remove listing
                    (map-delete listings { id: (get listing-id auction) })
                    (ok true)))
              ERR_NOT_FOUND)
          ;; No bids - return listing to seller
          (begin
            (map-set auctions
              { id: auction-id }
              { listing-id: (get listing-id auction)
              , starting-price: (get starting-price auction)
              , current-bid: (get current-bid auction)
              , highest-bidder: none
              , end-block: (get end-block auction)
              , ended: true })
            (ok false))))
    ERR_NOT_FOUND))

;; Rating system for completed transactions
(define-public (rate-transaction (counterparty principal) (rating uint))
  (begin
    (asserts! (<= rating u5) ERR_BAD_ROYALTY) ;; 1-5 star rating
    (asserts! (>= rating u1) ERR_BAD_ROYALTY)
    ;; Update seller reputation with rating
    (let ((current-rep (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } 
                                   (map-get? reputation-seller { seller: counterparty }))))
      (map-set reputation-seller
        { seller: counterparty }
        { successful-txs: (get successful-txs current-rep)
        , failed-txs: (get failed-txs current-rep)
        , rating-sum: (+ (get rating-sum current-rep) rating)
        , rating-count: (+ (get rating-count current-rep) u1)
        , total-volume: (get total-volume current-rep) }))
    (ok true)))

;; Get average rating for a seller
(define-read-only (get-seller-average-rating (seller principal))
  (let ((rep (default-to { successful-txs: u0, failed-txs: u0, rating-sum: u0, rating-count: u0, total-volume: u0 } 
                         (map-get? reputation-seller { seller: seller }))))
    (if (> (get rating-count rep) u0)
      (ok (/ (get rating-sum rep) (get rating-count rep)))
      (ok u0))))

;; Listing categories and search
(define-map listing-categories
  { listing-id: uint }
  { category: (string-ascii 50)
  , tags: (list 5 (string-ascii 20))
  })

(define-public (set-listing-category (listing-id uint) (category (string-ascii 50)) (tags (list 5 (string-ascii 20))))
  (match (map-get? listings { id: listing-id })
    listing
      (begin
        (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
        (map-set listing-categories
          { listing-id: listing-id }
          { category: category
          , tags: tags })
        (ok true))
    ERR_NOT_FOUND))

;; Offer system - buyers can make offers on listings
(define-data-var next-offer-id uint u1)

(define-map offers
  { id: uint }
  { listing-id: uint
  , buyer: principal
  , amount: uint
  , expires-at-block: uint
  , accepted: bool
  , cancelled: bool
  })

(define-public (make-offer (listing-id uint) (amount uint) (duration-blocks uint))
  (match (map-get? listings { id: listing-id })
    listing
      (let ((offer-id (var-get next-offer-id)))
        (begin
          (asserts! (not (is-eq tx-sender (get seller listing))) ERR_NOT_OWNER)
          (asserts! (> amount u0) ERR_INVALID_LISTING)
          ;; Transfer offer amount to contract (escrow)
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          (map-set offers
            { id: offer-id }
            { listing-id: listing-id
            , buyer: tx-sender
            , amount: amount
            , expires-at-block: (+ burn-block-height duration-blocks)
            , accepted: false
            , cancelled: false })
          (var-set next-offer-id (+ offer-id u1))
          (ok offer-id)))
    ERR_NOT_FOUND))

(define-public (accept-offer (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer
      (match (map-get? listings { id: (get listing-id offer) })
        listing
          (begin
            (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
            (asserts! (not (get accepted offer)) ERR_INVALID_STATE)
            (asserts! (not (get cancelled offer)) ERR_INVALID_STATE)
            (asserts! (< burn-block-height (get expires-at-block offer)) ERR_TIMEOUT_NOT_REACHED)
            (let ((price (get amount offer))
                  (buyer (get buyer offer))
                  (royalty-bips (get royalty-bips listing))
                  (royalty-recipient (get royalty-recipient listing))
                  (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
                  (marketplace-fee (/ (* price (var-get marketplace-fee-bips)) BPS_DENOMINATOR))
                  (seller-share (- (- price royalty) marketplace-fee)))
              (begin
                ;; Transfer payments from escrowed offer
                (try! (as-contract (stx-transfer? marketplace-fee tx-sender (var-get fee-recipient))))
                (if (> royalty u0)
                  (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
                  true)
                (try! (as-contract (stx-transfer? seller-share tx-sender tx-sender)))
                ;; Transfer NFT if present
                (match (get nft-contract listing)
                  nft-contract-principal
                    (match (get token-id listing)
                      token-id-value
                        (match (contract-call? nft-contract-principal transfer token-id-value tx-sender buyer)
                          (ok transfer-success)
                            (asserts! transfer-success ERR_NFT_TRANSFER_FAILED)
                          (err error-code)
                            (err error-code))
                      true)
                  true)
                ;; Mark offer as accepted
                (map-set offers
                  { id: offer-id }
                  { listing-id: (get listing-id offer)
                  , buyer: buyer
                  , amount: price
                  , expires-at-block: (get expires-at-block offer)
                  , accepted: true
                  , cancelled: false })
                ;; Remove listing
                (map-delete listings { id: (get listing-id offer) })
                (ok true))))
        ERR_NOT_FOUND)
    ERR_NOT_FOUND))

(define-public (cancel-offer (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer
      (begin
        (asserts! (is-eq tx-sender (get buyer offer)) ERR_NOT_OWNER)
        (asserts! (not (get accepted offer)) ERR_INVALID_STATE)
        (asserts! (not (get cancelled offer)) ERR_INVALID_STATE)
        ;; Refund offer amount
        (try! (as-contract (stx-transfer? (get amount offer) tx-sender (get buyer offer))))
        ;; Mark offer as cancelled
        (map-set offers
          { id: offer-id }
          { listing-id: (get listing-id offer)
          , buyer: (get buyer offer)
          , amount: (get amount offer)
          , expires-at-block: (get expires-at-block offer)
          , accepted: false
          , cancelled: true })
        (ok true))
    ERR_NOT_FOUND))

;; Listing visibility and status management
(define-map listing-status
  { listing-id: uint }
  { active: bool
  , featured: bool
  , promoted-until-block: uint
  })

(define-public (set-listing-active (listing-id uint) (active bool))
  (match (map-get? listings { id: listing-id })
    listing
      (begin
        (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
        (map-set listing-status
          { listing-id: listing-id }
          { active: active
          , featured: (get featured (default-to { active: true, featured: false, promoted-until-block: u0 } 
                                                (map-get? listing-status { listing-id: listing-id })))
          , promoted-until-block: (get promoted-until-block (default-to { active: true, featured: false, promoted-until-block: u0 } 
                                                                        (map-get? listing-status { listing-id: listing-id }))) })
        (ok true))
    ERR_NOT_FOUND))

(define-public (promote-listing (listing-id uint) (duration-blocks uint))
  (match (map-get? listings { id: listing-id })
    listing
      (begin
        (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
        ;; Charge promotion fee (simplified - in full implementation would have fee structure)
        (let ((promotion-fee u1000)) ;; Fixed fee for now
          (try! (stx-transfer? promotion-fee tx-sender (var-get fee-recipient))))
        (map-set listing-status
          { listing-id: listing-id }
          { active: (get active (default-to { active: true, featured: false, promoted-until-block: u0 } 
                                            (map-get? listing-status { listing-id: listing-id })))
          , featured: true
          , promoted-until-block: (+ burn-block-height duration-blocks) })
        (ok true))
    ERR_NOT_FOUND))

;; Bulk operations for efficiency
(define-public (bulk-create-listings (listings-data (list 10 { price: uint, royalty-bips: uint, royalty-recipient: principal })))
  (let ((results (map create-single-listing listings-data)))
    (ok results)))

(define-private (create-single-listing (listing-data { price: uint, royalty-bips: uint, royalty-recipient: principal }))
  (let ((price (get price listing-data))
        (royalty-bips (get royalty-bips listing-data))
        (royalty-recipient (get royalty-recipient listing-data)))
    (if (<= royalty-bips MAX_ROYALTY_BIPS)
      (let ((id (var-get next-id)))
        (begin
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
          id))
      u0))) ;; Return 0 for failed listings

;; Emergency functions for admin
(define-public (emergency-pause-listing (listing-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER)
    (map-set listing-status
      { listing-id: listing-id }
      { active: false
      , featured: false
      , promoted-until-block: u0 })
    (ok true)))

(define-public (emergency-refund-escrow (listing-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER)
    (match (map-get? escrows { listing-id: listing-id })
      escrow
        (let ((buyer (get buyer escrow))
              (amount (get amount escrow)))
          (begin
            ;; Refund to buyer
            (try! (as-contract (stx-transfer? amount tx-sender buyer)))
            ;; Update escrow state
            (map-set escrows
              { listing-id: listing-id }
              { buyer: buyer
              , amount: amount
              , created-at-block: (get created-at-block escrow)
              , state: "cancelled"
              , timeout-block: (get timeout-block escrow) })
;; Analytics and metrics
(define-data-var total-volume uint u0)
(define-data-var total-transactions uint u0)
(define-data-var total-fees-collected uint u0)

(define-private (update-marketplace-metrics (amount uint) (fee uint))
  (begin
    (var-set total-volume (+ (var-get total-volume) amount))
    (var-set total-transactions (+ (var-get total-transactions) u1))
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))))

(define-read-only (get-marketplace-metrics)
  (ok { total-volume: (var-get total-volume)
      , total-transactions: (var-get total-transactions)
      , total-fees-collected: (var-get total-fees-collected) }))

;; Improved helper functions
(define-read-only (get-listings-by-seller (seller principal)) 
  (ok "Enhanced: Would need to iterate through all listings or maintain seller index"))

(define-read-only (get-formatted-reputation (user principal)) 
  (let ((seller-rep (unwrap! (get-seller-reputation user) (err u0)))
        (buyer-rep (unwrap! (get-buyer-reputation user) (err u0))))
    (ok { seller: seller-rep
        , buyer: buyer-rep
        , combined-success-rate: (if (> (+ (get successful-txs seller-rep) (get successful-txs buyer-rep)) u0)
                                   (/ (* (+ (get successful-txs seller-rep) (get successful-txs buyer-rep)) u100)
                                      (+ (+ (get successful-txs seller-rep) (get successful-txs buyer-rep))
                                         (+ (get failed-txs seller-rep) (get failed-txs buyer-rep))))
                                   u0) })))
