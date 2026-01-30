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
