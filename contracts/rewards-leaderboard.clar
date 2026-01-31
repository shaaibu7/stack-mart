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

;; ============================================================================
;; ACHIEVEMENT SYSTEM
;; ============================================================================

;; Achievement IDs
(define-constant ACHIEVEMENT-FIRST-ACTIVITY u1)
(define-constant ACHIEVEMENT-STREAK-WEEK u2)
(define-constant ACHIEVEMENT-STREAK-MONTH u3)
(define-constant ACHIEVEMENT-REFERRAL-CHAMPION u4)
(define-constant ACHIEVEMENT-LIBRARY-MASTER u5)
(define-constant ACHIEVEMENT-GITHUB-CONTRIBUTOR u6)
(define-constant ACHIEVEMENT-TIER-GOLD u7)
(define-constant ACHIEVEMENT-TIER-PLATINUM u8)
(define-constant ACHIEVEMENT-TIER-DIAMOND u9)
(define-constant ACHIEVEMENT-POINTS-10K u10)

;; Achievement Rewards
(define-constant ACHIEVEMENT-REWARD-SMALL u50)
(define-constant ACHIEVEMENT-REWARD-MEDIUM u100)
(define-constant ACHIEVEMENT-REWARD-LARGE u250)

;; Achievement Tracking
(define-map UserAchievements 
    { user: principal, achievement-id: uint }
    { unlocked-at-block: uint, reward-claimed: bool }
)

;; Read-only: Check if Achievement is Unlocked
(define-read-only (has-achievement (user principal) (achievement-id uint))
    (is-some (map-get? UserAchievements { user: user, achievement-id: achievement-id }))
)

;; Read-only: Get Achievement Details
(define-read-only (get-achievement (user principal) (achievement-id uint))
    (map-get? UserAchievements { user: user, achievement-id: achievement-id })
)

;; Private: Unlock Achievement
(define-private (unlock-achievement (user principal) (achievement-id uint) (reward uint))
    (if (has-achievement user achievement-id)
        false ;; Already unlocked
        (begin
            (map-set UserAchievements 
                { user: user, achievement-id: achievement-id }
                { unlocked-at-block: burn-block-height, reward-claimed: false }
            )
            (print { event: "achievement-unlocked", user: user, achievement-id: achievement-id, reward: reward })
            true
        )
    )
)

;; Private: Check and Unlock Achievements
(define-private (check-achievements (user principal))
    (let (
        (stats (unwrap! (get-user-stats user) false))
        (streak (get current-streak (get-user-streak user)))
        (tier (unwrap-panic (get-user-tier user)))
    )
        ;; First Activity
        (if (and (> (get total-points stats) u0) (not (has-achievement user ACHIEVEMENT-FIRST-ACTIVITY)))
            (unlock-achievement user ACHIEVEMENT-FIRST-ACTIVITY ACHIEVEMENT-REWARD-SMALL)
            false
        )
        ;; Streak Achievements
        (if (and (>= streak u7) (not (has-achievement user ACHIEVEMENT-STREAK-WEEK)))
            (unlock-achievement user ACHIEVEMENT-STREAK-WEEK ACHIEVEMENT-REWARD-MEDIUM)
            false
        )
        (if (and (>= streak u30) (not (has-achievement user ACHIEVEMENT-STREAK-MONTH)))
            (unlock-achievement user ACHIEVEMENT-STREAK-MONTH ACHIEVEMENT-REWARD-LARGE)
            false
        )
        ;; Tier Achievements
        (if (and (>= tier TIER-GOLD) (not (has-achievement user ACHIEVEMENT-TIER-GOLD)))
            (unlock-achievement user ACHIEVEMENT-TIER-GOLD ACHIEVEMENT-REWARD-MEDIUM)
            false
        )
        (if (and (>= tier TIER-PLATINUM) (not (has-achievement user ACHIEVEMENT-TIER-PLATINUM)))
            (unlock-achievement user ACHIEVEMENT-TIER-PLATINUM ACHIEVEMENT-REWARD-LARGE)
            false
        )
        (if (and (>= tier TIER-DIAMOND) (not (has-achievement user ACHIEVEMENT-TIER-DIAMOND)))
            (unlock-achievement user ACHIEVEMENT-TIER-DIAMOND ACHIEVEMENT-REWARD-LARGE)
            false
        )
        ;; Points Milestone
        (if (and (>= (get total-points stats) u10000) (not (has-achievement user ACHIEVEMENT-POINTS-10K)))
            (unlock-achievement user ACHIEVEMENT-POINTS-10K ACHIEVEMENT-REWARD-LARGE)
            false
        )
        true
    )
)

;; ============================================================================
;; LEADERBOARD SNAPSHOTS
;; ============================================================================

;; Snapshot Types
(define-constant SNAPSHOT-WEEKLY u1)
(define-constant SNAPSHOT-MONTHLY u2)

;; Leaderboard Snapshots
(define-map LeaderboardSnapshots
    { period-type: uint, period-id: uint }
    {
        created-at-block: uint,
        top-users: (list 10 principal),
        top-scores: (list 10 uint)
    }
)

;; Read-only: Get Snapshot
(define-read-only (get-snapshot (period-type uint) (period-id uint))
    (map-get? LeaderboardSnapshots { period-type: period-type, period-id: period-id })
)

;; Admin: Create Snapshot
(define-public (create-snapshot 
    (period-type uint) 
    (period-id uint) 
    (top-users (list 10 principal)) 
    (top-scores (list 10 uint)))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq period-type SNAPSHOT-WEEKLY) (is-eq period-type SNAPSHOT-MONTHLY)) ERR-INVALID-POINTS)
        (asserts! (is-eq (len top-users) (len top-scores)) ERR-INVALID-POINTS)
        
        (map-set LeaderboardSnapshots
            { period-type: period-type, period-id: period-id }
            {
                created-at-block: burn-block-height,
                top-users: top-users,
                top-scores: top-scores
            }
        )
        (print { event: "snapshot-created", period-type: period-type, period-id: period-id })
        (ok true)
    )
)

;; Read-only: Calculate Period ID
(define-read-only (get-current-week-id)
    (ok (/ burn-block-height (* BLOCKS-PER-DAY u7)))
)

(define-read-only (get-current-month-id)
    (ok (/ burn-block-height (* BLOCKS-PER-DAY u30)))
)

;; ============================================================================
;; REWARD CLAIMING SYSTEM
;; ============================================================================

;; Claimable Rewards Tracking
(define-map ClaimableRewards principal uint)
(define-map ClaimHistory 
    { user: principal, claim-id: uint }
    { amount: uint, claimed-at-block: uint }
)
(define-map UserClaimCount principal uint)

;; Read-only: Get Claimable Rewards
(define-read-only (get-claimable-rewards (user principal))
    (ok (default-to u0 (map-get? ClaimableRewards user)))
)

;; Admin: Add Claimable Rewards
(define-public (add-claimable-rewards (user principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-POINTS)
        
        (let ((current-claimable (default-to u0 (map-get? ClaimableRewards user))))
            (map-set ClaimableRewards user (+ current-claimable amount))
            (print { event: "rewards-added", user: user, amount: amount })
            (ok true)
        )
    )
)

;; Public: Claim Rewards
(define-public (claim-rewards)
    (let (
        (claimable (default-to u0 (map-get? ClaimableRewards tx-sender)))
        (claim-count (default-to u0 (map-get? UserClaimCount tx-sender)))
    )
        (asserts! (> claimable u0) ERR-INVALID-POINTS)
        
        ;; Add to user's total points
        (let ((current-stats (unwrap! (get-user-stats tx-sender) ERR-USER-NOT-FOUND)))
            (map-set UserPoints tx-sender
                (merge current-stats {
                    total-points: (+ (get total-points current-stats) claimable)
                })
            )
        )
        
        ;; Record claim history
        (map-set ClaimHistory 
            { user: tx-sender, claim-id: claim-count }
            { amount: claimable, claimed-at-block: burn-block-height }
        )
        
        ;; Update claim count and reset claimable
        (map-set UserClaimCount tx-sender (+ claim-count u1))
        (map-set ClaimableRewards tx-sender u0)
        
        (print { event: "rewards-claimed", user: tx-sender, amount: claimable })
        (ok claimable)
    )
)

;; Read-only: Get Claim History
(define-read-only (get-claim-history (user principal) (claim-id uint))
    (map-get? ClaimHistory { user: user, claim-id: claim-id })
)

;; ============================================================================
;; BONUS POINT EVENTS
;; ============================================================================

;; Active Events Tracking
(define-map ActiveEvents
    uint ;; event-id
    {
        name: (string-ascii 50),
        multiplier: uint,
        start-block: uint,
        end-block: uint,
        active: bool
    }
)
(define-data-var next-event-id uint u1)

;; Admin: Create Bonus Event
(define-public (create-bonus-event 
    (name (string-ascii 50))
    (multiplier uint)
    (duration-blocks uint))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (asserts! (> multiplier u100) ERR-INVALID-POINTS) ;; Must be > 1.0x
        (asserts! (> duration-blocks u0) ERR-INVALID-POINTS)
        
        (let ((event-id (var-get next-event-id)))
            (map-set ActiveEvents event-id
                {
                    name: name,
                    multiplier: multiplier,
                    start-block: burn-block-height,
                    end-block: (+ burn-block-height duration-blocks),
                    active: true
                }
            )
            (var-set next-event-id (+ event-id u1))
            (print { event: "bonus-event-created", event-id: event-id, name: name, multiplier: multiplier })
            (ok event-id)
        )
    )
)

;; Admin: End Bonus Event
(define-public (end-bonus-event (event-id uint))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (let ((event-data (unwrap! (map-get? ActiveEvents event-id) ERR-INVALID-POINTS)))
            (map-set ActiveEvents event-id (merge event-data { active: false }))
            (print { event: "bonus-event-ended", event-id: event-id })
            (ok true)
        )
    )
)

;; Read-only: Get Active Events
(define-read-only (get-active-events)
    (ok (var-get next-event-id))
)

;; Read-only: Get Event Details
(define-read-only (get-event (event-id uint))
    (map-get? ActiveEvents event-id)
)

;; ============================================================================
;; PAGINATION & ACTIVITY LOGGING
;; ============================================================================

;; Detailed Activity Logs
(define-map UserActivityLogs
    { user: principal, log-id: uint }
    {
        activity-type: (string-ascii 20),
        points-earned: uint,
        timestamp: uint,
        metadata: (string-ascii 50)
    }
)

(define-map UserLogCount principal uint)

;; Internal: Log Activity Detail
(define-private (log-activity-detail (user principal) (activity-type (string-ascii 20)) (points uint) (meta (string-ascii 50)))
    (let ((count (default-to u0 (map-get? UserLogCount user))))
        (map-set UserActivityLogs
            { user: user, log-id: count }
            {
                activity-type: activity-type,
                points-earned: points,
                timestamp: burn-block-height,
                metadata: meta
            }
        )
        (map-set UserLogCount user (+ count u1))
        true
    )
)

;; Read-only: Get User Activity Log
(define-read-only (get-user-activity-log (user principal) (log-id uint))
    (map-get? UserActivityLogs { user: user, log-id: log-id })
)

;; Read-only: Get Total Log Count
(define-read-only (get-user-log-count (user principal))
    (default-to u0 (map-get? UserLogCount user))
)

;; Read-only: Get Total Active Users
(define-read-only (get-active-user-count)
    (get total-users (get-global-stats))
)

;; Read-only: Mock Paginated Leaderboard
;; In a real production contract, this would interface with an off-chain indexer
;; but for this implementation, we provide the interface for the frontend.
(define-read-only (get-leaderboard-page (offset uint) (limit uint))
    (ok {
        users: (list), ;; To be populated via off-chain indexing or specific principal lists
        total: (get total-users (get-global-stats))
    })
)

;; ============================================================================
;; MULTI-ADMIN MANAGEMENT
;; ============================================================================

;; Admin Map
(define-map Admins principal bool)

;; Initialize primary admin
(map-set Admins ADMIN true)

;; Read-only: Check if address is admin
(define-read-only (is-admin (address principal))
    (default-to false (map-get? Admins address))
)

;; Admin: Add new admin
(define-public (add-admin (new-admin principal))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (map-set Admins new-admin true)
        (print { event: "admin-added", added-by: tx-sender, new-admin: new-admin })
        (ok true)
    )
)

;; Admin: Remove admin
(define-public (remove-admin (old-admin principal))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        ;; Primary ADMIN cannot be removed for safety
        (asserts! (not (is-eq old-admin ADMIN)) ERR-NOT-AUTHORIZED)
        (map-delete Admins old-admin)
        (print { event: "admin-removed", removed-by: tx-sender, old-admin: old-admin })
        (ok true)
    )
)

;; Admin: Emergency Shutdown
(define-public (emergency-pause)
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (var-set contract-paused true)
        (print { event: "emergency-pause", triggered-by: tx-sender })
        (ok true)
    )
)

;; Admin: Transfer Ownership (Primary ADMIN only)
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-NOT-AUTHORIZED)
        (map-set Admins new-owner true)
        (print { event: "ownership-transfer-initiated", new-owner: new-owner })
        (ok true)
    )
)

;; ============================================================================
;; DYNAMIC MULTIPLIERS
;; ============================================================================

;; Map to store base multipliers for different activity types
(define-map ActivityMultipliers (string-ascii 20) uint)

;; Admin: Set multiplier for a specific activity
(define-public (set-activity-multiplier (activity (string-ascii 20)) (multiplier uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> multiplier u0) ERR-INVALID-POINTS)
        (map-set ActivityMultipliers activity multiplier)
        (print { event: "multiplier-updated", activity: activity, new-multiplier: multiplier })
        (ok true)
    )
)

;; Read-only: Get Multiplier for activity
(define-read-only (get-activity-multiplier (activity (string-ascii 20)))
    (default-to u100 (map-get? ActivityMultipliers activity))
)

;; Internal: Calculate Effective Multiplier (Tier + Streak + Base)
(define-private (calculate-effective-multiplier (user principal) (activity (string-ascii 20)))
    (let (
        (tier (unwrap-panic (get-user-tier user)))
        (tier-mult (get-tier-multiplier tier))
        (streak-mult (calculate-multiplier user))
        (activity-mult (get-activity-multiplier activity))
    )
        ;; Result: (TierMult/100 * StreakMult * ActivityMult/100)
        ;; We use basis points to preserve precision
        (/ (* (* tier-mult activity-mult) streak-mult) u100)
    )
)

;; Admin: Global Points Cap
(define-data-var global-multiplier-cap uint u500) ;; max 5x effective multiplier

(define-public (set-multiplier-cap (new-cap uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (ok (var-set global-multiplier-cap new-cap))
    )
)
;; ============================================================================
;; SEASONAL COMPETITION SYSTEM
;; ============================================================================

;; Season Management
(define-map Seasons 
    uint ;; season-id
    {
        name: (string-ascii 50),
        start-block: uint,
        end-block: uint,
        reward-pool: uint,
        active: bool,
        theme-multiplier: uint
    }
)

(define-map SeasonalPoints 
    { user: principal, season-id: uint }
    uint
)

(define-map SeasonalRankings
    { season-id: uint, rank: uint }
    { user: principal, points: uint }
)

(define-map SeasonRewards
    { user: principal, season-id: uint }
    { amount: uint, claimed: bool }
)

(define-data-var current-season-id uint u0)
(define-data-var next-season-id uint u1)

;; Admin: Create New Season
(define-public (create-season 
    (name (string-ascii 50))
    (duration-blocks uint)
    (reward-pool uint)
    (theme-multiplier uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> duration-blocks u0) ERR-INVALID-POINTS)
        (asserts! (> reward-pool u0) ERR-INVALID-POINTS)
        (asserts! (> theme-multiplier u0) ERR-INVALID-POINTS)
        
        (let ((season-id (var-get next-season-id)))
            (map-set Seasons season-id
                {
                    name: name,
                    start-block: burn-block-height,
                    end-block: (+ burn-block-height duration-blocks),
                    reward-pool: reward-pool,
                    active: true,
                    theme-multiplier: theme-multiplier
                }
            )
            (var-set next-season-id (+ season-id u1))
            (var-set current-season-id season-id)
            (print { event: "season-created", season-id: season-id, name: name })
            (ok season-id)
        )
    )
)

;; Public: Log Seasonal Activity
(define-public (log-seasonal-activity (user principal) (points uint))
    (let (
        (season-id (var-get current-season-id))
        (season-data (unwrap! (map-get? Seasons season-id) ERR-INVALID-POINTS))
    )
        (asserts! (get active season-data) ERR-CONTRACT-PAUSED)
        (asserts! (<= burn-block-height (get end-block season-data)) ERR-COOLDOWN-ACTIVE)
        
        (let (
            (current-seasonal (default-to u0 (map-get? SeasonalPoints { user: user, season-id: season-id })))
            (theme-mult (get theme-multiplier season-data))
            (adjusted-points (/ (* points theme-mult) u100))
        )
            (map-set SeasonalPoints 
                { user: user, season-id: season-id }
                (+ current-seasonal adjusted-points)
            )
            (print { event: "seasonal-activity", user: user, season-id: season-id, points: adjusted-points })
            (ok true)
        )
    )
)

;; Read-only: Get Seasonal Points
(define-read-only (get-seasonal-points (user principal) (season-id uint))
    (default-to u0 (map-get? SeasonalPoints { user: user, season-id: season-id }))
)

;; Read-only: Get Season Info
(define-read-only (get-season-info (season-id uint))
    (map-get? Seasons season-id)
)

;; Admin: End Season and Distribute Rewards
(define-public (end-season (season-id uint) (top-users (list 10 principal)) (rewards (list 10 uint)))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (len top-users) (len rewards)) ERR-INVALID-POINTS)
        
        (let ((season-data (unwrap! (map-get? Seasons season-id) ERR-INVALID-POINTS)))
            (asserts! (get active season-data) ERR-CONTRACT-PAUSED)
            
            ;; Mark season as inactive
            (map-set Seasons season-id (merge season-data { active: false }))
            
            ;; Set up rewards for top users
            (map distribute-season-rewards top-users rewards)
            
            (print { event: "season-ended", season-id: season-id })
            (ok true)
        )
    )
)

;; Private: Distribute Season Rewards Helper
(define-private (distribute-season-rewards (user principal) (reward uint))
    (let ((season-id (var-get current-season-id)))
        (map-set SeasonRewards
            { user: user, season-id: season-id }
            { amount: reward, claimed: false }
        )
        true
    )
)

;; Public: Claim Season Rewards
(define-public (claim-season-rewards (season-id uint))
    (let (
        (reward-data (unwrap! (map-get? SeasonRewards { user: tx-sender, season-id: season-id }) ERR-USER-NOT-FOUND))
    )
        (asserts! (not (get claimed reward-data)) ERR-COOLDOWN-ACTIVE)
        
        ;; Mark as claimed
        (map-set SeasonRewards 
            { user: tx-sender, season-id: season-id }
            (merge reward-data { claimed: true })
        )
        
        ;; Add to claimable rewards
        (let ((current-claimable (default-to u0 (map-get? ClaimableRewards tx-sender))))
            (map-set ClaimableRewards tx-sender (+ current-claimable (get amount reward-data)))
        )
        
        (print { event: "season-rewards-claimed", user: tx-sender, season-id: season-id, amount: (get amount reward-data) })
        (ok (get amount reward-data))
    )
)
;; ============================================================================
;; GUILD SYSTEM
;; ============================================================================

;; Guild Management
(define-map Guilds 
    uint ;; guild-id
    {
        name: (string-ascii 30),
        leader: principal,
        member-count: uint,
        total-points: uint,
        created-block: uint,
        active: bool
    }
)

(define-map GuildMembers 
    { guild-id: uint, member: principal }
    {
        joined-block: uint,
        contribution-points: uint,
        role: uint ;; 0=member, 1=officer, 2=leader
    }
)

(define-map UserGuild principal uint) ;; Maps user to their guild-id
(define-data-var next-guild-id uint u1)

;; Guild Role Constants
(define-constant GUILD-ROLE-MEMBER u0)
(define-constant GUILD-ROLE-OFFICER u1)
(define-constant GUILD-ROLE-LEADER u2)

;; Public: Create Guild
(define-public (create-guild (name (string-ascii 30)))
    (let ((guild-id (var-get next-guild-id)))
        ;; User cannot already be in a guild
        (asserts! (is-none (map-get? UserGuild tx-sender)) ERR-INVALID-POINTS)
        
        (map-set Guilds guild-id
            {
                name: name,
                leader: tx-sender,
                member-count: u1,
                total-points: u0,
                created-block: burn-block-height,
                active: true
            }
        )
        
        (map-set GuildMembers 
            { guild-id: guild-id, member: tx-sender }
            {
                joined-block: burn-block-height,
                contribution-points: u0,
                role: GUILD-ROLE-LEADER
            }
        )
        
        (map-set UserGuild tx-sender guild-id)
        (var-set next-guild-id (+ guild-id u1))
        
        (print { event: "guild-created", guild-id: guild-id, leader: tx-sender, name: name })
        (ok guild-id)
    )
)

;; Public: Join Guild
(define-public (join-guild (guild-id uint))
    (let ((guild-data (unwrap! (map-get? Guilds guild-id) ERR-USER-NOT-FOUND)))
        ;; User cannot already be in a guild
        (asserts! (is-none (map-get? UserGuild tx-sender)) ERR-INVALID-POINTS)
        (asserts! (get active guild-data) ERR-CONTRACT-PAUSED)
        
        (map-set GuildMembers 
            { guild-id: guild-id, member: tx-sender }
            {
                joined-block: burn-block-height,
                contribution-points: u0,
                role: GUILD-ROLE-MEMBER
            }
        )
        
        (map-set UserGuild tx-sender guild-id)
        
        ;; Update guild member count
        (map-set Guilds guild-id 
            (merge guild-data { member-count: (+ (get member-count guild-data) u1) })
        )
        
        (print { event: "guild-joined", guild-id: guild-id, member: tx-sender })
        (ok true)
    )
)

;; Public: Leave Guild
(define-public (leave-guild)
    (let (
        (guild-id (unwrap! (map-get? UserGuild tx-sender) ERR-USER-NOT-FOUND))
        (guild-data (unwrap! (map-get? Guilds guild-id) ERR-USER-NOT-FOUND))
        (member-data (unwrap! (map-get? GuildMembers { guild-id: guild-id, member: tx-sender }) ERR-USER-NOT-FOUND))
    )
        ;; Leaders cannot leave unless they transfer leadership
        (asserts! (not (is-eq (get role member-data) GUILD-ROLE-LEADER)) ERR-NOT-AUTHORIZED)
        
        ;; Remove member
        (map-delete GuildMembers { guild-id: guild-id, member: tx-sender })
        (map-delete UserGuild tx-sender)
        
        ;; Update guild member count
        (map-set Guilds guild-id 
            (merge guild-data { member-count: (- (get member-count guild-data) u1) })
        )
        
        (print { event: "guild-left", guild-id: guild-id, member: tx-sender })
        (ok true)
    )
)

;; Public: Add Guild Points (when member earns points)
(define-public (add-guild-points (member principal) (points uint))
    (let ((guild-id-opt (map-get? UserGuild member)))
        (match guild-id-opt
            guild-id 
                (let (
                    (guild-data (unwrap! (map-get? Guilds guild-id) ERR-USER-NOT-FOUND))
                    (member-data (unwrap! (map-get? GuildMembers { guild-id: guild-id, member: member }) ERR-USER-NOT-FOUND))
                )
                    ;; Update guild total points
                    (map-set Guilds guild-id 
                        (merge guild-data { total-points: (+ (get total-points guild-data) points) })
                    )
                    
                    ;; Update member contribution
                    (map-set GuildMembers { guild-id: guild-id, member: member }
                        (merge member-data { contribution-points: (+ (get contribution-points member-data) points) })
                    )
                    
                    (ok true)
                )
            (ok false) ;; User not in guild, no action needed
        )
    )
)

;; Read-only: Get Guild Info
(define-read-only (get-guild-info (guild-id uint))
    (map-get? Guilds guild-id)
)

;; Read-only: Get User's Guild
(define-read-only (get-user-guild (user principal))
    (map-get? UserGuild user)
)

;; Read-only: Get Guild Member Info
(define-read-only (get-guild-member-info (guild-id uint) (member principal))
    (map-get? GuildMembers { guild-id: guild-id, member: member })
)
;; ============================================================================
;; CROSS-CONTRACT INTEGRATION
;; ============================================================================

;; Partner Contract Management
(define-map PartnerContracts 
    principal ;; contract-address
    {
        name: (string-ascii 30),
        point-multiplier: uint,
        active: bool,
        registered-block: uint,
        total-activities: uint
    }
)

;; Activity Deduplication
(define-map ActivityHashes 
    (buff 32) ;; activity-hash
    {
        user: principal,
        contract: principal,
        processed-block: uint
    }
)

;; Cross-Contract Activity Log
(define-map CrossContractActivities
    { user: principal, activity-id: uint }
    {
        contract: principal,
        activity-type: (string-ascii 20),
        points-earned: uint,
        timestamp: uint,
        hash: (buff 32)
    }
)

(define-map UserCrossContractCount principal uint)

;; Admin: Register Partner Contract
(define-public (register-partner-contract 
    (contract-address principal)
    (name (string-ascii 30))
    (point-multiplier uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> point-multiplier u0) ERR-INVALID-POINTS)
        
        (map-set PartnerContracts contract-address
            {
                name: name,
                point-multiplier: point-multiplier,
                active: true,
                registered-block: burn-block-height,
                total-activities: u0
            }
        )
        
        (print { event: "partner-registered", contract: contract-address, name: name, multiplier: point-multiplier })
        (ok true)
    )
)

;; Public: Log Cross-Contract Activity
(define-public (log-cross-contract-activity 
    (user principal)
    (activity-type (string-ascii 20))
    (base-points uint)
    (activity-hash (buff 32)))
    (let (
        (partner-data (unwrap! (map-get? PartnerContracts contract-caller) ERR-NOT-AUTHORIZED))
        (existing-hash (map-get? ActivityHashes activity-hash))
    )
        (asserts! (get active partner-data) ERR-CONTRACT-PAUSED)
        ;; Prevent duplicate processing
        (asserts! (is-none existing-hash) ERR-COOLDOWN-ACTIVE)
        
        (let (
            (multiplier (get point-multiplier partner-data))
            (final-points (/ (* base-points multiplier) u100))
            (activity-count (default-to u0 (map-get? UserCrossContractCount user)))
        )
            ;; Record activity hash to prevent duplicates
            (map-set ActivityHashes activity-hash
                {
                    user: user,
                    contract: contract-caller,
                    processed-block: burn-block-height
                }
            )
            
            ;; Log detailed activity
            (map-set CrossContractActivities
                { user: user, activity-id: activity-count }
                {
                    contract: contract-caller,
                    activity-type: activity-type,
                    points-earned: final-points,
                    timestamp: burn-block-height,
                    hash: activity-hash
                }
            )
            
            ;; Update counters
            (map-set UserCrossContractCount user (+ activity-count u1))
            (map-set PartnerContracts contract-caller
                (merge partner-data { total-activities: (+ (get total-activities partner-data) u1) })
            )
            
            ;; Add points to user's regular account
            (unwrap! (log-contract-activity user (/ final-points u10)) ERR-BUFFER-OVERFLOW)
            
            (print { event: "cross-contract-activity", user: user, contract: contract-caller, points: final-points })
            (ok final-points)
        )
    )
)

;; Read-only: Get Partner Contract Info
(define-read-only (get-partner-contract (contract-address principal))
    (map-get? PartnerContracts contract-address)
)

;; Read-only: Check Activity Hash
(define-read-only (is-activity-processed (activity-hash (buff 32)))
    (is-some (map-get? ActivityHashes activity-hash))
)

;; Read-only: Get Cross-Contract Activity
(define-read-only (get-cross-contract-activity (user principal) (activity-id uint))
    (map-get? CrossContractActivities { user: user, activity-id: activity-id })
)

;; Admin: Update Partner Status
(define-public (update-partner-status (contract-address principal) (active bool))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (let ((partner-data (unwrap! (map-get? PartnerContracts contract-address) ERR-USER-NOT-FOUND)))
            (map-set PartnerContracts contract-address (merge partner-data { active: active }))
            (print { event: "partner-status-updated", contract: contract-address, active: active })
            (ok true)
        )
    )
)
;; ============================================================================
;; ADVANCED ANALYTICS SYSTEM
;; ============================================================================

;; Analytics Data Storage
(define-map UserEngagementMetrics
    principal
    {
        total-sessions: uint,
        avg-session-length: uint,
        last-session-block: uint,
        retention-score: uint,
        engagement-trend: uint ;; 0=declining, 1=stable, 2=growing
    }
)

(define-map SystemHealthMetrics
    uint ;; metric-type: 0=daily, 1=weekly, 2=monthly
    {
        active-users: uint,
        total-activities: uint,
        points-distributed: uint,
        avg-user-points: uint,
        timestamp: uint
    }
)

(define-map PerformanceTrends
    { user: principal, period: uint }
    {
        points-earned: uint,
        activities-completed: uint,
        rank-change: int,
        period-start: uint,
        period-end: uint
    }
)

(define-data-var analytics-enabled bool true)

;; Public: Update User Engagement
(define-public (update-user-engagement (user principal) (session-length uint))
    (begin
        (asserts! (var-get analytics-enabled) (ok false))
        
        (let (
            (current-metrics (default-to 
                {
                    total-sessions: u0,
                    avg-session-length: u0,
                    last-session-block: u0,
                    retention-score: u100,
                    engagement-trend: u1
                }
                (map-get? UserEngagementMetrics user)
            ))
            (new-sessions (+ (get total-sessions current-metrics) u1))
            (new-avg (/ (+ (* (get avg-session-length current-metrics) (get total-sessions current-metrics)) session-length) new-sessions))
        )
            (map-set UserEngagementMetrics user
                (merge current-metrics {
                    total-sessions: new-sessions,
                    avg-session-length: new-avg,
                    last-session-block: burn-block-height
                })
            )
            (ok true)
        )
    )
)

;; Admin: Record System Health Metrics
(define-public (record-system-health 
    (metric-type uint)
    (active-users uint)
    (total-activities uint)
    (points-distributed uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= metric-type u2) ERR-INVALID-POINTS)
        
        (let ((avg-points (if (> active-users u0) (/ points-distributed active-users) u0)))
            (map-set SystemHealthMetrics metric-type
                {
                    active-users: active-users,
                    total-activities: total-activities,
                    points-distributed: points-distributed,
                    avg-user-points: avg-points,
                    timestamp: burn-block-height
                }
            )
            (print { event: "system-health-recorded", metric-type: metric-type, active-users: active-users })
            (ok true)
        )
    )
)

;; Public: Record Performance Trend
(define-public (record-performance-trend 
    (user principal)
    (period uint)
    (points-earned uint)
    (activities-completed uint)
    (rank-change int))
    (begin
        (map-set PerformanceTrends { user: user, period: period }
            {
                points-earned: points-earned,
                activities-completed: activities-completed,
                rank-change: rank-change,
                period-start: (- burn-block-height u1000), ;; Approximate period start
                period-end: burn-block-height
            }
        )
        (ok true)
    )
)

;; Read-only: Get User Engagement Metrics
(define-read-only (get-user-engagement (user principal))
    (map-get? UserEngagementMetrics user)
)

;; Read-only: Get System Health
(define-read-only (get-system-health (metric-type uint))
    (map-get? SystemHealthMetrics metric-type)
)

;; Read-only: Get Performance Trend
(define-read-only (get-performance-trend (user principal) (period uint))
    (map-get? PerformanceTrends { user: user, period: period })
)

;; Read-only: Calculate Retention Rate
(define-read-only (calculate-retention-rate (user principal))
    (let (
        (metrics (map-get? UserEngagementMetrics user))
        (user-stats (get-user-stats user))
    )
        (match metrics
            user-metrics 
                (let (
                    (days-since-last (/ (- burn-block-height (get last-session-block user-metrics)) BLOCKS-PER-DAY))
                    (total-sessions (get total-sessions user-metrics))
                )
                    (ok (if (< days-since-last u7) u100 ;; Active within week = 100%
                        (if (< days-since-last u30) u75 ;; Active within month = 75%
                            (if (> total-sessions u10) u50 ;; Has history = 50%
                                u25 ;; Low retention = 25%
                            )
                        )
                    ))
                )
            (ok u0) ;; No metrics = 0%
        )
    )
)

;; Admin: Toggle Analytics
(define-public (toggle-analytics (enabled bool))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (ok (var-set analytics-enabled enabled))
    )
)
;; ============================================================================
;; MILESTONE TRACKING SYSTEM
;; ============================================================================

;; Milestone Definitions
(define-map Milestones
    uint ;; milestone-id
    {
        name: (string-ascii 50),
        description: (string-ascii 100),
        target-value: uint,
        reward-points: uint,
        prerequisite: (optional uint),
        milestone-type: uint, ;; 0=points, 1=activities, 2=streak, 3=referrals
        active: bool
    }
)

;; User Milestone Progress
(define-map UserMilestoneProgress
    { user: principal, milestone-id: uint }
    {
        current-value: uint,
        completed: bool,
        completed-block: (optional uint),
        reward-claimed: bool
    }
)

(define-data-var next-milestone-id uint u1)

;; Milestone Type Constants
(define-constant MILESTONE-TYPE-POINTS u0)
(define-constant MILESTONE-TYPE-ACTIVITIES u1)
(define-constant MILESTONE-TYPE-STREAK u2)
(define-constant MILESTONE-TYPE-REFERRALS u3)

;; Admin: Create Milestone
(define-public (create-milestone
    (name (string-ascii 50))
    (description (string-ascii 100))
    (target-value uint)
    (reward-points uint)
    (milestone-type uint)
    (prerequisite (optional uint)))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> target-value u0) ERR-INVALID-POINTS)
        (asserts! (> reward-points u0) ERR-INVALID-POINTS)
        (asserts! (<= milestone-type u3) ERR-INVALID-POINTS)
        
        ;; Validate prerequisite exists if provided
        (match prerequisite
            prereq-id (asserts! (is-some (map-get? Milestones prereq-id)) ERR-USER-NOT-FOUND)
            true
        )
        
        (let ((milestone-id (var-get next-milestone-id)))
            (map-set Milestones milestone-id
                {
                    name: name,
                    description: description,
                    target-value: target-value,
                    reward-points: reward-points,
                    prerequisite: prerequisite,
                    milestone-type: milestone-type,
                    active: true
                }
            )
            (var-set next-milestone-id (+ milestone-id u1))
            (print { event: "milestone-created", milestone-id: milestone-id, name: name })
            (ok milestone-id)
        )
    )
)

;; Public: Update Milestone Progress
(define-public (update-milestone-progress (user principal) (milestone-id uint) (new-value uint))
    (let (
        (milestone-data (unwrap! (map-get? Milestones milestone-id) ERR-USER-NOT-FOUND))
        (current-progress (default-to 
            {
                current-value: u0,
                completed: false,
                completed-block: none,
                reward-claimed: false
            }
            (map-get? UserMilestoneProgress { user: user, milestone-id: milestone-id })
        ))
    )
        (asserts! (get active milestone-data) ERR-CONTRACT-PAUSED)
        (asserts! (not (get completed current-progress)) (ok true)) ;; Already completed
        
        ;; Check prerequisites
        (match (get prerequisite milestone-data)
            prereq-id 
                (let ((prereq-progress (map-get? UserMilestoneProgress { user: user, milestone-id: prereq-id })))
                    (asserts! (and (is-some prereq-progress) (get completed (unwrap-panic prereq-progress))) ERR-NOT-AUTHORIZED)
                )
            true
        )
        
        (let (
            (updated-value (max (get current-value current-progress) new-value))
            (is-completed (>= updated-value (get target-value milestone-data)))
        )
            (map-set UserMilestoneProgress { user: user, milestone-id: milestone-id }
                {
                    current-value: updated-value,
                    completed: is-completed,
                    completed-block: (if is-completed (some burn-block-height) none),
                    reward-claimed: false
                }
            )
            
            (if is-completed
                (print { event: "milestone-completed", user: user, milestone-id: milestone-id })
                (print { event: "milestone-progress", user: user, milestone-id: milestone-id, progress: updated-value })
            )
            (ok is-completed)
        )
    )
)

;; Public: Claim Milestone Reward
(define-public (claim-milestone-reward (milestone-id uint))
    (let (
        (milestone-data (unwrap! (map-get? Milestones milestone-id) ERR-USER-NOT-FOUND))
        (progress-data (unwrap! (map-get? UserMilestoneProgress { user: tx-sender, milestone-id: milestone-id }) ERR-USER-NOT-FOUND))
    )
        (asserts! (get completed progress-data) ERR-NOT-AUTHORIZED)
        (asserts! (not (get reward-claimed progress-data)) ERR-COOLDOWN-ACTIVE)
        
        ;; Mark reward as claimed
        (map-set UserMilestoneProgress { user: tx-sender, milestone-id: milestone-id }
            (merge progress-data { reward-claimed: true })
        )
        
        ;; Add to claimable rewards
        (let ((current-claimable (default-to u0 (map-get? ClaimableRewards tx-sender))))
            (map-set ClaimableRewards tx-sender (+ current-claimable (get reward-points milestone-data)))
        )
        
        (print { event: "milestone-reward-claimed", user: tx-sender, milestone-id: milestone-id, reward: (get reward-points milestone-data) })
        (ok (get reward-points milestone-data))
    )
)

;; Read-only: Get Milestone Info
(define-read-only (get-milestone-info (milestone-id uint))
    (map-get? Milestones milestone-id)
)

;; Read-only: Get User Milestone Progress
(define-read-only (get-user-milestone-progress (user principal) (milestone-id uint))
    (map-get? UserMilestoneProgress { user: user, milestone-id: milestone-id })
)

;; Read-only: Check Milestone Eligibility
(define-read-only (is-milestone-eligible (user principal) (milestone-id uint))
    (let ((milestone-data (unwrap! (map-get? Milestones milestone-id) (err ERR-USER-NOT-FOUND))))
        (match (get prerequisite milestone-data)
            prereq-id 
                (let ((prereq-progress (map-get? UserMilestoneProgress { user: user, milestone-id: prereq-id })))
                    (ok (and (is-some prereq-progress) (get completed (unwrap-panic prereq-progress))))
                )
            (ok true)
        )
    )
)

;; Private: Auto-update milestones based on user stats
(define-private (auto-update-milestones (user principal))
    (let ((user-stats (unwrap! (get-user-stats user) false)))
        ;; Update points-based milestones
        (update-milestone-progress user u1 (get total-points user-stats)) ;; Assuming milestone 1 is points-based
        ;; Update activity-based milestones  
        (update-milestone-progress user u2 (+ (get contract-impact-points user-stats) (get library-usage-points user-stats))) ;; Assuming milestone 2 is activity-based
        true
    )
)
;; ============================================================================
;; DYNAMIC REWARD POOLS
;; ============================================================================

;; Reward Pool Management
(define-map RewardPools
    uint ;; pool-id
    {
        name: (string-ascii 30),
        total-amount: uint,
        distributed-amount: uint,
        participation-threshold: uint,
        distribution-rule: uint, ;; 0=equal, 1=proportional, 2=tiered
        active: bool,
        created-block: uint,
        end-block: uint
    }
)

;; Pool Participation Tracking
(define-map PoolParticipants
    { pool-id: uint, participant: principal }
    {
        contribution-score: uint,
        reward-earned: uint,
        claimed: bool
    }
)

(define-map PoolStats
    uint ;; pool-id
    {
        total-participants: uint,
        total-contribution: uint,
        avg-contribution: uint
    }
)

(define-data-var next-pool-id uint u1)

;; Distribution Rule Constants
(define-constant DISTRIBUTION-EQUAL u0)
(define-constant DISTRIBUTION-PROPORTIONAL u1)
(define-constant DISTRIBUTION-TIERED u2)

;; Admin: Create Reward Pool
(define-public (create-reward-pool
    (name (string-ascii 30))
    (total-amount uint)
    (participation-threshold uint)
    (distribution-rule uint)
    (duration-blocks uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> total-amount u0) ERR-INVALID-POINTS)
        (asserts! (<= distribution-rule u2) ERR-INVALID-POINTS)
        
        (let ((pool-id (var-get next-pool-id)))
            (map-set RewardPools pool-id
                {
                    name: name,
                    total-amount: total-amount,
                    distributed-amount: u0,
                    participation-threshold: participation-threshold,
                    distribution-rule: distribution-rule,
                    active: true,
                    created-block: burn-block-height,
                    end-block: (+ burn-block-height duration-blocks)
                }
            )
            
            (map-set PoolStats pool-id
                {
                    total-participants: u0,
                    total-contribution: u0,
                    avg-contribution: u0
                }
            )
            
            (var-set next-pool-id (+ pool-id u1))
            (print { event: "reward-pool-created", pool-id: pool-id, name: name, amount: total-amount })
            (ok pool-id)
        )
    )
)

;; Public: Participate in Pool
(define-public (participate-in-pool (pool-id uint) (contribution-score uint))
    (let (
        (pool-data (unwrap! (map-get? RewardPools pool-id) ERR-USER-NOT-FOUND))
        (pool-stats (unwrap! (map-get? PoolStats pool-id) ERR-USER-NOT-FOUND))
        (existing-participation (map-get? PoolParticipants { pool-id: pool-id, participant: tx-sender }))
    )
        (asserts! (get active pool-data) ERR-CONTRACT-PAUSED)
        (asserts! (<= burn-block-height (get end-block pool-data)) ERR-COOLDOWN-ACTIVE)
        (asserts! (>= contribution-score (get participation-threshold pool-data)) ERR-INVALID-POINTS)
        
        (match existing-participation
            existing-data
                ;; Update existing participation
                (map-set PoolParticipants { pool-id: pool-id, participant: tx-sender }
                    (merge existing-data { contribution-score: (+ (get contribution-score existing-data) contribution-score) })
                )
            ;; New participation
            (begin
                (map-set PoolParticipants { pool-id: pool-id, participant: tx-sender }
                    {
                        contribution-score: contribution-score,
                        reward-earned: u0,
                        claimed: false
                    }
                )
                ;; Update pool stats
                (map-set PoolStats pool-id
                    (merge pool-stats { total-participants: (+ (get total-participants pool-stats) u1) })
                )
            )
        )
        
        ;; Update total contribution
        (let ((new-total-contribution (+ (get total-contribution pool-stats) contribution-score)))
            (map-set PoolStats pool-id
                (merge pool-stats { 
                    total-contribution: new-total-contribution,
                    avg-contribution: (/ new-total-contribution (get total-participants pool-stats))
                })
            )
        )
        
        (print { event: "pool-participation", pool-id: pool-id, participant: tx-sender, contribution: contribution-score })
        (ok true)
    )
)

;; Admin: Distribute Pool Rewards
(define-public (distribute-pool-rewards (pool-id uint))
    (let (
        (pool-data (unwrap! (map-get? RewardPools pool-id) ERR-USER-NOT-FOUND))
        (pool-stats (unwrap! (map-get? PoolStats pool-id) ERR-USER-NOT-FOUND))
    )
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (get active pool-data) ERR-CONTRACT-PAUSED)
        (asserts! (> burn-block-height (get end-block pool-data)) ERR-COOLDOWN-ACTIVE)
        
        ;; Mark pool as inactive
        (map-set RewardPools pool-id (merge pool-data { active: false }))
        
        (print { event: "pool-distribution-started", pool-id: pool-id, participants: (get total-participants pool-stats) })
        (ok true)
    )
)

;; Public: Claim Pool Reward
(define-public (claim-pool-reward (pool-id uint))
    (let (
        (pool-data (unwrap! (map-get? RewardPools pool-id) ERR-USER-NOT-FOUND))
        (participation-data (unwrap! (map-get? PoolParticipants { pool-id: pool-id, participant: tx-sender }) ERR-USER-NOT-FOUND))
        (pool-stats (unwrap! (map-get? PoolStats pool-id) ERR-USER-NOT-FOUND))
    )
        (asserts! (not (get active pool-data)) ERR-CONTRACT-PAUSED) ;; Pool must be closed
        (asserts! (not (get claimed participation-data)) ERR-COOLDOWN-ACTIVE)
        
        ;; Calculate reward based on distribution rule
        (let (
            (reward-amount (calculate-pool-reward 
                pool-id 
                (get contribution-score participation-data)
                (get total-contribution pool-stats)
                (get total-participants pool-stats)
                (get distribution-rule pool-data)
                (get total-amount pool-data)
            ))
        )
            ;; Mark as claimed
            (map-set PoolParticipants { pool-id: pool-id, participant: tx-sender }
                (merge participation-data { 
                    reward-earned: reward-amount,
                    claimed: true 
                })
            )
            
            ;; Add to claimable rewards
            (let ((current-claimable (default-to u0 (map-get? ClaimableRewards tx-sender))))
                (map-set ClaimableRewards tx-sender (+ current-claimable reward-amount))
            )
            
            (print { event: "pool-reward-claimed", pool-id: pool-id, participant: tx-sender, reward: reward-amount })
            (ok reward-amount)
        )
    )
)

;; Private: Calculate Pool Reward
(define-private (calculate-pool-reward 
    (pool-id uint)
    (user-contribution uint)
    (total-contribution uint)
    (total-participants uint)
    (distribution-rule uint)
    (total-pool uint))
    (if (is-eq distribution-rule DISTRIBUTION-EQUAL)
        ;; Equal distribution
        (/ total-pool total-participants)
        (if (is-eq distribution-rule DISTRIBUTION-PROPORTIONAL)
            ;; Proportional to contribution
            (/ (* total-pool user-contribution) total-contribution)
            ;; Tiered distribution (simplified)
            (let ((contribution-ratio (/ (* user-contribution u100) total-contribution)))
                (if (> contribution-ratio u50) ;; Top 50% contributors
                    (/ (* total-pool u60) u100) ;; Get 60% share
                    (/ (* total-pool u40) u100) ;; Others get 40% share
                )
            )
        )
    )
)

;; Read-only: Get Pool Info
(define-read-only (get-pool-info (pool-id uint))
    (map-get? RewardPools pool-id)
)

;; Read-only: Get Pool Participation
(define-read-only (get-pool-participation (pool-id uint) (participant principal))
    (map-get? PoolParticipants { pool-id: pool-id, participant: participant })
)

;; Read-only: Get Pool Stats
(define-read-only (get-pool-stats (pool-id uint))
    (map-get? PoolStats pool-id)
)
;; ============================================================================
;; ENHANCED API AND DATA EXPORT
;; ============================================================================

;; Pagination Support
(define-map PaginatedQueries
    { query-type: uint, offset: uint, limit: uint }
    {
        results: (list 50 principal),
        total-count: uint,
        has-more: bool
    }
)

;; Query Type Constants
(define-constant QUERY-TYPE-LEADERBOARD u0)
(define-constant QUERY-TYPE-GUILD-MEMBERS u1)
(define-constant QUERY-TYPE-SEASON-PARTICIPANTS u2)

;; Enhanced Event Emission
(define-map EventLog
    uint ;; event-id
    {
        event-type: (string-ascii 30),
        user: (optional principal),
        data: (string-ascii 200),
        timestamp: uint
    }
)

(define-data-var next-event-id uint u1)

;; Public: Export User Data
(define-public (export-user-data (user principal))
    (let (
        (user-stats (get-user-stats user))
        (user-tier (unwrap-panic (get-user-tier user)))
        (user-streak (get-user-streak user))
        (user-guild (get-user-guild user))
        (engagement-metrics (get-user-engagement user))
    )
        (print {
            event: "user-data-export",
            user: user,
            stats: user-stats,
            tier: user-tier,
            streak: user-streak,
            guild: user-guild,
            engagement: engagement-metrics,
            export-timestamp: burn-block-height
        })
        (ok true)
    )
)

;; Read-only: Get Paginated Leaderboard
(define-read-only (get-paginated-leaderboard (offset uint) (limit uint))
    (let (
        (capped-limit (if (> limit u50) u50 limit))
        (global-stats (get-global-stats))
    )
        (ok {
            offset: offset,
            limit: capped-limit,
            total-users: (get total-users global-stats),
            has-more: (> (get total-users global-stats) (+ offset capped-limit)),
            note: "Full leaderboard requires off-chain indexing"
        })
    )
)

;; Read-only: Get User Activity Summary
(define-read-only (get-user-activity-summary (user principal))
    (let (
        (stats (get-user-stats user))
        (log-count (get-user-log-count user))
        (cross-contract-count (default-to u0 (map-get? UserCrossContractCount user)))
        (guild-info (get-user-guild user))
    )
        (match stats
            user-stats (ok {
                total-points: (get total-points user-stats),
                contract-points: (get contract-impact-points user-stats),
                library-points: (get library-usage-points user-stats),
                github-points: (get github-contrib-points user-stats),
                reputation: (get reputation-score user-stats),
                activity-count: log-count,
                cross-contract-activities: cross-contract-count,
                guild-membership: guild-info,
                last-activity: (get last-activity-block user-stats)
            })
            (err ERR-USER-NOT-FOUND)
        )
    )
)

;; Read-only: Get System Overview
(define-read-only (get-system-overview)
    (let (
        (global-stats (get-global-stats))
        (current-season (var-get current-season-id))
        (total-guilds (var-get next-guild-id))
        (total-pools (var-get next-pool-id))
        (total-milestones (var-get next-milestone-id))
    )
        (ok {
            total-users: (get total-users global-stats),
            total-points-distributed: (get total-points-distributed global-stats),
            top-score: (get top-score global-stats),
            current-season: current-season,
            total-guilds: total-guilds,
            total-reward-pools: total-pools,
            total-milestones: total-milestones,
            contract-paused: (var-get contract-paused),
            analytics-enabled: (var-get analytics-enabled)
        })
    )
)

;; Public: Log Custom Event
(define-public (log-custom-event 
    (event-type (string-ascii 30))
    (user (optional principal))
    (data (string-ascii 200)))
    (let ((event-id (var-get next-event-id)))
        (map-set EventLog event-id
            {
                event-type: event-type,
                user: user,
                data: data,
                timestamp: burn-block-height
            }
        )
        (var-set next-event-id (+ event-id u1))
        (print { event: "custom-event-logged", event-id: event-id, type: event-type })
        (ok event-id)
    )
)

;; Read-only: Get Event Log Entry
(define-read-only (get-event-log (event-id uint))
    (map-get? EventLog event-id)
)

;; Read-only: Get Comprehensive User Profile
(define-read-only (get-user-profile (user principal))
    (let (
        (basic-stats (get-user-stats user))
        (tier (unwrap-panic (get-user-tier user)))
        (level (unwrap-panic (get-user-level user)))
        (reputation (unwrap-panic (get-user-reputation user)))
        (streak (get-user-streak user))
        (guild (get-user-guild user))
        (engagement (get-user-engagement user))
        (claimable (unwrap-panic (get-claimable-rewards user)))
    )
        (match basic-stats
            stats (ok {
                user: user,
                points: (get total-points stats),
                tier: tier,
                level: level,
                reputation: reputation,
                streak: (get current-streak streak),
                guild-id: guild,
                engagement-score: (match engagement eng (get retention-score eng) u0),
                claimable-rewards: claimable,
                last-activity: (get last-activity-block stats)
            })
            (err ERR-USER-NOT-FOUND)
        )
    )
)

;; Read-only: Generate Mock Data for Testing
(define-read-only (generate-mock-leaderboard)
    (ok {
        mock-users: (list 
            "SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE"
            "SP2JXKMSH007NPYAQHKJPQMAQYAD90NQGTVJVQ02B"
            "SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9"
        ),
        mock-scores: (list u5000 u4500 u4000),
        note: "Mock data for integration testing"
    })
)
;; ============================================================================
;; EXPANDED ACHIEVEMENT SYSTEM
;; ============================================================================

;; Extended Achievement Categories
(define-constant ACHIEVEMENT-SOCIAL-BUTTERFLY u11) ;; Join guild + refer 5 users
(define-constant ACHIEVEMENT-SEASON-CHAMPION u12) ;; Win a season
(define-constant ACHIEVEMENT-MILESTONE-MASTER u13) ;; Complete 10 milestones
(define-constant ACHIEVEMENT-CROSS-CHAIN-EXPERT u14) ;; Activity on 5+ partner contracts
(define-constant ACHIEVEMENT-ANALYTICS-GURU u15) ;; High engagement metrics
(define-constant ACHIEVEMENT-POOL-WINNER u16) ;; Win reward pool distribution
(define-constant ACHIEVEMENT-STREAK-LEGEND u17) ;; 100+ day streak
(define-constant ACHIEVEMENT-POINT-MILLIONAIRE u18) ;; 1M+ points
(define-constant ACHIEVEMENT-GUILD-LEADER u19) ;; Lead successful guild
(define-constant ACHIEVEMENT-EARLY-ADOPTER u20) ;; First 100 users

;; Achievement Progress Tracking
(define-map AchievementProgress
    { user: principal, achievement-id: uint }
    {
        current-progress: uint,
        target-progress: uint,
        progress-percentage: uint,
        last-updated: uint
    }
)

;; Achievement Categories
(define-map AchievementCategories
    uint ;; category-id
    {
        name: (string-ascii 30),
        description: (string-ascii 100),
        total-achievements: uint
    }
)

;; Category Constants
(define-constant CATEGORY-ENGAGEMENT u1)
(define-constant CATEGORY-SOCIAL u2)
(define-constant CATEGORY-COMPETITIVE u3)
(define-constant CATEGORY-TECHNICAL u4)
(define-constant CATEGORY-MILESTONE u5)

;; Public: Update Achievement Progress
(define-public (update-achievement-progress 
    (user principal)
    (achievement-id uint)
    (progress-increment uint))
    (let (
        (current-progress (default-to 
            {
                current-progress: u0,
                target-progress: u100,
                progress-percentage: u0,
                last-updated: u0
            }
            (map-get? AchievementProgress { user: user, achievement-id: achievement-id })
        ))
        (new-progress (+ (get current-progress current-progress) progress-increment))
        (target (get target-progress current-progress))
        (percentage (/ (* new-progress u100) target))
    )
        (map-set AchievementProgress { user: user, achievement-id: achievement-id }
            {
                current-progress: new-progress,
                target-progress: target,
                progress-percentage: percentage,
                last-updated: burn-block-height
            }
        )
        
        ;; Check if achievement should be unlocked
        (if (>= percentage u100)
            (unlock-achievement user achievement-id ACHIEVEMENT-REWARD-MEDIUM)
            false
        )
        
        (ok true)
    )
)

;; Public: Check Multiple Achievements
(define-public (check-comprehensive-achievements (user principal))
    (let (
        (stats (unwrap! (get-user-stats user) ERR-USER-NOT-FOUND))
        (streak (get current-streak (get-user-streak user)))
        (guild-id (get-user-guild user))
        (cross-contract-count (default-to u0 (map-get? UserCrossContractCount user)))
    )
        ;; Social Butterfly: Guild + Referrals
        (if (and (is-some guild-id) (>= (len (default-to (list) (map-get? Referrals user))) u5))
            (unlock-achievement user ACHIEVEMENT-SOCIAL-BUTTERFLY ACHIEVEMENT-REWARD-LARGE)
            false
        )
        
        ;; Cross-Chain Expert
        (if (>= cross-contract-count u5)
            (unlock-achievement user ACHIEVEMENT-CROSS-CHAIN-EXPERT ACHIEVEMENT-REWARD-MEDIUM)
            false
        )
        
        ;; Streak Legend
        (if (>= streak u100)
            (unlock-achievement user ACHIEVEMENT-STREAK-LEGEND ACHIEVEMENT-REWARD-LARGE)
            false
        )
        
        ;; Point Millionaire
        (if (>= (get total-points stats) u1000000)
            (unlock-achievement user ACHIEVEMENT-POINT-MILLIONAIRE ACHIEVEMENT-REWARD-LARGE)
            false
        )
        
        (ok true)
    )
)

;; Admin: Create Achievement Category
(define-public (create-achievement-category
    (category-id uint)
    (name (string-ascii 30))
    (description (string-ascii 100)))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (map-set AchievementCategories category-id
            {
                name: name,
                description: description,
                total-achievements: u0
            }
        )
        (print { event: "achievement-category-created", category-id: category-id, name: name })
        (ok true)
    )
)

;; Read-only: Get Achievement Progress
(define-read-only (get-achievement-progress (user principal) (achievement-id uint))
    (map-get? AchievementProgress { user: user, achievement-id: achievement-id })
)

;; Read-only: Get User Achievement Summary
(define-read-only (get-user-achievement-summary (user principal))
    (let (
        (total-unlocked (fold count-achievements 
            (list ACHIEVEMENT-FIRST-ACTIVITY ACHIEVEMENT-STREAK-WEEK ACHIEVEMENT-STREAK-MONTH 
                  ACHIEVEMENT-REFERRAL-CHAMPION ACHIEVEMENT-LIBRARY-MASTER ACHIEVEMENT-GITHUB-CONTRIBUTOR
                  ACHIEVEMENT-TIER-GOLD ACHIEVEMENT-TIER-PLATINUM ACHIEVEMENT-TIER-DIAMOND
                  ACHIEVEMENT-POINTS-10K ACHIEVEMENT-SOCIAL-BUTTERFLY ACHIEVEMENT-SEASON-CHAMPION)
            { user: user, count: u0 }
        ))
    )
        (ok {
            total-achievements: (get count total-unlocked),
            recent-achievements: (list), ;; Would need additional tracking for recent ones
            progress-summary: "Achievement system active"
        })
    )
)

;; Private: Count Achievements Helper
(define-private (count-achievements (achievement-id uint) (acc { user: principal, count: uint }))
    (if (has-achievement (get user acc) achievement-id)
        { user: (get user acc), count: (+ (get count acc) u1) }
        acc
    )
)

;; Read-only: Get Achievement Category
(define-read-only (get-achievement-category (category-id uint))
    (map-get? AchievementCategories category-id)
)
;; ============================================================================
;; ENHANCED SECURITY AND VALIDATION
;; ============================================================================

;; Rate Limiting
(define-map UserRateLimits
    principal
    {
        last-action-block: uint,
        action-count: uint,
        cooldown-until: uint
    }
)

;; Security Constants
(define-constant MAX-ACTIONS-PER-PERIOD u10)
(define-constant RATE-LIMIT-PERIOD u100) ;; blocks
(define-constant COOLDOWN-PENALTY u500) ;; blocks

;; Input Validation
(define-private (validate-string-input (input (string-ascii 50)))
    (and (> (len input) u0) (<= (len input) u50))
)

;; Rate Limiting Check
(define-private (check-rate-limit (user principal))
    (let (
        (rate-data (default-to 
            {
                last-action-block: u0,
                action-count: u0,
                cooldown-until: u0
            }
            (map-get? UserRateLimits user)
        ))
        (current-block burn-block-height)
    )
        ;; Check if in cooldown
        (asserts! (< current-block (get cooldown-until rate-data)) (ok false))
        
        ;; Reset counter if period expired
        (let (
            (blocks-since-last (- current-block (get last-action-block rate-data)))
            (reset-counter (> blocks-since-last RATE-LIMIT-PERIOD))
            (new-count (if reset-counter u1 (+ (get action-count rate-data) u1)))
        )
            ;; Check if exceeding rate limit
            (if (> new-count MAX-ACTIONS-PER-PERIOD)
                (begin
                    ;; Apply cooldown penalty
                    (map-set UserRateLimits user
                        (merge rate-data { 
                            cooldown-until: (+ current-block COOLDOWN-PENALTY),
                            action-count: u0
                        })
                    )
                    (ok false)
                )
                (begin
                    ;; Update rate limit data
                    (map-set UserRateLimits user
                        {
                            last-action-block: current-block,
                            action-count: new-count,
                            cooldown-until: (get cooldown-until rate-data)
                        }
                    )
                    (ok true)
                )
            )
        )
    )
)

;; Enhanced Input Validation
(define-private (validate-points-input (points uint))
    (and (> points u0) (<= points u1000000)) ;; Max 1M points per action
)

;; Overflow Protection Helper
(define-private (safe-add (a uint) (b uint))
    (let ((result (+ a b)))
        (asserts! (>= result a) ERR-BUFFER-OVERFLOW) ;; Check for overflow
        (ok result)
    )
)

;; Enhanced Authorization Check
(define-private (enhanced-auth-check (required-role uint))
    (let ((is-authorized (or (is-admin tx-sender) (is-eq required-role u0))))
        (asserts! is-authorized ERR-NOT-AUTHORIZED)
        (ok true)
    )
)

;; Public: Secure Activity Logging
(define-public (secure-log-activity 
    (user principal)
    (activity-type (string-ascii 20))
    (points uint))
    (begin
        ;; Rate limiting
        (asserts! (unwrap! (check-rate-limit tx-sender) ERR-COOLDOWN-ACTIVE) ERR-COOLDOWN-ACTIVE)
        
        ;; Input validation
        (asserts! (validate-string-input activity-type) ERR-INVALID-POINTS)
        (asserts! (validate-points-input points) ERR-INVALID-POINTS)
        
        ;; Contract not paused
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        
        ;; Log the activity
        (log-contract-activity user (/ points u10))
    )
)

;; Admin: Security Audit Log
(define-public (log-security-event 
    (event-type (string-ascii 30))
    (severity uint)
    (description (string-ascii 100)))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= severity u3) ERR-INVALID-POINTS) ;; 0=info, 1=warning, 2=error, 3=critical
        
        (print { 
            event: "security-audit",
            type: event-type,
            severity: severity,
            description: description,
            admin: tx-sender,
            timestamp: burn-block-height
        })
        (ok true)
    )
)
;; ============================================================================
;; NOTIFICATION AND ALERT SYSTEM
;; ============================================================================

;; Notification Types
(define-constant NOTIFICATION-ACHIEVEMENT u0)
(define-constant NOTIFICATION-TIER-UPGRADE u1)
(define-constant NOTIFICATION-SEASON-END u2)
(define-constant NOTIFICATION-GUILD-INVITE u3)
(define-constant NOTIFICATION-REWARD-AVAILABLE u4)

;; User Notifications
(define-map UserNotifications
    { user: principal, notification-id: uint }
    {
        notification-type: uint,
        title: (string-ascii 50),
        message: (string-ascii 100),
        read: bool,
        created-block: uint,
        expires-block: uint
    }
)

(define-map UserNotificationCount principal uint)

;; System Alerts
(define-map SystemAlerts
    uint ;; alert-id
    {
        alert-type: uint,
        message: (string-ascii 100),
        severity: uint,
        active: bool,
        created-block: uint
    }
)

(define-data-var next-alert-id uint u1)

;; Public: Create User Notification
(define-public (create-notification
    (user principal)
    (notification-type uint)
    (title (string-ascii 50))
    (message (string-ascii 100))
    (expires-in-blocks uint))
    (let (
        (notification-count (default-to u0 (map-get? UserNotificationCount user)))
        (notification-id notification-count)
    )
        (asserts! (<= notification-type u4) ERR-INVALID-POINTS)
        (asserts! (validate-string-input title) ERR-INVALID-POINTS)
        
        (map-set UserNotifications { user: user, notification-id: notification-id }
            {
                notification-type: notification-type,
                title: title,
                message: message,
                read: false,
                created-block: burn-block-height,
                expires-block: (+ burn-block-height expires-in-blocks)
            }
        )
        
        (map-set UserNotificationCount user (+ notification-count u1))
        
        (print { event: "notification-created", user: user, type: notification-type, title: title })
        (ok notification-id)
    )
)

;; Public: Mark Notification as Read
(define-public (mark-notification-read (notification-id uint))
    (let (
        (notification-data (unwrap! (map-get? UserNotifications { user: tx-sender, notification-id: notification-id }) ERR-USER-NOT-FOUND))
    )
        (map-set UserNotifications { user: tx-sender, notification-id: notification-id }
            (merge notification-data { read: true })
        )
        (ok true)
    )
)

;; Admin: Create System Alert
(define-public (create-system-alert
    (alert-type uint)
    (message (string-ascii 100))
    (severity uint))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= severity u3) ERR-INVALID-POINTS)
        
        (let ((alert-id (var-get next-alert-id)))
            (map-set SystemAlerts alert-id
                {
                    alert-type: alert-type,
                    message: message,
                    severity: severity,
                    active: true,
                    created-block: burn-block-height
                }
            )
            (var-set next-alert-id (+ alert-id u1))
            
            (print { event: "system-alert-created", alert-id: alert-id, severity: severity })
            (ok alert-id)
        )
    )
)

;; Read-only: Get User Notifications
(define-read-only (get-user-notifications (user principal) (limit uint))
    (let ((notification-count (default-to u0 (map-get? UserNotificationCount user))))
        (ok {
            total-notifications: notification-count,
            unread-count: u0, ;; Would need additional tracking
            has-more: (> notification-count limit)
        })
    )
)

;; Read-only: Get System Alerts
(define-read-only (get-active-system-alerts)
    (ok {
        total-alerts: (var-get next-alert-id),
        note: "Active alerts require iteration"
    })
)
;; ============================================================================
;; ADVANCED LEADERBOARD FEATURES
;; ============================================================================

;; Leaderboard Categories
(define-map CategoryLeaderboards
    { category: uint, rank: uint }
    { user: principal, score: uint }
)

;; Category Constants
(define-constant LEADERBOARD-OVERALL u0)
(define-constant LEADERBOARD-WEEKLY u1)
(define-constant LEADERBOARD-MONTHLY u2)
(define-constant LEADERBOARD-SEASONAL u3)
(define-constant LEADERBOARD-GUILD u4)

;; Leaderboard Metadata
(define-map LeaderboardMeta
    uint ;; category
    {
        name: (string-ascii 30),
        description: (string-ascii 100),
        last-updated: uint,
        total-entries: uint
    }
)

;; User Rankings History
(define-map UserRankingHistory
    { user: principal, period: uint }
    {
        rank: uint,
        score: uint,
        category: uint,
        recorded-block: uint
    }
)

;; Admin: Update Category Leaderboard
(define-public (update-category-leaderboard
    (category uint)
    (rankings (list 10 { user: principal, score: uint })))
    (begin
        (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= category u4) ERR-INVALID-POINTS)
        
        ;; Update leaderboard entries
        (map update-leaderboard-entry rankings)
        
        ;; Update metadata
        (map-set LeaderboardMeta category
            {
                name: "Category Leaderboard",
                description: "Updated leaderboard rankings",
                last-updated: burn-block-height,
                total-entries: (len rankings)
            }
        )
        
        (print { event: "leaderboard-updated", category: category, entries: (len rankings) })
        (ok true)
    )
)

;; Private: Update Leaderboard Entry Helper
(define-private (update-leaderboard-entry (entry { user: principal, score: uint }))
    (let ((rank u1)) ;; Simplified ranking
        (map-set CategoryLeaderboards { category: LEADERBOARD-OVERALL, rank: rank }
            { user: (get user entry), score: (get score entry) }
        )
        true
    )
)

;; Public: Record User Ranking
(define-public (record-user-ranking
    (user principal)
    (rank uint)
    (score uint)
    (category uint)
    (period uint))
    (begin
        (map-set UserRankingHistory { user: user, period: period }
            {
                rank: rank,
                score: score,
                category: category,
                recorded-block: burn-block-height
            }
        )
        (ok true)
    )
)

;; Read-only: Get Category Leaderboard
(define-read-only (get-category-leaderboard (category uint) (limit uint))
    (let ((meta (map-get? LeaderboardMeta category)))
        (ok {
            category: category,
            metadata: meta,
            note: "Full rankings require off-chain processing"
        })
    )
)

;; Read-only: Get User Ranking History
(define-read-only (get-user-ranking-history (user principal) (period uint))
    (map-get? UserRankingHistory { user: user, period: period })
)

;; Read-only: Calculate Rank Change
(define-read-only (calculate-rank-change (user principal) (current-period uint) (previous-period uint))
    (let (
        (current-rank (map-get? UserRankingHistory { user: user, period: current-period }))
        (previous-rank (map-get? UserRankingHistory { user: user, period: previous-period }))
    )
        (match current-rank
            current-data
                (match previous-rank
                    previous-data
                        (ok (- (get rank previous-data) (get rank current-data))) ;; Positive = improvement
                    (ok 0) ;; No previous data
                )
            (err ERR-USER-NOT-FOUND)
        )
    )
)
;; ============================================================================
;; REPUTATION AND TRUST SYSTEM
;; ============================================================================

;; Trust Scores
(define-map UserTrustScores
    principal
    {
        trust-score: uint,
        verification-level: uint,
        endorsements: uint,
        reports: uint,
        last-updated: uint
    }
)

;; Endorsements
(define-map UserEndorsements
    { endorser: principal, endorsed: principal }
    {
        endorsement-type: uint,
        message: (string-ascii 50),
        timestamp: uint,
        weight: uint
    }
)

;; Trust Level Constants
(define-constant TRUST-LEVEL-UNVERIFIED u0)
(define-constant TRUST-LEVEL-BASIC u1)
(define-constant TRUST-LEVEL-VERIFIED u2)
(define-constant TRUST-LEVEL-TRUSTED u3)
(define-constant TRUST-LEVEL-EXPERT u4)

;; Endorsement Types
(define-constant ENDORSEMENT-HELPFUL u0)
(define-constant ENDORSEMENT-SKILLED u1)
(define-constant ENDORSEMENT-TRUSTWORTHY u2)
(define-constant ENDORSEMENT-LEADER u3)

;; Public: Endorse User
(define-public (endorse-user
    (endorsed principal)
    (endorsement-type uint)
    (message (string-ascii 50)))
    (begin
        (asserts! (not (is-eq tx-sender endorsed)) ERR-INVALID-POINTS)
        (asserts! (<= endorsement-type u3) ERR-INVALID-POINTS)
        (asserts! (validate-string-input message) ERR-INVALID-POINTS)
        
        ;; Check if already endorsed
        (asserts! (is-none (map-get? UserEndorsements { endorser: tx-sender, endorsed: endorsed })) ERR-COOLDOWN-ACTIVE)
        
        (let (
            (endorser-stats (unwrap! (get-user-stats tx-sender) ERR-USER-NOT-FOUND))
            (endorsement-weight (calculate-endorsement-weight (get total-points endorser-stats)))
        )
            ;; Record endorsement
            (map-set UserEndorsements { endorser: tx-sender, endorsed: endorsed }
                {
                    endorsement-type: endorsement-type,
                    message: message,
                    timestamp: burn-block-height,
                    weight: endorsement-weight
                }
            )
            
            ;; Update endorsed user's trust score
            (update-trust-score endorsed endorsement-weight)
            
            (print { event: "user-endorsed", endorser: tx-sender, endorsed: endorsed, type: endorsement-type })
            (ok true)
        )
    )
)

;; Private: Calculate Endorsement Weight
(define-private (calculate-endorsement-weight (endorser-points uint))
    (if (> endorser-points u100000) u5      ;; High-value users have more weight
        (if (> endorser-points u10000) u3   ;; Medium-value users
            (if (> endorser-points u1000) u2 ;; Low-value users
                u1                          ;; New users
            )
        )
    )
)

;; Private: Update Trust Score
(define-private (update-trust-score (user principal) (weight uint))
    (let (
        (current-trust (default-to 
            {
                trust-score: u100,
                verification-level: TRUST-LEVEL-UNVERIFIED,
                endorsements: u0,
                reports: u0,
                last-updated: u0
            }
            (map-get? UserTrustScores user)
        ))
        (new-endorsements (+ (get endorsements current-trust) u1))
        (new-trust-score (+ (get trust-score current-trust) (* weight u10)))
        (new-verification-level (calculate-verification-level new-trust-score new-endorsements))
    )
        (map-set UserTrustScores user
            {
                trust-score: new-trust-score,
                verification-level: new-verification-level,
                endorsements: new-endorsements,
                reports: (get reports current-trust),
                last-updated: burn-block-height
            }
        )
        true
    )
)

;; Private: Calculate Verification Level
(define-private (calculate-verification-level (trust-score uint) (endorsements uint))
    (if (and (> trust-score u1000) (> endorsements u20)) TRUST-LEVEL-EXPERT
        (if (and (> trust-score u500) (> endorsements u10)) TRUST-LEVEL-TRUSTED
            (if (and (> trust-score u200) (> endorsements u5)) TRUST-LEVEL-VERIFIED
                (if (> trust-score u100) TRUST-LEVEL-BASIC
                    TRUST-LEVEL-UNVERIFIED
                )
            )
        )
    )
)

;; Public: Report User (for negative behavior)
(define-public (report-user (reported principal) (reason (string-ascii 50)))
    (begin
        (asserts! (not (is-eq tx-sender reported)) ERR-INVALID-POINTS)
        (asserts! (validate-string-input reason) ERR-INVALID-POINTS)
        
        (let (
            (current-trust (default-to 
                {
                    trust-score: u100,
                    verification-level: TRUST-LEVEL-UNVERIFIED,
                    endorsements: u0,
                    reports: u0,
                    last-updated: u0
                }
                (map-get? UserTrustScores reported)
            ))
            (new-reports (+ (get reports current-trust) u1))
            (penalty (if (> new-reports u5) u50 u10)) ;; Escalating penalties
            (new-trust-score (if (> (get trust-score current-trust) penalty) 
                                (- (get trust-score current-trust) penalty) 
                                u0))
        )
            (map-set UserTrustScores reported
                (merge current-trust {
                    trust-score: new-trust-score,
                    reports: new-reports,
                    last-updated: burn-block-height
                })
            )
            
            (print { event: "user-reported", reporter: tx-sender, reported: reported, reason: reason })
            (ok true)
        )
    )
)

;; Read-only: Get Trust Score
(define-read-only (get-trust-score (user principal))
    (map-get? UserTrustScores user)
)

;; Read-only: Get Endorsement
(define-read-only (get-endorsement (endorser principal) (endorsed principal))
    (map-get? UserEndorsements { endorser: endorser, endorsed: endorsed })
)