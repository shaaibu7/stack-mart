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
            (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
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

;; Buy a bundle (purchases all listings in bundle with discount)
(define-public (buy-bundle (bundle-id uint))
  (match (map-get? bundles { id: bundle-id })
    bundle
      (let ((listing-ids (get listing-ids bundle))
            (discount-bips (get discount-bips bundle)))
        (begin
          ;; Calculate total price with discount
          (let ((total-price (calculate-bundle-price listing-ids discount-bips)))
            (begin
              ;; Transfer payment
              ;; Note: In full implementation, would handle each listing purchase
              ;; For now, simplified - actual payment would be calculated from individual listings
              true
              ;; Process each listing purchase
              (process-bundle-purchases listing-ids tx-sender)
              ;; Delete bundle after purchase
              (map-delete bundles { id: bundle-id })
              (ok true)))))
    ERR_BUNDLE_NOT_FOUND))

;; Helper function to calculate bundle price
;; Note: Simplified calculation - in full implementation would iterate through all listings
(define-private (calculate-bundle-price (listing-ids (list 10 uint)) (discount-bips uint))
  ;; For now, return a placeholder price
  ;; In full implementation, would sum all listing prices and apply discount
  u0)

;; Helper function to process bundle purchases
(define-private (process-bundle-purchases (listing-ids (list 10 uint)) (buyer principal))
  ;; Note: Simplified - in full implementation would process each listing
  true)

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
