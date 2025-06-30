;; VaultCore: Bitcoin-Collateralized Stablecoin System
;; Author: VaultCore Development Team
;; Version: 1.0.0

;; Constants
(define-constant PROTOCOL-ADMIN tx-sender)
(define-constant OVERCOLLATERAL-THRESHOLD u150) ;; 150% overcollateralization required
(define-constant DANGER-ZONE-THRESHOLD u120) ;; 120% liquidation boundary
(define-constant MIN-VAULT-SIZE u100000) ;; Minimum vault size in sats
(define-constant ANNUAL-BORROW-FEE u5) ;; 0.5% annual borrowing fee
(define-constant MAX-INTEGER u340282366920938463463374607431768211455) ;; Maximum uint value
(define-constant PRICE-CAP u1000000000) ;; Maximum price (10,000 USD per sat)
(define-constant YEARLY-BLOCKS u52560) ;; Approximate blocks per year

;; Global State Variables
(define-data-var stablecoin-circulation uint u0)
(define-data-var btc-price-feed uint u0)

;; User Vault Storage
(define-map user-vaults
    principal
    {
        btc-locked: uint,
        stablecoin-minted: uint,
        accumulated-fees: uint,
        last-fee-update: uint
    }
)

;; Error Constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-BACKING (err u101))
(define-constant ERR-LIQUIDATION-DANGER (err u102))
(define-constant ERR-VAULT-MISSING (err u103))
(define-constant ERR-WITHDRAWAL-TOO-LARGE (err u104))
(define-constant ERR-VAULT-TOO-SMALL (err u105))
(define-constant ERR-INVALID-INPUT (err u106))
(define-constant ERR-PRICE-OUT-OF-BOUNDS (err u107))
(define-constant ERR-PAYMENT-SHORTFALL (err u108))

;; Internal Calculations
(define-private (compute-borrowing-fees (debt uint) (block-count uint))
    (let (
        (fee-calculation (/ (* ANNUAL-BORROW-FEE debt block-count) (* YEARLY-BLOCKS u1000)))
    )
    fee-calculation)
)

(define-private (refresh-accumulated-fees (vault-info {btc-locked: uint, stablecoin-minted: uint, accumulated-fees: uint, last-fee-update: uint}))
    (let (
        (blocks-elapsed (- block-height (get last-fee-update vault-info)))
        (additional-fees (compute-borrowing-fees (get stablecoin-minted vault-info) blocks-elapsed))
    )
    (+ (get accumulated-fees vault-info) additional-fees))
)

;; Query Functions
(define-read-only (fetch-vault-info (vault-owner principal))
    (map-get? user-vaults vault-owner)
)

(define-read-only (calculate-backing-ratio (vault-owner principal))
    (let (
        (vault-data (unwrap! (fetch-vault-info vault-owner) ERR-VAULT-MISSING))
        (btc-value (* (get btc-locked vault-data) (var-get btc-price-feed)))
        (total-obligations (+ (get stablecoin-minted vault-data) (refresh-accumulated-fees vault-data)))
    )
    (if (is-eq total-obligations u0)
        (ok u0)
        (ok (/ (* btc-value u100) total-obligations))
    ))
)

(define-read-only (calculate-max-withdrawal (vault-owner principal))
    (let (
        (vault-data (unwrap! (fetch-vault-info vault-owner) ERR-VAULT-MISSING))
        (btc-amount (get btc-locked vault-data))
        (total-obligations (+ (get stablecoin-minted vault-data) (refresh-accumulated-fees vault-data)))
        (btc-value (* btc-amount (var-get btc-price-feed)))
        (required-btc-minimum (/ (* total-obligations OVERCOLLATERAL-THRESHOLD) (var-get btc-price-feed)))
    )
    (if (is-eq total-obligations u0)
        (ok btc-amount)
        (ok (- btc-amount required-btc-minimum))))
)

;; Core Protocol Functions
(define-public (initialize-vault (btc-deposit uint))
    (let (
        (vault-creator tx-sender)
        (existing-vault-check (fetch-vault-info vault-creator))
    )
    (asserts! (>= btc-deposit MIN-VAULT-SIZE) ERR-INSUFFICIENT-BACKING)
    (asserts! (is-none existing-vault-check) ERR-VAULT-MISSING)
    
    (map-set user-vaults
        vault-creator
        {
            btc-locked: btc-deposit,
            stablecoin-minted: u0,
            accumulated-fees: u0,
            last-fee-update: block-height
        }
    )
    (ok true))
)

(define-public (generate-stablecoin (mint-amount uint))
    (let (
        (vault-creator tx-sender)
        (vault-data (unwrap! (fetch-vault-info vault-creator) ERR-VAULT-MISSING))
        (updated-debt (+ (get stablecoin-minted vault-data) mint-amount))
        (refreshed-fees (refresh-accumulated-fees vault-data))
        (btc-value (* (get btc-locked vault-data) (var-get btc-price-feed)))
        (total-obligations (+ updated-debt refreshed-fees))
        (updated-backing-ratio (/ (* btc-value u100) total-obligations))
    )
    (asserts! (> mint-amount u0) ERR-INVALID-INPUT)
    (asserts! (<= (+ (var-get stablecoin-circulation) mint-amount) MAX-INTEGER) ERR-INVALID-INPUT)
    (asserts! (>= updated-backing-ratio OVERCOLLATERAL-THRESHOLD) ERR-INSUFFICIENT-BACKING)
    
    (map-set user-vaults
        vault-creator
        {
            btc-locked: (get btc-locked vault-data),
            stablecoin-minted: updated-debt,
            accumulated-fees: refreshed-fees,
            last-fee-update: block-height
        }
    )
    (var-set stablecoin-circulation (+ (var-get stablecoin-circulation) mint-amount))
    (ok true))
)

(define-public (settle-borrowing-fees (fee-payment uint))
    (let (
        (vault-owner tx-sender)
        (vault-data (unwrap! (fetch-vault-info vault-owner) ERR-VAULT-MISSING))
        (refreshed-fees (refresh-accumulated-fees vault-data))
    )
    (asserts! (>= refreshed-fees fee-payment) ERR-PAYMENT-SHORTFALL)
    
    (map-set user-vaults
        vault-owner
        {
            btc-locked: (get btc-locked vault-data),
            stablecoin-minted: (get stablecoin-minted vault-data),
            accumulated-fees: (- refreshed-fees fee-payment),
            last-fee-update: block-height
        }
    )
    (ok true))
)

(define-public (burn-stablecoin (burn-amount uint))
    (let (
        (vault-owner tx-sender)
        (vault-data (unwrap! (fetch-vault-info vault-owner) ERR-VAULT-MISSING))
        (current-debt (get stablecoin-minted vault-data))
        (refreshed-fees (refresh-accumulated-fees vault-data))
    )
    (asserts! (>= current-debt burn-amount) ERR-INSUFFICIENT-BACKING)
    
    (map-set user-vaults
        vault-owner
        {
            btc-locked: (get btc-locked vault-data),
            stablecoin-minted: (- current-debt burn-amount),
            accumulated-fees: refreshed-fees,
            last-fee-update: block-height
        }
    )
    (var-set stablecoin-circulation (- (var-get stablecoin-circulation) burn-amount))
    (ok true))
)

(define-public (extract-btc-collateral (withdrawal-amount uint))
    (let (
        (vault-owner tx-sender)
        (vault-data (unwrap! (fetch-vault-info vault-owner) ERR-VAULT-MISSING))
        (current-btc (get btc-locked vault-data))
        (current-debt (get stablecoin-minted vault-data))
        (max-withdrawal (unwrap! (calculate-max-withdrawal vault-owner) ERR-VAULT-MISSING))
    )
    (asserts! (<= withdrawal-amount max-withdrawal) ERR-WITHDRAWAL-TOO-LARGE)
    (asserts! (>= (- current-btc withdrawal-amount) MIN-VAULT-SIZE) ERR-VAULT-TOO-SMALL)
    
    (map-set user-vaults
        vault-owner
        {
            btc-locked: (- current-btc withdrawal-amount),
            stablecoin-minted: current-debt,
            accumulated-fees: (refresh-accumulated-fees vault-data),
            last-fee-update: block-height
        }
    )
    (ok true))
)

(define-public (liquidate-undercollateralized-vault (target-vault principal))
    (let (
        (vault-data (unwrap! (fetch-vault-info target-vault) ERR-VAULT-MISSING))
        (backing-ratio (unwrap! (calculate-backing-ratio target-vault) ERR-VAULT-MISSING))
    )
    (asserts! (< backing-ratio DANGER-ZONE-THRESHOLD) ERR-UNAUTHORIZED-ACCESS)
    
    (map-delete user-vaults target-vault)
    (var-set stablecoin-circulation (- (var-get stablecoin-circulation) (get stablecoin-minted vault-data)))
    (ok true))
)

;; Administrative Functions
(define-public (update-btc-price-oracle (new-btc-price uint))
    (begin
        (asserts! (is-eq tx-sender PROTOCOL-ADMIN) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (and (> new-btc-price u0) (<= new-btc-price PRICE-CAP)) ERR-PRICE-OUT-OF-BOUNDS)
        (var-set btc-price-feed new-btc-price)
        (ok true))
)