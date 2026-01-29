(impl-trait .stack-mart.sip009-nft-trait)

(define-non-fungible-token mock-nft uint)

(define-public (get-owner (id uint))
  (ok (nft-get-owner? mock-nft id)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u403))
    (nft-transfer? mock-nft id sender recipient)))

(define-public (mint (recipient principal) (id uint))
  (nft-mint? mock-nft id recipient))
