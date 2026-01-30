;; Rewards and Leaderboard Contract
;; This contract tracks user points based on Stacks activity, 
;; library usage, and GitHub contributions.

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant ERR-BUFFER-OVERFLOW (err u102))
(define-constant ERR-INVALID-POINTS (err u103))
(define-constant ERR-COOLDOWN-ACTIVE (err u104))
(define-constant ERR-CONTRACT-PAUSED (err u105))

;; Constants
(define-constant ADMIN tx-sender)
(define-constant POINTS-PER-CONTRACT-ACTIVITY u50)
(define-constant POINTS-PER-LIBRARY-USAGE u25)
(define-constant POINTS-PER-REFERRAL u100)
(define-constant REPUTATION-PER-ACTIVITY u10)
(define-constant LEVEL-THRESHOLD u1000) ;; 1000 points per level
(define-constant BLOCKS-PER-DAY u144) ;; Rough estimate for Stacks
(define-constant DECAY-FACTOR u95) ;; 5% decay periodically

;; Tier System Constants
(define-constant TIER-BRONZE u0)
(define-constant TIER-SILVER u1)
(define-constant TIER-GOLD u2)
(define-constant TIER-PLATINUM u3)
(define-constant TIER-DIAMOND u4)
(define-constant TIER-BRONZE-THRESHOLD u0)
(define-constant TIER-SILVER-THRESHOLD u1000)
(define-constant TIER-GOLD-THRESHOLD u5000)
(define-constant TIER-PLATINUM-THRESHOLD u15000)
(define-constant TIER-DIAMOND-THRESHOLD u50000)
(define-constant TIER-BRONZE-MULTIPLIER u100) ;; 1.0x = 100
(define-constant TIER-SILVER-MULTIPLIER u110) ;; 1.1x = 110
(define-constant TIER-GOLD-MULTIPLIER u125) ;; 1.25x = 125
(define-constant TIER-PLATINUM-MULTIPLIER u150) ;; 1.5x = 150
(define-constant TIER-DIAMOND-MULTIPLIER u200) ;; 2.0x = 200

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var activity-point-base uint u50)

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

;; Referral Tracking
(define-map Referrals principal (list 200 principal))
(define-map Referrers principal principal)

;; Streak Tracking
(define-map UserStreaks 
    principal 
    {
        current-streak: uint,
        last-activity-block: uint
    }
)

;; Tier Tracking
(define-map UserTiers principal uint)
(define-map TierUpgradeEvents 
    { user: principal, tier: uint } 
    { upgraded-at-block: uint, points-at-upgrade: uint }
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
            last-activity-block: burn-block-height,
            reputation-score: u0
        }
    )
)

;; Public: Log Smart Contract Activity
;; Increments points based on contract interaction and impact
(define-public (log-contract-activity (user principal) (impact-score uint))
    (begin
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        (let (
        (current-stats (default-to 
            {
                total-points: u0,
                contract-impact-points: u0,
                library-usage-points: u0,
                github-contrib-points: u0,
                last-activity-block: burn-block-height,
                reputation-score: u0
            }
            (map-get? UserPoints user)
        ))
        (base-points (var-get activity-point-base))
        (multiplier (calculate-multiplier user))
        (impact-bonus (* impact-score u10))
        (total-new-points (* (+ base-points impact-bonus) multiplier))
    )
        ;; Check for overflow
        (asserts! (< (+ (get total-points current-stats) total-new-points) u340282366920938463463374607431768211455) ERR-BUFFER-OVERFLOW)
        
        
        (map-set UserPoints user
            (merge current-stats {
                total-points: (+ (get total-points current-stats) total-new-points),
                contract-impact-points: (+ (get contract-impact-points current-stats) total-new-points),
                reputation-score: (+ (get reputation-score current-stats) REPUTATION-PER-ACTIVITY),
                last-activity-block: burn-block-height
            })
        )
        (update-streak user)
        (check-and-update-tier user (+ (get total-points current-stats) total-new-points))
        (update-global-stats total-new-points)
        (ok true)
    )
))

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
                last-activity-block: burn-block-height,
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
                last-activity-block: burn-block-height
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
                last-activity-block: burn-block-height,
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
                last-activity-block: burn-block-height
            })
        )
        (update-global-stats points)
        (ok true)
    )
)

;; Public: Apply Point Decay
;; Encourages continuous activity by reducing points over time
(define-public (apply-decay (user principal))
    (let (
        (current-stats (default-to 
            {
                total-points: u0,
                contract-impact-points: u0,
                library-usage-points: u0,
                github-contrib-points: u0,
                last-activity-block: burn-block-height,
                reputation-score: u0
            }
            (map-get? UserPoints user)
        ))
        (old-points (get total-points current-stats))
        (new-points (/ (* old-points DECAY-FACTOR) u100))
    )
        ;; Only apply if significant time has passed (e.g., 1000 blocks)
        (asserts! (> (- burn-block-height (get last-activity-block current-stats)) u1000) (ok true))
        
        (map-set UserPoints user
            (merge current-stats {
                total-points: new-points,
                last-activity-block: burn-block-height
            })
        )
        (ok true)
    )
)

;; Read-only: Calculate Rank (Mock implementation for now)
(define-read-only (get-user-rank (user principal))
    (let (
        (stats (get-user-stats user))
        (global (get-global-stats))
    )
        (match stats
            user-stats (ok {
                rank: u1, ;; Future: iterate or use off-chain index
                percentile: (/ (* (get total-points user-stats) u100) (if (> (get top-score global) u0) (get top-score global) u1))
            })
            (err ERR-USER-NOT-FOUND)
        )
    )
)

;; Read-only: Get User Level
(define-read-only (get-user-level (user principal))
    (let (
        (stats (get-user-stats user))
    )
        (match stats
            user-stats (ok (/ (get total-points user-stats) LEVEL-THRESHOLD))
            (err ERR-USER-NOT-FOUND)
        )
    )
)

;; Read-only: Get Reputation
(define-read-only (get-user-reputation (user principal))
    (let (
        (stats (get-user-stats user))
    )
        (match stats
            user-stats (ok (get reputation-score user-stats))
            (err ERR-USER-NOT-FOUND)
        )
    )
)

;; Public: Log Referral
;; Tracks who referred whom and rewards the referrer
(define-public (log-referral (new-user principal) (referrer principal))
    (let (
        (current-referrals (default-to (list) (map-get? Referrals referrer)))
        (existing-referrer (map-get? Referrers new-user))
    )
        ;; New user cannot be the referrer
        (asserts! (not (is-eq new-user referrer)) ERR-INVALID-POINTS)
        ;; New user cannot already have a referrer
        (asserts! (is-none existing-referrer) ERR-INVALID-POINTS)
        
        ;; Update Referrers map
        (map-set Referrers new-user referrer)
        
        ;; Update Referrals list (appends new user to referrer's list)
        (map-set Referrals referrer (unwrap! (as-max-len? (append current-referrals new-user) u200) ERR-BUFFER-OVERFLOW))
        
        ;; Reward the referrer
        (let (
            (referrer-stats (default-to 
                {
                    total-points: u0,
                    contract-impact-points: u0,
                    library-usage-points: u0,
                    github-contrib-points: u0,
                    last-activity-block: burn-block-height,
                    reputation-score: u0
                }
                (map-get? UserPoints referrer)
            ))
            (points POINTS-PER-REFERRAL)
        )
            (map-set UserPoints referrer
                (merge referrer-stats {
                    total-points: (+ (get total-points referrer-stats) points),
                    last-activity-block: burn-block-height
                })
            )
            (update-global-stats points)
        )
        (ok true)
    )
)

;; Read-only: Get Streak
(define-read-only (get-user-streak (user principal))
    (default-to { current-streak: u0, last-activity-block: u0 } (map-get? UserStreaks user))
)

;; Admin: Set Paused State
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-paused paused))
    )
)

;; Admin: Update Base Points
(define-public (set-activity-point-base (new-base uint))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (ok (var-set activity-point-base new-base))
    )
)

;; Internal: Calculate Multiplier based on streak
(define-private (calculate-multiplier (user principal))
    (let (
        (streak-stats (default-to { current-streak: u0, last-activity-block: u0 } (map-get? UserStreaks user)))
        (streak (get current-streak streak-stats))
    )
        (if (> streak u30) u3 ;; Max 3x for 30+ day streak
            (if (> streak u7) u2 ;; 2x for 1 week+
                u1 ;; 1x default
            )
        )
    )
)

;; Update streak logic
(define-private (update-streak (user principal))
    (let (
        (streak-stats (default-to { current-streak: u0, last-activity-block: u0 } (map-get? UserStreaks user)))
        (last-block (get last-activity-block streak-stats))
        (current-streak (get current-streak streak-stats))
    )
        (if (is-eq last-block u0)
            (map-set UserStreaks user { current-streak: u1, last-activity-block: burn-block-height })
            (if (< (- burn-block-height last-block) (* BLOCKS-PER-DAY u2))
                (if (> (- burn-block-height last-block) BLOCKS-PER-DAY)
                    (map-set UserStreaks user { current-streak: (+ current-streak u1), last-activity-block: burn-block-height })
                    true ;; Still within same day, don't increment but don't reset
                )
                (map-set UserStreaks user { current-streak: u1, last-activity-block: burn-block-height }) ;; Reset if missed a day
            )
        )
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

;; ============================================================================
;; TIER SYSTEM
;; ============================================================================

;; Read-only: Get User Tier
(define-read-only (get-user-tier (user principal))
    (let (
        (stats (get-user-stats user))
    )
        (match stats
            user-stats 
                (let ((points (get total-points user-stats)))
                    (ok (if (>= points TIER-DIAMOND-THRESHOLD) TIER-DIAMOND
                        (if (>= points TIER-PLATINUM-THRESHOLD) TIER-PLATINUM
                            (if (>= points TIER-GOLD-THRESHOLD) TIER-GOLD
                                (if (>= points TIER-SILVER-THRESHOLD) TIER-SILVER
                                    TIER-BRONZE
                                )
                            )
                        )
                    ))
                )
            (ok TIER-BRONZE) ;; Default to Bronze for new users
        )
    )
)

;; Read-only: Get Tier Multiplier
(define-read-only (get-tier-multiplier (tier uint))
    (if (is-eq tier TIER-DIAMOND) TIER-DIAMOND-MULTIPLIER
        (if (is-eq tier TIER-PLATINUM) TIER-PLATINUM-MULTIPLIER
            (if (is-eq tier TIER-GOLD) TIER-GOLD-MULTIPLIER
                (if (is-eq tier TIER-SILVER) TIER-SILVER-MULTIPLIER
                    TIER-BRONZE-MULTIPLIER
                )
            )
        )
    )
)

;; Private: Check and Update Tier
(define-private (check-and-update-tier (user principal) (new-points uint))
    (let (
        (old-tier (default-to TIER-BRONZE (map-get? UserTiers user)))
        (new-tier (unwrap-panic (get-user-tier user)))
    )
        (if (> new-tier old-tier)
            (begin
                (map-set UserTiers user new-tier)
                (map-set TierUpgradeEvents 
                    { user: user, tier: new-tier }
                    { upgraded-at-block: burn-block-height, points-at-upgrade: new-points }
                )
                (print { event: "tier-upgrade", user: user, old-tier: old-tier, new-tier: new-tier, points: new-points })
                true
            )
            true
        )
    )
)

;; Read-only: Get Tier Upgrade History
(define-read-only (get-tier-upgrade-event (user principal) (tier uint))
    (map-get? TierUpgradeEvents { user: user, tier: tier })
)
