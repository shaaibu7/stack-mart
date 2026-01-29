;; Rewards and Leaderboard Contract
;; This contract tracks user points based on Stacks activity, 
;; library usage, and GitHub contributions.

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant ERR-BUFFER-OVERFLOW (err u102))
(define-constant ERR-INVALID-POINTS (err u103))
(define-constant ERR-COOLDOWN-ACTIVE (err u104))

;; Constants
(define-constant ADMIN tx-sender)
(define-constant POINTS-PER-CONTRACT-ACTIVITY u50)
(define-constant POINTS-PER-LIBRARY-USAGE u25)
(define-constant DECAY-FACTOR u95) ;; 5% decay periodically

;; Data Maps
(define-map UserPoints
    principal
    {
        total-points: uint,
        contract-impact-points: uint,
        library-usage-points: uint,
        github-contrib-points: uint,
        last-activity-block: uint,
        reputation-score: uint
    }
)

(define-map GlobalStats
    uint ;; Index 0
    {
        total-users: uint,
        total-points-distributed: uint,
        top-score: uint
    }
)

;; Read-only: Get User Stats
(define-read-only (get-user-stats (user principal))
    (map-get? UserPoints user)
)

;; Read-only: Get Global Stats
(define-read-only (get-global-stats)
    (default-to 
        { total-users: u0, total-points-distributed: u0, top-score: u0 }
        (map-get? GlobalStats u0)
    )
)

;; Private Initialize User
(define-private (initialize-user (user principal))
    (map-set UserPoints user
        {
            total-points: u0,
            contract-impact-points: u0,
            library-usage-points: u0,
            github-contrib-points: u0,
            last-activity-block: block-height,
            reputation-score: u0
        }
    )
)

;; Public: Log Smart Contract Activity
;; Increments points based on contract interaction and impact
(define-public (log-contract-activity (user principal) (impact-score uint))
    (let (
        (current-stats (default-to 
            {
                total-points: u0,
                contract-impact-points: u0,
                library-usage-points: u0,
                github-contrib-points: u0,
                last-activity-block: block-height,
                reputation-score: u0
            }
            (map-get? UserPoints user)
        ))
        (base-points POINTS-PER-CONTRACT-ACTIVITY)
        (impact-bonus (* impact-score u10))
        (total-new-points (+ base-points impact-bonus))
    )
        ;; Check for overflow
        (asserts! (< (+ (get total-points current-stats) total-new-points) u340282366920938463463374607431768211455) ERR-BUFFER-OVERFLOW)
        
        (map-set UserPoints user
            (merge current-stats {
                total-points: (+ (get total-points current-stats) total-new-points),
                contract-impact-points: (+ (get contract-impact-points current-stats) total-new-points),
                last-activity-block: block-height
            })
        )
        (update-global-stats total-new-points)
        (ok true)
    )
)

;; Public: Log Library Usage
;; Tracks use of @stacks/connect and @stacks/transactions
(define-public (log-library-usage (user principal) (library-type (string-ascii 20)))
    (let (
        (current-stats (default-to 
            {
                total-points: u0,
                contract-impact-points: u0,
                library-usage-points: u0,
                github-contrib-points: u0,
                last-activity-block: block-height,
                reputation-score: u0
            }
            (map-get? UserPoints user)
        ))
        (points POINTS-PER-LIBRARY-USAGE)
    )
        ;; Validate library type
        (asserts! (or (is-eq library-type "connect") (is-eq library-type "transactions")) ERR-INVALID-POINTS)
        
        ;; Check for overflow
        (asserts! (< (+ (get total-points current-stats) points) u340282366920938463463374607431768211455) ERR-BUFFER-OVERFLOW)
        
        (map-set UserPoints user
            (merge current-stats {
                total-points: (+ (get total-points current-stats) points),
                library-usage-points: (+ (get library-usage-points current-stats) points),
                last-activity-block: block-height
            })
        )
        (update-global-stats points)
        (ok true)
    )
)

;; Public: Log GitHub Contributions
;; Restricted to contract owner (admin/oracle)
(define-public (log-github-contribution (user principal) (points uint))
    (let (
        (current-stats (default-to 
            {
                total-points: u0,
                contract-impact-points: u0,
                library-usage-points: u0,
                github-contrib-points: u0,
                last-activity-block: block-height,
                reputation-score: u0
            }
            (map-get? UserPoints user)
        ))
    )
        ;; Check authorization
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        
        ;; Check for overflow
        (asserts! (< (+ (get total-points current-stats) points) u340282366920938463463374607431768211455) ERR-BUFFER-OVERFLOW)
        
        (map-set UserPoints user
            (merge current-stats {
                total-points: (+ (get total-points current-stats) points),
                github-contrib-points: (+ (get github-contrib-points current-stats) points),
                last-activity-block: block-height
            })
        )
        (update-global-stats points)
        (ok true)
    )
)

;; Internal: Update Global Accumulators
(define-private (update-global-stats (new-points uint))
    (let (
        (current-global (get-global-stats))
    )
        (map-set GlobalStats u0
            {
                total-users: (+ (get total-users current-global) u1),
                total-points-distributed: (+ (get total-points-distributed current-global) new-points),
                top-score: (if (> new-points (get top-score current-global)) new-points (get top-score current-global))
            }
        )
    )
)
