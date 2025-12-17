;; StackMart marketplace scaffold

(define-data-var next-id uint u1)

(define-constant MAX_ROYALTY_BIPS u1000) ;; 10% in basis points
(define-constant BPS_DENOMINATOR u10000)
(define-constant ERR_BAD_ROYALTY (err u400))
(define-constant ERR_NOT_FOUND (err u404))

(define-map listings
  { id: uint }
  { seller: principal
  , price: uint
  , royalty-bips: uint
  , royalty-recipient: principal
  })

(define-read-only (get-next-id)
  (ok (var-get next-id)))

(define-read-only (get-listing (id uint))
  (match (map-get? listings { id: id })
    listing (ok listing)
    ERR_NOT_FOUND))

(define-private (assert-royalty-ok (royalty-bips uint))
  (asserts! (<= royalty-bips MAX_ROYALTY_BIPS) ERR_BAD_ROYALTY))

(define-public (create-listing (price uint) (royalty-bips uint) (royalty-recipient principal))
  (begin
    (assert-royalty-ok royalty-bips)
    (let ((id (var-get next-id)))
      (map-set listings
        { id: id }
        { seller: tx-sender
        , price: price
        , royalty-bips: royalty-bips
        , royalty-recipient: royalty-recipient })
      (var-set next-id (+ id u1))
      (ok id))))

(define-public (buy-listing (id uint))
  (match (map-get? listings { id: id })
    listing
      (let (
            (price (get price listing))
            (royalty-bips (get royalty-bips listing))
            (seller (get seller listing))
            (royalty-recipient (get royalty-recipient listing))
            (royalty (/ (* price royalty-bips) BPS_DENOMINATOR))
            (seller-share (- price royalty))
           )
        (begin
          (when (> royalty u0)
            (try! (stx-transfer? royalty tx-sender royalty-recipient)))
          (try! (stx-transfer? seller-share tx-sender seller))
          (map-delete listings { id: id })
          (ok true)))
    ERR_NOT_FOUND))

