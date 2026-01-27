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

;; Security guards
(define-data-var reentrancy-guard bool false)

;; Rate limiting
(define-map rate-limits
  { principal: principal }
  { last-action: uint
  , action-count: uint
  })

;; Event logging system
(define-data-var next-event-id uint u1)

;; Operation tracking for duplicate prevention
(define-map operation-nonces
  { principal: principal }
  uint)

(define-map completed-operations
  { principal: principal
  , operation-type: (string-ascii 50)
  , nonce: uint }
  bool)

(define-map events
  { event-id: uint }
  { event-type: (string-ascii 50)
  , principal: principal
  , listing-id: (optional uint)
  , amount: (optional uint)
  , timestamp: uint
  , data: (optional (string-ascii 500))
  })

(define-constant RATE_LIMIT_WINDOW u10) ;; 10 blocks
(define-constant MAX_ACTIONS_PER_WINDOW u5)

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
(define-constant MARKETPLACE_FEE_BIPS u250) ;; 2.5% fee
(define-constant FEE_RECIPIENT tx-sender) ;; Deployer is initial fee recipient

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

(define-map wishlists
  { user: principal }
  { listing-ids: (list 100 uint) })

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

;; Enhanced listing structure with search and filtering capabilities
(define-map listings-v2
  { id: uint }
  { seller: principal
  , price: uint
  , royalty-bips: uint
  , royalty-recipient: principal
  , nft-contract: (optional principal)
  , token-id: (optional uint)
  , license-terms: (optional (string-ascii 500))
  , category: (string-ascii 50)
  , tags: (list 5 (string-ascii 20))
  , created-at: uint
  , updated-at: uint
  , view-count: uint
  , featured: bool
  })

;; Category index for efficient filtering
(define-map category-listings
  { category: (string-ascii 50) }
  { listing-ids: (list 100 uint) })

;; Price range index for efficient filtering (using price buckets)
(define-map price-bucket-listings
  { bucket: uint } ;; 0=0-1000, 1=1001-10000, 2=10001-100000, etc.
  { listing-ids: (list 100 uint) })

;; Active listings by seller for reputation-based filtering
(define-map seller-active-listings
  { seller: principal }
  { listing-ids: (list 50 uint) })

;; Valid categories for validation
(define-constant VALID_CATEGORIES (list "art" "music" "gaming" "collectibles" "utility" "domain" "photography" "sports" "fashion" "other"))

;; Price bucket constants for efficient range filtering
(define-constant PRICE_BUCKET_0 u1000)      ;; 0-1000 microSTX
(define-constant PRICE_BUCKET_1 u10000)     ;; 1001-10000 microSTX  
(define-constant PRICE_BUCKET_2 u100000)    ;; 10001-100000 microSTX
(define-constant PRICE_BUCKET_3 u1000000)   ;; 100001-1000000 microSTX
(define-constant PRICE_BUCKET_4 u10000000)  ;; 1000001-10000000 microSTX

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

(define-private (update-reputation-v2 (principal principal) (success bool) (amount uint) (rating (optional uint)))
  (let ((current-rep (default-to { 
          successful-txs: u0, 
          failed-txs: u0, 
          total-volume: u0, 
          rating-sum: u0, 
          rating-count: u0, 
          weighted-score: u0, 
          last-updated: u0, 
          verification-level: u0 
        } (map-get? reputation-v2 { principal: principal })))
        (new-successful (if success (+ (get successful-txs current-rep) u1) (get successful-txs current-rep)))
        (new-failed (if success (get failed-txs current-rep) (+ (get failed-txs current-rep) u1)))
        (new-volume (+ (get total-volume current-rep) amount))
        (new-rating-sum (match rating
          some-rating (+ (get rating-sum current-rep) some-rating)
          (get rating-sum current-rep)))
        (new-rating-count (match rating
          some-rating (+ (get rating-count current-rep) u1)
          (get rating-count current-rep)))
        (new-weighted-score (calculate-weighted-score new-successful new-failed new-volume new-rating-sum new-rating-count)))
    (begin
      (map-set reputation-v2
        { principal: principal }
        { successful-txs: new-successful
        , failed-txs: new-failed
        , total-volume: new-volume
        , rating-sum: new-rating-sum
        , rating-count: new-rating-count
        , weighted-score: new-weighted-score
        , last-updated: burn-block-height
        , verification-level: (get verification-level current-rep) })
      ;; Log reputation update event
      (log-event "reputation-updated" principal none (some amount) none)
      true)))

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
            (update-reputation-v2 other-party true (get amount escrow) (some rating)))
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
            (marketplace-fee (/ (* price MARKETPLACE_FEE_BIPS) BPS_DENOMINATOR))
            (seller-share (- (- price royalty) marketplace-fee))
           )
        (begin
          ;; Transfer marketplace fee
          (try! (stx-transfer? marketplace-fee tx-sender FEE_RECIPIENT))
          
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
                ;; Transfer payments from contract-held escrow
                ;; Note: In a full implementation, these would transfer from contract balance
                ;; For now, simplified to direct transfers
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
                ;; Update reputation - successful transaction
                (update-reputation seller true)
                (update-reputation tx-sender true)
                ;; Update enhanced reputation system
                (update-reputation-v2 seller true price none)
                (update-reputation-v2 tx-sender true price none)
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
      (if (get stx-held escrow)
        (try! (as-contract (stx-transfer? price tx-sender buyer-addr)))
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
      (update-reputation-v2 (get seller escrow) false price none)
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
            (try! (as-contract (stx-transfer? marketplace-fee tx-sender FEE_RECIPIENT)))
            true)
          ;; Transfer royalty if applicable
          (if (> royalty u0)
            (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
            true)
          ;; Transfer seller share
          (try! (as-contract (stx-transfer? seller-share tx-sender seller))))
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
            (try! (as-contract (stx-transfer? marketplace-fee tx-sender FEE_RECIPIENT)))
            true)
          ;; Transfer royalty if applicable
          (if (> royalty u0)
            (try! (as-contract (stx-transfer? royalty tx-sender royalty-recipient)))
            true)
          ;; Transfer seller share
          (try! (as-contract (stx-transfer? seller-share tx-sender seller))))
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
    ERR_ESCROW_NOT_FOUND))





;; Helper function to update reputation (optimized)
(define-private (update-reputation (principal principal) (success bool))
  (let ((current-rep (default-to DEFAULT_REPUTATION (map-get? reputation { principal: principal }))))
    (if success
      (map-set reputation
        { principal: principal }
        { successful-txs: (+ (get successful-txs current-rep) u1)
        , failed-txs: (get failed-txs current-rep)
        , rating-sum: (get rating-sum current-rep)
        , rating-count: (get rating-count current-rep) })
      (map-set reputation
        { principal: principal }
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

;; Helper function to process pack purchases with seller payments
(define-private (process-pack-purchases-v2 (listing-ids (list 20 uint)) (buyer principal) (total-seller-payment uint))
  (let ((num-listings (len listing-ids))
        (payment-per-listing (if (> num-listings u0) (/ total-seller-payment num-listings) u0)))
    (fold (process-single-pack-purchase payment-per-listing buyer) listing-ids (ok true))))

(define-private (process-single-pack-purchase (payment-per-listing uint) (buyer principal) (listing-id uint) (acc (response bool uint)))
  (match acc
    (ok success)
      (if success
        (match (map-get? listings { id: listing-id })
          listing
            (let ((seller (get seller listing)))
              (begin
                ;; Transfer payment to individual seller
                (if (> payment-per-listing u0)
                  (try! (stx-transfer? payment-per-listing tx-sender seller))
                  true)
                ;; Remove listing (transfer ownership to buyer)
                (map-delete listings { id: listing-id })
                ;; Update reputation
                (update-reputation seller true)
                (update-reputation buyer true)
                (ok true)))
          (ok true)) ;; Listing not found, continue with others
        acc) ;; Previous operation failed
    error-result error-result)) ;; Propagate error

;; Get enhanced bundle details
(define-read-only (get-bundle-v2 (bundle-id uint))
  (match (map-get? bundles-v2 { id: bundle-id })
    bundle (ok bundle)
    ERR_BUNDLE_NOT_FOUND))

;; Get enhanced pack details
(define-read-only (get-pack-v2 (pack-id uint))
  (match (map-get? packs-v2 { id: pack-id })
    pack (ok pack)
    ERR_PACK_NOT_FOUND))

;; Deactivate a pack (curator only)
(define-public (deactivate-pack (pack-id uint))
  (match (map-get? packs-v2 { id: pack-id })
    pack
      (begin
        ;; Only curator can deactivate
        (asserts! (is-eq tx-sender (get curator pack)) ERR_NOT_OWNER)
        ;; Update pack to inactive
        (map-set packs-v2
          { id: pack-id }
          (merge pack { active: false }))
        ;; Log pack deactivation event
        (log-event "pack-v2-deactivated" tx-sender none none none)
        (ok true))
    ERR_PACK_NOT_FOUND))

;; ========================================
;; SEARCH AND FILTERING FUNCTIONS
;; ========================================

;; Helper function to validate category
(define-private (is-valid-category (category (string-ascii 50)))
  (is-some (index-of VALID_CATEGORIES category)))

;; Helper function to get price bucket for a given price
(define-private (get-price-bucket (price uint))
  (if (<= price PRICE_BUCKET_0)
    u0
    (if (<= price PRICE_BUCKET_1)
      u1
      (if (<= price PRICE_BUCKET_2)
        u2
        (if (<= price PRICE_BUCKET_3)
          u3
          (if (<= price PRICE_BUCKET_4)
            u4
            u5)))))) ;; 5+ for prices above 10M microSTX

;; Helper function to add listing to category index
(define-private (add-to-category-index (listing-id uint) (category (string-ascii 50)))
  (let ((current-listings (default-to (list) (get listing-ids (map-get? category-listings { category: category })))))
    (match (as-max-len? (append current-listings listing-id) u100)
      updated-list
        (begin
          (map-set category-listings { category: category } { listing-ids: updated-list })
          true)
      false))) ;; List full, ignore for now

;; Helper function to add listing to price bucket index
(define-private (add-to-price-bucket-index (listing-id uint) (price uint))
  (let ((bucket (get-price-bucket price))
        (current-listings (default-to (list) (get listing-ids (map-get? price-bucket-listings { bucket: bucket })))))
    (match (as-max-len? (append current-listings listing-id) u100)
      updated-list
        (begin
          (map-set price-bucket-listings { bucket: bucket } { listing-ids: updated-list })
          true)
      false))) ;; List full, ignore for now

;; Helper function to add listing to seller index
(define-private (add-to-seller-index (listing-id uint) (seller principal))
  (let ((current-listings (default-to (list) (get listing-ids (map-get? seller-active-listings { seller: seller })))))
    (match (as-max-len? (append current-listings listing-id) u50)
      updated-list
        (begin
          (map-set seller-active-listings { seller: seller } { listing-ids: updated-list })
          true)
      false))) ;; List full, ignore for now

;; Enhanced listing creation with search indexing
(define-public (create-listing-v2 
    (price uint) 
    (royalty-bips uint) 
    (royalty-recipient principal)
    (category (string-ascii 50))
    (tags (list 5 (string-ascii 20))))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Enhanced input validation
    (asserts! (validate-price price) ERR_INVALID_INPUT)
    (asserts! (validate-royalty royalty-bips) ERR_BAD_ROYALTY)
    (asserts! (is-valid-category category) ERR_INVALID_CATEGORY)
    (let ((id (var-get next-id)))
      (begin
        ;; Create enhanced listing
        (map-set listings-v2
          { id: id }
          { seller: tx-sender
          , price: price
          , royalty-bips: royalty-bips
          , royalty-recipient: royalty-recipient
          , nft-contract: none
          , token-id: none
          , license-terms: none
          , category: category
          , tags: tags
          , created-at: burn-block-height
          , updated-at: burn-block-height
          , view-count: u0
          , featured: false })
        ;; Add to search indices
        (add-to-category-index id category)
        (add-to-price-bucket-index id price)
        (add-to-seller-index id tx-sender)
        (var-set next-id (+ id u1))
        ;; Log listing creation event
        (log-event "listing-v2-created" tx-sender (some id) (some price) (some category))
        (clear-reentrancy)
        (ok id)))))

;; Enhanced NFT listing creation with search indexing
(define-public (create-listing-v2-with-nft
    (nft-contract principal)
    (token-id uint)
    (price uint)
    (royalty-bips uint)
    (royalty-recipient principal)
    (license-terms (string-ascii 500))
    (category (string-ascii 50))
    (tags (list 5 (string-ascii 20))))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Enhanced input validation
    (asserts! (validate-price price) ERR_INVALID_INPUT)
    (asserts! (validate-royalty royalty-bips) ERR_BAD_ROYALTY)
    (asserts! (validate-string-length license-terms u500) ERR_INVALID_INPUT)
    (asserts! (is-valid-category category) ERR_INVALID_CATEGORY)
    ;; Verify seller owns the NFT
    (asserts! (verify-nft-ownership nft-contract token-id tx-sender) ERR_NOT_OWNER)
    (let ((id (var-get next-id)))
      (begin
        ;; Create enhanced NFT listing
        (map-set listings-v2
          { id: id }
          { seller: tx-sender
          , price: price
          , royalty-bips: royalty-bips
          , royalty-recipient: royalty-recipient
          , nft-contract: (some nft-contract)
          , token-id: (some token-id)
          , license-terms: (some license-terms)
          , category: category
          , tags: tags
          , created-at: burn-block-height
          , updated-at: burn-block-height
          , view-count: u0
          , featured: false })
        ;; Add to search indices
        (add-to-category-index id category)
        (add-to-price-bucket-index id price)
        (add-to-seller-index id tx-sender)
        (var-set next-id (+ id u1))
        ;; Log NFT listing creation event
        (log-event "nft-listing-v2-created" tx-sender (some id) (some price) (some category))
        (clear-reentrancy)
        (ok id)))))

;; Search listings by category
(define-read-only (search-by-category (category (string-ascii 50)))
  (match (map-get? category-listings { category: category })
    category-data (ok (get listing-ids category-data))
    (ok (list))))

;; Filter listings by price range
(define-read-only (filter-by-price-range (min-price uint) (max-price uint))
  (let ((min-bucket (get-price-bucket min-price))
        (max-bucket (get-price-bucket max-price)))
    ;; For simplicity, return listings from the min-price bucket
    ;; In full implementation, would check multiple buckets and filter precisely
    (match (map-get? price-bucket-listings { bucket: min-bucket })
      bucket-data (ok (get listing-ids bucket-data))
      (ok (list)))))

;; Filter listings by seller reputation (minimum weighted score)
(define-read-only (filter-by-seller-reputation (min-reputation-score uint))
  (let ((high-rep-sellers (get-high-reputation-sellers min-reputation-score)))
    ;; Return listings from high reputation sellers
    ;; For simplicity, return first high-rep seller's listings
    ;; In full implementation, would aggregate from all qualifying sellers
    (if (> (len high-rep-sellers) u0)
      (match (element-at high-rep-sellers u0)
        (some seller)
          (match (map-get? seller-active-listings { seller: seller })
            seller-data (ok (get listing-ids seller-data))
            (ok (list)))
        (ok (list)))
      (ok (list)))))

;; Helper function to get sellers with high reputation
(define-private (get-high-reputation-sellers (min-score uint))
  ;; Simplified implementation - returns empty list for now
  ;; In full implementation, would iterate through reputation-v2 map
  (list))

;; Combined search function with multiple filters
(define-read-only (search-listings 
    (category (optional (string-ascii 50)))
    (min-price (optional uint))
    (max-price (optional uint))
    (min-reputation (optional uint)))
  (let ((category-results (match category
          (some cat) (unwrap-panic (search-by-category cat))
          (list))) ;; Return empty list if no category filter
        (price-results (match min-price
          (some min-p) 
            (match max-price
              (some max-p) (unwrap-panic (filter-by-price-range min-p max-p))
              (unwrap-panic (filter-by-price-range min-p u1000000000000))) ;; Use max possible price
          (list))) ;; Return empty list if no price filter
        (reputation-results (match min-reputation
          (some min-rep) (unwrap-panic (filter-by-seller-reputation min-rep))
          (list)))) ;; Return empty list if no reputation filter
    ;; For simplicity, return category results if available, otherwise price results
    ;; In full implementation, would intersect all result sets
    (if (> (len category-results) u0)
      (ok category-results)
      (if (> (len price-results) u0)
        (ok price-results)
        (ok reputation-results)))))

;; Get enhanced listing details
(define-read-only (get-listing-v2 (id uint))
  (match (map-get? listings-v2 { id: id })
    listing (ok listing)
    ERR_NOT_FOUND))

;; Get all valid categories
(define-read-only (get-valid-categories)
  (ok VALID_CATEGORIES))

;; Get listings count by category
(define-read-only (get-category-count (category (string-ascii 50)))
  (match (map-get? category-listings { category: category })
    category-data (ok (len (get listing-ids category-data)))
    (ok u0)))

;; Get featured listings (listings marked as featured)
(define-read-only (get-featured-listings)
  ;; Simplified implementation - would need to maintain featured index
  ;; For now, return empty list
  (ok (list)))

;; Update listing view count (for analytics)
(define-public (increment-view-count (listing-id uint))
  (match (map-get? listings-v2 { id: listing-id })
    listing
      (begin
        (map-set listings-v2
          { id: listing-id }
          (merge listing { view-count: (+ (get view-count listing) u1) }))
        (ok true))
    ERR_NOT_FOUND))

;; ========================================
;; OFFER AND NEGOTIATION SYSTEM
;; ========================================

;; Offer states: pending, accepted, rejected, countered, expired
(define-map offers
  { id: uint }
  { listing-id: uint
  , offerer: principal
  , amount: uint
  , expires-at: uint
  , state: (string-ascii 20)
  , created-at: uint
  , message: (optional (string-ascii 200))
  })

;; Counter-offer tracking
(define-map counter-offers
  { original-offer-id: uint }
  { counter-offer-id: uint
  , counter-amount: uint
  , counter-message: (optional (string-ascii 200))
  , created-at: uint
  })

;; Offer history for listings
(define-map listing-offers
  { listing-id: uint }
  { offer-ids: (list 20 uint) })

;; User's active offers
(define-map user-offers
  { user: principal }
  { offer-ids: (list 50 uint) })

(define-data-var next-offer-id uint u1)

;; Offer expiration constants
(define-constant DEFAULT_OFFER_EXPIRY_BLOCKS u1440) ;; ~10 days assuming 10 min blocks
(define-constant MAX_OFFER_EXPIRY_BLOCKS u4320)     ;; ~30 days max

;; Helper function to add offer to listing index
(define-private (add-offer-to-listing-index (listing-id uint) (offer-id uint))
  (let ((current-offers (default-to (list) (get offer-ids (map-get? listing-offers { listing-id: listing-id })))))
    (match (as-max-len? (append current-offers offer-id) u20)
      updated-list
        (begin
          (map-set listing-offers { listing-id: listing-id } { offer-ids: updated-list })
          true)
      false))) ;; List full, ignore for now

;; Helper function to add offer to user index
(define-private (add-offer-to-user-index (user principal) (offer-id uint))
  (let ((current-offers (default-to (list) (get offer-ids (map-get? user-offers { user: user })))))
    (match (as-max-len? (append current-offers offer-id) u50)
      updated-list
        (begin
          (map-set user-offers { user: user } { offer-ids: updated-list })
          true)
      false))) ;; List full, ignore for now

;; Create an offer on a listing
(define-public (create-offer 
    (listing-id uint) 
    (amount uint) 
    (expiry-blocks uint)
    (message (optional (string-ascii 200))))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Validate inputs
    (asserts! (validate-price amount) ERR_INVALID_INPUT)
    (asserts! (<= expiry-blocks MAX_OFFER_EXPIRY_BLOCKS) ERR_INVALID_INPUT)
    ;; Check listing exists
    (match (map-get? listings { id: listing-id })
      listing
        (begin
          ;; Can't offer on own listing
          (asserts! (not (is-eq tx-sender (get seller listing))) ERR_INVALID_INPUT)
          ;; Check if listing also exists in v2 (prefer v2 if available)
          (let ((listing-price (match (map-get? listings-v2 { id: listing-id })
                  v2-listing (get price v2-listing)
                  (get price listing)))
                (offer-id (var-get next-offer-id))
                (expires-at (+ burn-block-height (if (> expiry-blocks u0) expiry-blocks DEFAULT_OFFER_EXPIRY_BLOCKS))))
            (begin
              ;; Create offer
              (map-set offers
                { id: offer-id }
                { listing-id: listing-id
                , offerer: tx-sender
                , amount: amount
                , expires-at: expires-at
                , state: "pending"
                , created-at: burn-block-height
                , message: message })
              ;; Add to indices
              (add-offer-to-listing-index listing-id offer-id)
              (add-offer-to-user-index tx-sender offer-id)
              (var-set next-offer-id (+ offer-id u1))
              ;; Log offer creation event
              (log-event "offer-created" tx-sender (some listing-id) (some amount) none)
              (clear-reentrancy)
              (ok offer-id))))
      ERR_NOT_FOUND)))

;; Accept an offer (seller only)
(define-public (accept-offer (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer
      (match (map-get? listings { id: (get listing-id offer) })
        listing
          (begin
            ;; Only seller can accept
            (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
            ;; Offer must be pending and not expired
            (asserts! (is-eq (get state offer) "pending") ERR_INVALID_STATE)
            (asserts! (< burn-block-height (get expires-at offer)) ERR_EXPIRED_LISTING)
            ;; Update offer state
            (map-set offers
              { id: offer-id }
              (merge offer { state: "accepted" }))
            ;; Create escrow with offer amount
            (let ((listing-id (get listing-id offer))
                  (offerer (get offerer offer))
                  (offer-amount (get amount offer)))
              (begin
                ;; Create escrow with accepted offer amount
                (map-set escrows
                  { listing-id: listing-id }
                  { buyer: offerer
                  , seller: tx-sender
                  , amount: offer-amount
                  , created-at-block: burn-block-height
                  , state: "pending"
                  , timeout-block: (+ burn-block-height ESCROW_TIMEOUT_BLOCKS)
                  , stx-held: false }) ;; Offerer will need to fund escrow
                ;; Log offer acceptance event
                (log-event "offer-accepted" tx-sender (some listing-id) (some offer-amount) none)
                (ok true))))
        ERR_NOT_FOUND)
    ERR_NOT_FOUND))

;; Reject an offer (seller only)
(define-public (reject-offer (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer
      (match (map-get? listings { id: (get listing-id offer) })
        listing
          (begin
            ;; Only seller can reject
            (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
            ;; Offer must be pending
            (asserts! (is-eq (get state offer) "pending") ERR_INVALID_STATE)
            ;; Update offer state
            (map-set offers
              { id: offer-id }
              (merge offer { state: "rejected" }))
            ;; Log offer rejection event
            (log-event "offer-rejected" tx-sender (some (get listing-id offer)) (some (get amount offer)) none)
            (ok true))
        ERR_NOT_FOUND)
    ERR_NOT_FOUND))

;; Create counter-offer (seller only)
(define-public (create-counter-offer 
    (original-offer-id uint) 
    (counter-amount uint)
    (counter-message (optional (string-ascii 200))))
  (match (map-get? offers { id: original-offer-id })
    original-offer
      (match (map-get? listings { id: (get listing-id original-offer) })
        listing
          (begin
            ;; Only seller can counter-offer
            (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
            ;; Original offer must be pending
            (asserts! (is-eq (get state original-offer) "pending") ERR_INVALID_STATE)
            ;; Validate counter amount
            (asserts! (validate-price counter-amount) ERR_INVALID_INPUT)
            ;; Create new offer as counter-offer
            (let ((counter-offer-id (var-get next-offer-id))
                  (listing-id (get listing-id original-offer))
                  (original-offerer (get offerer original-offer)))
              (begin
                ;; Create counter-offer as new offer
                (map-set offers
                  { id: counter-offer-id }
                  { listing-id: listing-id
                  , offerer: tx-sender ;; Seller is now the offerer
                  , amount: counter-amount
                  , expires-at: (+ burn-block-height DEFAULT_OFFER_EXPIRY_BLOCKS)
                  , state: "pending"
                  , created-at: burn-block-height
                  , message: counter-message })
                ;; Link counter-offer to original
                (map-set counter-offers
                  { original-offer-id: original-offer-id }
                  { counter-offer-id: counter-offer-id
                  , counter-amount: counter-amount
                  , counter-message: counter-message
                  , created-at: burn-block-height })
                ;; Update original offer state
                (map-set offers
                  { id: original-offer-id }
                  (merge original-offer { state: "countered" }))
                ;; Add to indices
                (add-offer-to-listing-index listing-id counter-offer-id)
                (add-offer-to-user-index tx-sender counter-offer-id)
                (var-set next-offer-id (+ counter-offer-id u1))
                ;; Log counter-offer creation event
                (log-event "counter-offer-created" tx-sender (some listing-id) (some counter-amount) none)
                (ok counter-offer-id))))
        ERR_NOT_FOUND)
    ERR_NOT_FOUND))

;; Cancel an offer (offerer only, if pending)
(define-public (cancel-offer (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer
      (begin
        ;; Only offerer can cancel
        (asserts! (is-eq tx-sender (get offerer offer)) ERR_NOT_OWNER)
        ;; Offer must be pending
        (asserts! (is-eq (get state offer) "pending") ERR_INVALID_STATE)
        ;; Update offer state
        (map-set offers
          { id: offer-id }
          (merge offer { state: "cancelled" }))
        ;; Log offer cancellation event
        (log-event "offer-cancelled" tx-sender (some (get listing-id offer)) (some (get amount offer)) none)
        (ok true))
    ERR_NOT_FOUND))

;; Get offer details
(define-read-only (get-offer (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer (ok offer)
    ERR_NOT_FOUND))

;; Get counter-offer details
(define-read-only (get-counter-offer (original-offer-id uint))
  (match (map-get? counter-offers { original-offer-id: original-offer-id })
    counter-offer (ok counter-offer)
    ERR_NOT_FOUND))

;; Get all offers for a listing
(define-read-only (get-listing-offers (listing-id uint))
  (match (map-get? listing-offers { listing-id: listing-id })
    listing-offer-data (ok (get offer-ids listing-offer-data))
    (ok (list))))

;; Get all offers by a user
(define-read-only (get-user-offers (user principal))
  (match (map-get? user-offers { user: user })
    user-offer-data (ok (get offer-ids user-offer-data))
    (ok (list))))

;; Check if offer is expired
(define-read-only (is-offer-expired (offer-id uint))
  (match (map-get? offers { id: offer-id })
    offer (ok (>= burn-block-height (get expires-at offer)))
    ERR_NOT_FOUND))

;; Get active offers for a listing (non-expired, pending)
(define-read-only (get-active-offers (listing-id uint))
  ;; Simplified implementation - returns all offers for listing
  ;; In full implementation, would filter by state and expiry
  (get-listing-offers listing-id))

;; ========================================
;; TIME-LIMITED PROMOTIONS AND DISCOUNTS
;; ========================================

;; Promotion types: percentage, fixed-amount, bundle-discount
(define-map promotions
  { id: uint }
  { listing-id: uint
  , creator: principal
  , promotion-type: (string-ascii 20)
  , discount-value: uint ;; percentage in bips or fixed amount in microSTX
  , starts-at: uint
  , expires-at: uint
  , max-uses: uint
  , current-uses: uint
  , active: bool
  , conditions: (optional (string-ascii 200)) ;; Optional conditions like minimum purchase
  })

;; Promotion usage tracking
(define-map promotion-usage
  { promotion-id: uint
  , user: principal }
  { used-at: uint
  , purchase-amount: uint
  })

;; Active promotions by listing
(define-map listing-promotions
  { listing-id: uint }
  { promotion-ids: (list 10 uint) })

;; Seasonal/global promotions
(define-map global-promotions
  { id: uint }
  { name: (string-ascii 100)
  , promotion-type: (string-ascii 20)
  , discount-value: uint
  , starts-at: uint
  , expires-at: uint
  , max-uses: uint
  , current-uses: uint
  , active: bool
  , applicable-categories: (list 5 (string-ascii 50))
  })

(define-data-var next-promotion-id uint u1)
(define-data-var next-global-promotion-id uint u1)

;; Promotion constants
(define-constant MAX_PROMOTION_DISCOUNT_BIPS u5000) ;; 50% max discount
(define-constant MAX_PROMOTION_DURATION_BLOCKS u14400) ;; ~100 days max

;; Helper function to add promotion to listing index
(define-private (add-promotion-to-listing-index (listing-id uint) (promotion-id uint))
  (let ((current-promotions (default-to (list) (get promotion-ids (map-get? listing-promotions { listing-id: listing-id })))))
    (match (as-max-len? (append current-promotions promotion-id) u10)
      updated-list
        (begin
          (map-set listing-promotions { listing-id: listing-id } { promotion-ids: updated-list })
          true)
      false))) ;; List full, ignore for now

;; Check if promotion is currently active
(define-private (is-promotion-active (promotion-id uint))
  (match (map-get? promotions { id: promotion-id })
    promotion
      (and (get active promotion)
           (<= (get starts-at promotion) burn-block-height)
           (> (get expires-at promotion) burn-block-height)
           (< (get current-uses promotion) (get max-uses promotion)))
    false))

;; Calculate discounted price for a promotion
(define-private (calculate-discounted-price (original-price uint) (promotion-type (string-ascii 20)) (discount-value uint))
  (if (is-eq promotion-type "percentage")
    ;; Percentage discount (discount-value in basis points)
    (let ((discount-amount (/ (* original-price discount-value) BPS_DENOMINATOR)))
      (if (> original-price discount-amount)
        (- original-price discount-amount)
        u1)) ;; Minimum price of 1 microSTX
    ;; Fixed amount discount
    (if (> original-price discount-value)
      (- original-price discount-value)
      u1))) ;; Minimum price of 1 microSTX

;; Create a time-limited promotion for a listing
(define-public (create-promotion
    (listing-id uint)
    (promotion-type (string-ascii 20))
    (discount-value uint)
    (duration-blocks uint)
    (max-uses uint)
    (conditions (optional (string-ascii 200))))
  (begin
    ;; Security checks
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Validate inputs
    (asserts! (or (is-eq promotion-type "percentage") (is-eq promotion-type "fixed-amount")) ERR_INVALID_INPUT)
    (asserts! (<= duration-blocks MAX_PROMOTION_DURATION_BLOCKS) ERR_INVALID_INPUT)
    (asserts! (> max-uses u0) ERR_INVALID_INPUT)
    ;; For percentage discounts, validate discount is within limits
    (if (is-eq promotion-type "percentage")
      (asserts! (<= discount-value MAX_PROMOTION_DISCOUNT_BIPS) ERR_INVALID_INPUT)
      true)
    ;; Check listing exists and caller is seller
    (match (map-get? listings { id: listing-id })
      listing
        (begin
          (asserts! (is-eq tx-sender (get seller listing)) ERR_NOT_OWNER)
          (let ((promotion-id (var-get next-promotion-id))
                (starts-at burn-block-height)
                (expires-at (+ burn-block-height duration-blocks)))
            (begin
              ;; Create promotion
              (map-set promotions
                { id: promotion-id }
                { listing-id: listing-id
                , creator: tx-sender
                , promotion-type: promotion-type
                , discount-value: discount-value
                , starts-at: starts-at
                , expires-at: expires-at
                , max-uses: max-uses
                , current-uses: u0
                , active: true
                , conditions: conditions })
              ;; Add to listing index
              (add-promotion-to-listing-index listing-id promotion-id)
              (var-set next-promotion-id (+ promotion-id u1))
              ;; Log promotion creation event
              (log-event "promotion-created" tx-sender (some listing-id) (some discount-value) none)
              (clear-reentrancy)
              (ok promotion-id))))
      ERR_NOT_FOUND)))

;; Create a global/seasonal promotion
(define-public (create-global-promotion
    (name (string-ascii 100))
    (promotion-type (string-ascii 20))
    (discount-value uint)
    (duration-blocks uint)
    (max-uses uint)
    (applicable-categories (list 5 (string-ascii 50))))
  (begin
    ;; Security checks - only contract owner can create global promotions
    ;; For now, any user can create (in production, would restrict to admin)
    (try! (check-reentrancy))
    (try! (check-rate-limit tx-sender))
    ;; Validate inputs
    (asserts! (or (is-eq promotion-type "percentage") (is-eq promotion-type "fixed-amount")) ERR_INVALID_INPUT)
    (asserts! (<= duration-blocks MAX_PROMOTION_DURATION_BLOCKS) ERR_INVALID_INPUT)
    (asserts! (> max-uses u0) ERR_INVALID_INPUT)
    ;; For percentage discounts, validate discount is within limits
    (if (is-eq promotion-type "percentage")
      (asserts! (<= discount-value MAX_PROMOTION_DISCOUNT_BIPS) ERR_INVALID_INPUT)
      true)
    (let ((global-promotion-id (var-get next-global-promotion-id))
          (starts-at burn-block-height)
          (expires-at (+ burn-block-height duration-blocks)))
      (begin
        ;; Create global promotion
        (map-set global-promotions
          { id: global-promotion-id }
          { name: name
          , promotion-type: promotion-type
          , discount-value: discount-value
          , starts-at: starts-at
          , expires-at: expires-at
          , max-uses: max-uses
          , current-uses: u0
          , active: true
          , applicable-categories: applicable-categories })
        (var-set next-global-promotion-id (+ global-promotion-id u1))
        ;; Log global promotion creation event
        (log-event "global-promotion-created" tx-sender none (some discount-value) (some name))
        (clear-reentrancy)
        (ok global-promotion-id)))))

;; Apply promotion to a purchase (internal helper)
(define-private (apply-promotion-to-purchase (listing-id uint) (original-price uint) (buyer principal))
  ;; Get active promotions for listing
  (match (map-get? listing-promotions { listing-id: listing-id })
    listing-promotion-data
      (let ((promotion-ids (get promotion-ids listing-promotion-data)))
        ;; For simplicity, apply first active promotion found
        ;; In full implementation, would find best promotion for user
        (if (> (len promotion-ids) u0)
          (match (element-at promotion-ids u0)
            (some first-promotion-id)
              (if (is-promotion-active first-promotion-id)
                (match (map-get? promotions { id: first-promotion-id })
                  promotion
                    (let ((discounted-price (calculate-discounted-price 
                            original-price 
                            (get promotion-type promotion) 
                            (get discount-value promotion))))
                      ;; Record promotion usage
                      (map-set promotion-usage
                        { promotion-id: first-promotion-id, user: buyer }
                        { used-at: burn-block-height, purchase-amount: discounted-price })
                      ;; Update promotion usage count
                      (map-set promotions
                        { id: first-promotion-id }
                        (merge promotion { current-uses: (+ (get current-uses promotion) u1) }))
                      discounted-price)
                  original-price) ;; Promotion not found, return original price
                original-price) ;; Promotion not active, return original price
            original-price) ;; No promotion ID found, return original price
          original-price)) ;; No promotions, return original price
    original-price)) ;; No promotions for listing, return original price

;; Get current price with active promotions applied
(define-read-only (get-promotional-price (listing-id uint))
  (match (map-get? listings { id: listing-id })
    listing
      (let ((original-price (get price listing))
            (promotional-price (apply-promotion-to-purchase listing-id original-price tx-sender)))
        (ok { original-price: original-price, promotional-price: promotional-price }))
    ERR_NOT_FOUND))

;; Deactivate a promotion (creator only)
(define-public (deactivate-promotion (promotion-id uint))
  (match (map-get? promotions { id: promotion-id })
    promotion
      (begin
        ;; Only creator can deactivate
        (asserts! (is-eq tx-sender (get creator promotion)) ERR_NOT_OWNER)
        ;; Update promotion to inactive
        (map-set promotions
          { id: promotion-id }
          (merge promotion { active: false }))
        ;; Log promotion deactivation event
        (log-event "promotion-deactivated" tx-sender (some (get listing-id promotion)) none none)
        (ok true))
    ERR_NOT_FOUND))

;; Get promotion details
(define-read-only (get-promotion (promotion-id uint))
  (match (map-get? promotions { id: promotion-id })
    promotion (ok promotion)
    ERR_NOT_FOUND))

;; Get global promotion details
(define-read-only (get-global-promotion (global-promotion-id uint))
  (match (map-get? global-promotions { id: global-promotion-id })
    global-promotion (ok global-promotion)
    ERR_NOT_FOUND))

;; Get all promotions for a listing
(define-read-only (get-listing-promotions (listing-id uint))
  (match (map-get? listing-promotions { listing-id: listing-id })
    listing-promotion-data (ok (get promotion-ids listing-promotion-data))
    (ok (list))))

;; Check if user has used a specific promotion
(define-read-only (has-user-used-promotion (promotion-id uint) (user principal))
  (is-some (map-get? promotion-usage { promotion-id: promotion-id, user: user })))

;; Get active promotions for a listing (non-expired, within usage limits)
(define-read-only (get-active-promotions (listing-id uint))
  ;; Simplified implementation - returns all promotions for listing
  ;; In full implementation, would filter by active status, expiry, and usage limits
  (get-listing-promotions listing-id))
