#property copyright "Copyright 2025, Algoxpert"
#property link      "https://mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//--- Strategy types
enum ENUM_STRATEGY_MODE
{
   STRATEGY_MODE_SINGLE = 0     // Single Strategy Mode
};

enum ENUM_LEAD_STRATEGY
{
   
   LEAD_ICHIMOKU = 0, // Ichimoku Cloud - Comprehensive trend analysis system
};

enum ENUM_SINGLE_STRATEGY
{
   SINGLE_ICHIMOKU = 0 // Ichimoku Cloud Strategy
};

//--- Signal types
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,    // No signal
   SIGNAL_BUY = 1,     // Buy signal
   SIGNAL_SELL = 2     // Sell signal
};

//--- Daily Drawdown Mode Types
enum ENUM_DD_MODE
{
   DD_MODE_DISABLED = 0,
   DD_MODE_TIERED = 2        // Tiered System - Reduce position size by tiers
};

//--- Daily Drawdown Tier Types
enum ENUM_DD_TIER
{
   DD_TIER_SAFE = 0,      // Safe Zone - Normal trading
   DD_TIER_WARNING = 1,   // Warning Zone - Reduced position size
   DD_TIER_DANGER = 2,    // Danger Zone - Heavily reduced position size
   DD_TIER_STOPPED = 3    // Critical Zone - Trading stopped
};

//--- Trading Session Types
enum ENUM_TRADING_SESSION
{
   SESSION_DISABLED = 0, 
   SESSION_FULL_DAY = 6               // Full Day - 00:00-23:59 GMT
};

//--- Trading Days Types
enum ENUM_TRADING_DAYS
{
   TRADING_DAYS_ALL_WEEK = 0,         // Full Week - Monday to Sunday
};

//--- Input parameters
// input group "=== Strategy Selection ==="
ENUM_STRATEGY_MODE strategy_mode = STRATEGY_MODE_SINGLE; // Trading Strategy Mode

// Single Strategy Selection (used when strategy_mode = SINGLE)
ENUM_SINGLE_STRATEGY single_strategy = SINGLE_ICHIMOKU; // Single Strategy Selection

// ========== STRATEGY EXPLANATION ==========
//
// 📊 STRATEGY MODE:
//    • STRATEGY_MODE_SINGLE: Use Ichimoku Cloud strategy independently
//
// 🎯 ICHIMOKU CLOUD STRATEGY:
//    • Comprehensive trend analysis system using multiple components:
//      - Tenkan-sen (Conversion Line): 9-period midpoint
//      - Kijun-sen (Base Line): 26-period midpoint
//      - Senkou Span A & B (Leading Spans): Form the cloud
//      - Chikou Span (Lagging Span): Price shifted back 26 periods
//    • BUY Signal: Price above cloud + Tenkan above Kijun
//    • SELL Signal: Price below cloud + Tenkan below Kijun
//
// _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

//+------------------------------------------------------------------+
//| OPTIMIZED INPUT PARAMETERS - 15 Critical Parameters Only         |
//| Reduced from 28 to 15 for focused stress testing                 |
//+------------------------------------------------------------------+

input group "=== 🔥 ICHIMOKU CORE STRATEGY ==="
// LOCKED: Tenkan Sen Period (CLIFF at value 9 - 80% Calmar collapse in stress test)
int ichimoku_tenkan_sen_period = 8;           // HARD LOCKED at 8 - Do NOT optimize!

input int ichimoku_kijun_sen_period = 39;     // Kijun-sen Period [PEAK: 38-42 only]
input int ichimoku_senkou_span_b_period = 68; // Senkou Span B Period [SAFE: 65-75]

//input group "=== 💰 RISK MANAGEMENT ==="
// (No adjustable parameters - risk is LOCKED for safety)

input group "=== 🛑 TOTAL MAX DRAWDOWN PROTECTION ==="
input bool   enable_total_max_dd = true;       // Enable Total Max DD Protection
input double total_max_dd_percent = 30.0;       // Max DD Threshold (%)
bool total_dd_close_losers = true;     // Close losing positions when DD > 9%

input group "=== 🛡️ DAILY DRAWDOWN PROTECTION ==="
input double dd_tier1_threshold = 0.01;        // [v3] EXACT KhongSua value
input double dd_tier1_risk_multiplier = 0.75;  // [v3] EXACT KhongSua value (75%)
input double dd_tier2_threshold = 0.1;         // [v3] EXACT KhongSua value
input double dd_tier2_risk_multiplier = 0.5;   // [v3] EXACT KhongSua value (50%)
input double dd_tier3_threshold = 1.5;        // [v3] EXACT KhongSua value - Daily loss limit!


input group "=== 💰 TRAILING PROFIT PROTECTION (v4 NEW!) ==="
// 🧠 INSIGHT: Ngày thắng không nên trở thành ngày thua!
// Khi có lãi, tighten circuit breaker để bảo vệ gains
input bool   enable_profit_protection = false;    // [v4 FAILED] Disable - Made performance worse!
input double profit_protect_trigger = 0.5;        // Activate when daily profit >= X%
input double profit_protect_keep_ratio = 0.6;     // Keep X% of peak profit (lock in gains)
input double profit_protect_min_buffer = 0.3;     // Minimum buffer before trigger (%)

//+------------------------------------------------------------------+
//| 🕐 TIME FILTER - Avoid Dangerous Trading Hours (v5 NEW!)         |
//+------------------------------------------------------------------+
//| 📊 DATA ANALYSIS (6 years, 54,000+ events):                      |
//|                                                                  |
//| DANGEROUS HOURS (DL ≥ 5% events distribution):                   |
//| • 00:00-05:59 (Early Asian): 32.9% of high-risk events          |
//| • 15:00-19:59 (NY Overlap):  22.1% of high-risk events          |
//| • 20:00-23:59 (Late NY):     Only 5.9% - SAFEST                 |
//|                                                                  |
//| EXTREME EVENTS (DL > 15%):                                       |
//| • 2020.01.22 20:25 → DL=17.99%                                  |
//| • 2021.08.03 19:55 → DL=18.29%                                  |
//| • 2024.06.27 18:30 → DL=20.79% (WORST!)                         |
//|                                                                  |
//| 💡 Filtering dangerous hours can reduce ~55% of extreme events! |
//+------------------------------------------------------------------+
input group "=== 🕐 TIME FILTER (v5 NEW!) ==="
input bool   enable_time_filter = true;           // Enable Dangerous Hours Filter
input int    danger_hour1_start = 3;              // Danger Zone 1 Start (03:00 UTC)
input int    danger_hour1_end = 6;                // Danger Zone 1 End (06:00 UTC)
input int    danger_hour2_start = 17;             // Danger Zone 2 Start (17:00 UTC)
input int    danger_hour2_end = 20;               // Danger Zone 2 End (20:00 UTC)

// Time Filter Behavior Options
enum ENUM_TIME_FILTER_MODE
{
   TIME_FILTER_BLOCK_ENTRY = 0,       // Block New Entries (safest)
   TIME_FILTER_REDUCE_SIZE = 1,       // Reduce Position Size
   TIME_FILTER_LIMIT_GRID = 2         // Limit Grid Depth Only
};
input ENUM_TIME_FILTER_MODE time_filter_mode = TIME_FILTER_BLOCK_ENTRY; // Filter Behavior

input double time_filter_size_mult = 0.5;         // Size Multiplier in Danger Zone (if REDUCE_SIZE)
input double time_filter_max_grid_load = 1.5;     // Max Grid Load in Danger Zone % (if LIMIT_GRID)
input bool   time_filter_close_on_danger = false; // Close all if entering danger zone with high DL

//+------------------------------------------------------------------+
//| 🚨 GRID EXPANSION CONTROL (v6 NEW!)                             |
//+------------------------------------------------------------------+
//| PROBLEM IDENTIFIED: TIME FILTER chỉ block NEW entries,          |
//|                     nhưng GRID EXPANSION vẫn xảy ra!             |
//|                                                                  |
//| ROOT CAUSE:                                                      |
//| • Grid positions đã có sẵn vẫn tiếp tục expand trong danger zone |
//| • Example: 2026.01.19 20:25 → DL spike từ 1.6% → 18.9%!         |
//|                                                                  |
//| SOLUTION: Block grid expansion when:                             |
//|   1. In dangerous time zone                                      |
//|   2. OR when DL > threshold                                       |
//|   3. OR when DL spikes suddenly (emergency)                      |
//+------------------------------------------------------------------+
input group "=== 🚨 GRID EXPANSION CONTROL (v6 NEW!) ==="
input bool   enable_grid_expansion_filter = true;  // Block Grid Expansion
input double grid_expansion_max_dl = 1.0;          // Max DL before blocking grid expansion (%)
input bool   grid_expansion_block_in_danger = true; // Block expansion in danger hours
input bool   grid_expansion_close_on_spike = false; // Emergency close if DL spikes suddenly
input double grid_expansion_spike_threshold = 5.0; // DL spike threshold (% increase)

input group "=== 🔍 ENTRY FILTERS ==="
input double min_candle_size_atr = 0.24;      // Min Candle Size [PEAK: 0.1-0.9]
input double max_candle_size_atr = 3.5;       // Max Candle Size [OPTIMAL: 3.5-7.5]
input double atr_sl_multiplier = 2.0;         // ATR Stop Loss Multiplier [CLAMP: 1.8-2.5]
input int atr_sl_tp_period = 14;             // ATR SL/TP Period [STABLE: 13-15]

input group "=== 📊 GRID TRADING SYSTEM ==="
input double grid_spacing_atr_multiplier = 1.0; // Grid Spacing [SAFE: 0.85-1.025]
input double grid_risk_multiplier = 2;      // Grid Risk Multiplier [1.35-1.65]
input int grid_atr_period = 14;               // Grid ATR Period [STABLE: 12-15]

input group "=== 🧱 GRID EXPOSURE CAP (Anti-Overfit) ==="
input bool   enable_grid_exposure_cap = true;          // Cap grid expansion by exposure
input double grid_exposure_max_dl_for_expansion = 1.8; // Block adding grid levels if Deposit Load >= X%
input int    grid_exposure_max_positions_total = 5;    // Block grid expansion if total open positions >= X
input int    grid_exposure_max_positions_side = 3;     // Block grid expansion if positions same direction >= X

input group "=== 📐 HTF TREND BIAS (H1 EMA100/EMA200) ==="
input bool   enable_htf_trend_bias = true;          // Enable HTF Trend Bias (reduce size)
input ENUM_TIMEFRAMES htf_timeframe = PERIOD_H1;    // HTF timeframe (recommended H1 for USDJPY M5)
input int    htf_ema_fast = 100;                    // Fast EMA period (H1)
input int    htf_ema_slow = 200;                    // Slow EMA period (H1)
input int    htf_atr_period = 14;                   // ATR period for neutral buffer (H1)
input double htf_neutral_buffer_atr = 0.25;         // Neutral if |EMA100-EMA200| < buffer*ATR(H1)
input double htf_countertrend_mult = 0.5;           // If trade against HTF trend
input double htf_neutral_mult = 0.7;                // If HTF neutral/flat

input group "=== 🌊 MARKET REGIME FILTER (ADX) ==="
input bool enable_market_regime_filter = true; // Enable Market Regime Filter
input int adx_period = 14;                     // ADX Period [STANDARD: 14]
input double adx_trending_threshold = 25.0;    // ADX Trending Threshold [RECOMMENDED: 25]
input double adx_weak_trend_threshold = 20.0;  // ADX Weak Trend Threshold [OPTIONAL: 20]
input bool block_weak_trends = false;          // Block Trades in Weak Trends

input group "=== 📊 RSI MOMENTUM FILTER (NEW - Stability Booster) ==="
input bool enable_rsi_filter = true;           // Enable RSI Momentum Filter
input int rsi_period = 14;                     // RSI Period [STANDARD: 14]
input double rsi_overbought = 70.0;            // RSI Overbought Level (Block BUY above this)
input double rsi_oversold = 30.0;              // RSI Oversold Level (Block SELL below this)
input bool rsi_use_divergence = false;         // Enable RSI Divergence Detection (Advanced)
input double rsi_neutral_zone_low = 40.0;      // RSI Neutral Zone Lower (Prefer trades in 40-60)
input double rsi_neutral_zone_high = 60.0;     // RSI Neutral Zone Upper (Prefer trades in 40-60)

input group "=== 🚀 ROC MOMENTUM FILTER (NEW) ==="
input bool   enable_roc_filter = true;           // Enable ROC (Rate of Change) filter
input int    roc_period = 12;                    // ROC period (bars)
input double roc_min_abs_atr = 0.15;             // Block if |ROC| < X * ATR (dead market)
input double roc_countertrend_mult = 0.6;        // Reduce size if ROC opposes trade direction

input group "=== 🧭 KDJ FILTER (Stochastic-based, NEW) ==="
input bool   enable_kdj_filter = true;           // Enable KDJ filter
input int    kdj_k_period = 9;                   // Stoch K period
input int    kdj_d_period = 3;                   // Stoch D period
input int    kdj_slowing = 3;                    // Slowing
input double kdj_overbought = 85.0;              // Block BUY if J >= this
input double kdj_oversold = 15.0;                // Block SELL if J <= this
input bool   kdj_reduce_in_extreme = false;       // If true: reduce instead of block in extremes
input double kdj_extreme_reduce_mult = 0.6;      // Reduce multiplier if reduce mode

input group "=== 📐 ADX SLOPE (Experiment 2) ==="
input bool enable_adx_slope_filter = true;           // Enable ADX Slope Filter
input int adx_slope_lookback = 5;                    // Lookback bars
input double adx_slope_rising_threshold = 0.3;       // Rising threshold
input double adx_slope_falling_threshold = -0.3;     // Falling threshold
input bool adx_slope_block_falling = true;           // Block when falling
input double adx_slope_falling_risk_mult = 0.5;      // Risk mult if not blocking

input group "=== 📊 ATR STABILITY (Experiment 3) ==="
input bool enable_atr_stability_filter = true;       // Enable ATR Stability Filter
input int atr_stability_period = 14;                 // ATR lookback period for stability calc
input double atr_ratio_upper = 1.3;                  // ATR ratio upper limit (block if above)
input double atr_ratio_lower = 0.7;                  // ATR ratio lower limit (block if below)
input double atr_volatility_threshold = 0.25;        // ATR volatility threshold (reduce if above)
input bool atr_stability_block_extreme = true;       // Block on extreme ATR ratio
input double atr_stability_reduce_mult = 0.5;        // Risk mult when volatile

input group "=== 📈 ROLLING PERFORMANCE GATE (Experiment 1) ==="

input group "=== 🧬 COMPRESSION/BREAKOUT (BB Squeeze - Exp 4) ==="
input bool   enable_bb_squeeze_filter = true;          // Enable Bollinger Band Squeeze Filter
input int    bb_period = 20;                           // Bollinger Bands Period [Std: 20]
input double bb_deviation = 2.0;                       // Bollinger Bands Deviation [Std: 2.0]
input double bb_squeeze_threshold_atr = 0.8;           // Squeeze if BB Width < X * ATR

enum ENUM_BB_SQUEEZE_MODE
{
   BB_SQUEEZE_BLOCK = 0,       // Block trades during squeeze
   BB_SQUEEZE_REDUCE = 1       // Reduce trade size during squeeze
};
input ENUM_BB_SQUEEZE_MODE bb_squeeze_mode = BB_SQUEEZE_REDUCE; // Squeeze Action
input double bb_squeeze_risk_mult = 0.5;               // Risk multiplier during squeeze (if REDUCE)
input bool   bb_squeeze_trade_breakout = false;        // Allow trades on first bar after squeeze ends

input bool enable_performance_gate = true;             // Enable Rolling Performance Gate
input int perf_lookback_trades = 20;                 // Lookback Period (number of trades)
input double perf_sharpe_full_trade = 1.0;           // Sharpe threshold for full trade (100%)
input double perf_sharpe_reduced = 0.0;              // Sharpe threshold for reduced trade (50%)
input double perf_sharpe_block = -0.5;               // Sharpe threshold to block trades (0%)
input double perf_reduced_risk_multiplier = 0.5;     // Risk multiplier when reduced (50%)
input int perf_min_trades_required = 5;              // Minimum trades before filter activates
input int perf_consecutive_loss_limit = 5;           // Max consecutive losses before block [REVERTED to original]
input int perf_consecutive_loss_cooldown = 5;       // Cooldown bars after consecutive loss block [REVERTED]

input group "=== 🧩 MACD CONFIRMATION FILTER (Option E) ==="
input bool   enable_macd_filter = true;             // Enable MACD confirmation filter (BLOCK)
input int    macd_fast = 12;                        // MACD fast EMA
input int    macd_slow = 26;                        // MACD slow EMA
input int    macd_signal = 9;                       // MACD signal SMA

input group "=== 🛡️ MICROSTRUCTURE GUARD (Spread/Slippage) ==="
input bool   enable_microstructure_guard = true;    // Enable spread/slippage guard
input double max_spread_points = 25;                // Max allowed spread in points (USDJPY M5 typical 10-25)
input double spread_reduce_mult = 0.5;              // Risk multiplier if spread is high (reduce mode)

enum ENUM_SPREAD_GUARD_MODE
{
   SPREAD_GUARD_BLOCK = 0,
   SPREAD_GUARD_REDUCE = 1
};
input ENUM_SPREAD_GUARD_MODE spread_guard_mode = SPREAD_GUARD_BLOCK; // Behavior when spread too high

input group "=== 🛡️ ENHANCED RISK MANAGEMENT (NEW) ==="
input bool enable_volatility_position_sizing = false; // Enable Volatility-Based Position Sizing [DISABLED - Too strict]
input double volatility_reduce_threshold = 2.0;     // ATR ratio threshold to reduce size (2.0x = high vol) [INCREASED]
input double volatility_reduce_multiplier = 0.7;    // Position size multiplier when volatility high (70%) [INCREASED]
input bool enable_equity_curve_protection = false;   // Enable Equity Curve Trailing Stop [DISABLED - Too strict]
input double equity_trailing_start = 5.0;            // Start trailing after X% profit from peak [INCREASED]
input double equity_trailing_step = 1.0;              // Trailing step (%) [INCREASED]
input double equity_trailing_stop = 3.0;              // Stop trading if equity drops X% from peak [INCREASED - Less strict]
input bool enable_correlation_risk_management = false; // Enable Correlation-Based Risk Management [DISABLED - Too strict]
input int max_same_direction_trades = 5;                // Max trades in same direction before reduce [INCREASED]
input double correlation_risk_multiplier = 0.8;        // Risk multiplier when too many same direction [INCREASED]

input group "=== 🤖 ADAPTIVE FILTER SYSTEM ==="
input bool   enable_adaptive_filters = true;         // Enable Adaptive Filter Switching
input int    adaptive_lookback_bars = 50;            // Bars to analyze for regime detection
input double adx_reliability_high = 0.7;             // ADX reliable if score >= this
input double adx_reliability_low = 0.5;              // ADX unreliable if score < this
input double adaptive_atr_vol_threshold = 0.20;      // ATR volatility threshold for regime

//+------------------------------------------------------------------+
//| Enum Definitions (MUST be defined before use)                    |
//+------------------------------------------------------------------+

// Grid Mode Enum
enum ENUM_GRID_MODE
{
   GRID_ANTI_TREND = 1    // Anti-Trend Grid (against trend direction)
};

// Grid Size Mode Enum
enum ENUM_GRID_SIZE_MODE
{
   GRID_SIZE_MULTIPLY_FIRST = 0,    // Multiply from first order risk
   GRID_SIZE_MULTIPLY_PREVIOUS = 1  // Multiply from previous order risk
};

//+------------------------------------------------------------------+
//| HARDCODED PARAMETERS - Core Strategy Settings (Locked)           |
//| These define the core strategy and are NOT exposed as inputs     |
//+------------------------------------------------------------------+

// WIN RATE BOOSTER - Entry Quality Filters
bool use_price_action_filter = true;         // Always enabled - core filter

// Trading Session Control
ENUM_TRADING_SESSION trading_session = SESSION_FULL_DAY; // Full day trading
int candles_before_session_end = 5;          // Standard value
bool close_positions_on_session_end = true;  // Risk management
ENUM_TRADING_DAYS trading_days = TRADING_DAYS_ALL_WEEK; // All weekdays

// Risk Management - Fixed Values
double slippage = 0.001;                      // Standard slippage
ENUM_DD_MODE daily_drawdown_mode = DD_MODE_TIERED; // Always use tiered mode

// Grid Trading - Core Logic (Locked)
// ⚠️ STRESS TEST FINDING: max_grid_orders NO-EFFECT (1 year test)
// • User tested values 1-50 with step=1 on 1 year data
// • Results: 1≠2, but 3=4=5=...=50 (all identical)
// • Observed max depth: 2 (never exceeded in real backtest)
// • Decision: HARDCODE = 3 (observed_max + 1 buffer)
// • Rationale: No optimization value, 1 alpha = 1 pair+TF (no cross-market)
bool grid_trading_enabled = true;            // Core strategy component
ENUM_GRID_MODE grid_mode = GRID_ANTI_TREND;  // Anti-trend strategy locked
int max_grid_orders = 3;                     // HARDCODED - Safety limit (observed max = 2)

bool use_atr_for_grid_spacing = true;        // Always use ATR
double grid_spacing_percentage = 0.005;      // Not used (ATR mode)
ENUM_TIMEFRAMES grid_atr_timeframe = PERIOD_CURRENT; // Current timeframe
ENUM_GRID_SIZE_MODE grid_size_mode = GRID_SIZE_MULTIPLY_FIRST; // Locked sizing mode

// Risk Management - LOCKED for Safety
// ⚠️ STRESS TEST FINDING: risk_per_trade CLIFF at ≥0.003 (0.3%)
// • Optimal: 0.0005 (0.05%) with Sharpe 3.15, MaxDD 3.54%, Profit $8362
// • CLIFF: ≥0.003 causes MaxDD >20%, ≥0.004 causes CATASTROPHIC LOSS
// • Decision: LOCK at 0.05% (industry standard, proven optimal)
// • Rationale: Risk management should be FIXED, not optimized
double risk_per_trade = 0.0005;              // LOCKED at 0.05% - Do NOT modify!

// Stop Loss & Take Profit - Fixed Method
bool use_atr_for_sl_tp = true;               // Always use ATR-based SL/TP
double sl_pct = 0.02;                        // Backup only, not used
double tp_pct = 0.03;                        // Backup only, not used

// Trailing Stop - Fixed Settings
// ⚠️ STRESS TEST FINDING: reward_risk_ratio NO-EFFECT
// • Instrumentation shows ≥95% trades have TP=0 (trailing mode active)
// • Only used in <5% of trades when trailing disabled
// • Decision: HARDCODE = 2.0 (industry standard R:R)
double reward_risk_ratio = 2.0;              // HARDCODED - Not used with trailing

//+------------------------------------------------------------------+
//| 🎯 PROFIT HARVESTING SYSTEM - Capture equity peaks              |
//| ⚠️ ALPHA WARNING: Original settings CUT WINNERS TOO EARLY!      |
//|                                                                  |
//| ROOT CAUSE ANALYSIS:                                             |
//| • Grid + Anti-Trend accumulates positions during adverse moves   |
//| • When trend reverses, ALL grid positions profit SIMULTANEOUSLY  |
//| • Partial TP at 1x ATR cuts 50% of this recovery profit!         |
//| • Tight trail (0.4x ATR) gets stopped on minor pullbacks         |
//| • Result: 50% upside lost but 100% downside still taken          |
//|                                                                  |
//| FIX: Either DISABLE or use MUCH HIGHER thresholds                |
//+------------------------------------------------------------------+
input group "=== 🎯 PROFIT HARVESTING SYSTEM ==="
input bool   enable_profit_harvesting = false;   // [v2] DISABLED - Was cutting winners too early
input double partial_tp_atr_mult = 2.5;          // [v2] Partial TP at 2.5x ATR (was 1.0)
input double partial_tp_percent = 30.0;          // [v2] Close only 30% (was 50%)
input double tighten_trail_atr_mult = 0.8;       // [v2] After partial: 0.8x ATR (was 0.4)
input double profit_retrace_atr_mult = 1.2;      // [v2] Exit only if drop 1.2x ATR from MFE (was 0.5)
input int    trail_buffer_points = 5;            // Trailing buffer (points above StopLevel)

// Trailing Stop Settings - REVERTED TO WIDER SETTINGS
// 🧠 ALPHA INSIGHT: Ichimoku is a TREND-FOLLOWING strategy
// It needs room to "breathe" during pullbacks within trend
// Tight trailing (0.3x/0.5x ATR) gets stopped on noise
bool atr_trailing_stop_enabled = true;           // Always enabled
bool use_tp_with_trailing = false;               // Standard: No TP with trailing
double atr_trailing_start_multiplier = 1.0;      // [v2] REVERTED to 1.0x ATR (was 0.3)
double atr_trailing_multiplier = 1.0;            // [v2] REVERTED to 1.0x ATR (was 0.5)

// ATR Settings - Industry Standard
int atr_trailing_period = 14;
ENUM_TIMEFRAMES atr_timeframe = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
int atr_sl_tp_handle;
int atr_trailing_handle;
int grid_atr_handle; // ATR handle for grid spacing

// HTF Trend Bias handles
int htf_ema_fast_handle = INVALID_HANDLE;
int htf_ema_slow_handle = INVALID_HANDLE;
int htf_atr_handle = INVALID_HANDLE;

// HTF Bias state
enum ENUM_HTF_BIAS { HTF_BIAS_UP=0, HTF_BIAS_DOWN=1, HTF_BIAS_NEUTRAL=2, HTF_BIAS_UNKNOWN=3 };
ENUM_HTF_BIAS current_htf_bias = HTF_BIAS_UNKNOWN;

// HTF Bias instrumentation
int htf_trades_aligned = 0;
int htf_trades_neutral = 0;
int htf_trades_counter = 0;

// Market Regime Filter handles
int mr_adx_handle = INVALID_HANDLE; // ADX handle for trend detection (Option 1 - ACTIVE)

// RSI Momentum Filter handle
int rsi_handle = INVALID_HANDLE; // RSI handle for momentum confirmation

// ROC / KDJ handles (NEW)
int roc_handle = INVALID_HANDLE; // ROC handle (Rate of Change)
int kdj_handle = INVALID_HANDLE; // Stochastic handle (used to compute KDJ)

// MACD Filter handle (Option E)
int macd_handle = INVALID_HANDLE;

// BB Squeeze Filter handle (Experiment 4)
int bb_squeeze_handle = INVALID_HANDLE; // BB handle for squeeze detection

// 🔥 NEW: Smart Daily Loss Limit System V2 - Structure to track per pair-TF-strategy
struct DailyLossTracker
{
   string symbol;
   int timeframe;
   int strategy_id;
   datetime last_reset_date;

   // Daily loss tracking
   int total_losses_today;
   double daily_loss_amount;
   double max_daily_loss_dollars;

   // Consecutive tracking with timeout
   int consecutive_buy_losses;
   int consecutive_sell_losses;
   datetime last_buy_loss_time;
   datetime last_sell_loss_time;
};

// Global array to track all contexts (per pair-TF-strategy)
DailyLossTracker loss_trackers[];

struct PositionData
{
   ulong ticket;
   double entry_price;
   double stop_loss;
   double take_profit;
   double atr_value;
   datetime open_time;
   bool trailing_active;
   // 🎯 Profit Harvesting fields
   double max_floating_profit;   // MFE tracking (Maximum Favorable Excursion)
   bool partial_closed;          // True if partial TP was taken
   double original_lot_size;     // Original lot before partial close
   bool use_tight_trail;         // Use tighter trailing after partial
};

// Grid Trading structures
struct GridData
{
   ulong ticket;
   ENUM_ORDER_TYPE order_type;  // BUY or SELL
   double entry_price;
   double stop_loss;
   double take_profit;
   double atr_value;
   datetime open_time;
   bool trailing_active;
   int grid_level;              // Grid level (0 = first order, 1 = second, etc.)
   double used_risk;            // Risk amount used for this grid order
   bool is_grid_order;          // Flag to identify grid orders
   // 🎯 Profit Harvesting fields
   double max_floating_profit;   // MFE tracking (Maximum Favorable Excursion)
   bool partial_closed;          // True if partial TP was taken
   double original_lot_size;     // Original lot before partial close
   bool use_tight_trail;         // Use tighter trailing after partial
};

PositionData managed_positions[];
GridData grid_positions[];

// Grid Trading state variables
bool grid_active = false;
ENUM_ORDER_TYPE current_grid_direction = ORDER_TYPE_BUY;

// Time Filter state variables (v5)
bool is_in_dangerous_time = false;          // Current dangerous time state
int time_filter_blocked_count = 0;          // Signals blocked by time filter
int time_filter_reduced_count = 0;          // Signals with reduced size due to time filter
double current_time_filter_multiplier = 1.0; // Current size multiplier from time filter

// Grid Expansion Control state variables (v6)
int grid_expansion_blocked_count = 0;       // Grid expansions blocked
int grid_expansion_spike_detected = 0;      // DL spikes detected
int grid_exposure_cap_blocked_count = 0;    // Grid expansions blocked by exposure cap

double last_deposit_load = 0.0;             // Last DL for spike detection
datetime last_dl_check_time = 0;            // Last DL check time

//+------------------------------------------------------------------+
//| INSTRUMENTATION: Parameter Sensitivity Activation Metrics        |
//| These counters prove NO-EFFECT claims with actual data           |
//+------------------------------------------------------------------+

// Counter: Take Profit usage (to verify reward_risk_ratio NO-EFFECT)
int total_trades_opened = 0;          // Total trades executed
int trades_with_tp = 0;                // Trades with TP > 0
int trades_without_tp = 0;             // Trades with TP = 0 (trailing mode)

// Counter: Trailing Stop activation (to verify atr_trailing_* NO-EFFECT)
int trailing_activated_count = 0;     // Times trailing became active
int trailing_modified_count = 0;      // Times trailing SL was modified

// Counter: Grid depth (to verify max_grid_orders NO-EFFECT)
int max_grid_depth_reached = 0;       // Maximum grid level ever reached
int grid_depth_histogram[20];         // Distribution of grid depths (0-19)

// Counter: Daily Drawdown tiers (to verify dd_tier2 activation)
int dd_tier1_triggered_count = 0;     // Times DD Tier 1 was triggered
int dd_tier2_triggered_count = 0;     // Times DD Tier 2 was triggered
int dd_tier3_triggered_count = 0;     // Times DD Tier 3 was triggered

// Tracking: Previous DD tier (to detect transitions)
ENUM_DD_TIER previous_dd_tier = DD_TIER_SAFE;

// Counter: Market Regime Filter effectiveness
int total_signals_checked = 0;        // Total signals from Ichimoku

// RSI Filter instrumentation
int rsi_signals_passed = 0;           // RSI filter passed
int rsi_signals_blocked_overbought = 0; // RSI blocked BUY (overbought)
int rsi_signals_blocked_oversold = 0;   // RSI blocked SELL (oversold)
int rsi_signals_blocked_momentum = 0;   // RSI blocked (wrong momentum direction)

// MACD Filter instrumentation (Option E)
int macd_signals_passed = 0;
int macd_signals_blocked = 0;

int signals_passed_regime = 0;        // Signals that passed regime filter
int signals_blocked_ranging = 0;      // Signals blocked due to ranging market
int signals_blocked_weak_trend = 0;   // Signals blocked due to weak trend

//+------------------------------------------------------------------+
//| ROLLING PERFORMANCE GATE - Data Structures & Variables           |
//| Experiment 1: Track recent trade performance to adapt risk       |
//+------------------------------------------------------------------+

// Performance Tier Enum
enum ENUM_PERF_TIER
{
   PERF_TIER_FULL = 0,      // Full trading - Rolling Sharpe >= threshold
   PERF_TIER_REDUCED = 1,   // Reduced trading - Rolling Sharpe between thresholds
   PERF_TIER_BLOCKED = 2    // Blocked - Rolling Sharpe below threshold or consecutive losses
};

// Circular buffer for recent trade results
double perf_trade_returns[];          // Array to store recent trade returns (as % of equity)
int perf_buffer_index = 0;            // Current index in circular buffer
int perf_total_trades_tracked = 0;    // Total trades tracked (for knowing when buffer is full)
int perf_consecutive_losses = 0;      // Current consecutive loss count
ENUM_PERF_TIER current_perf_tier = PERF_TIER_FULL; // Current performance tier

// Rolling metrics (calculated on each trade close)
double rolling_sharpe = 0.0;          // Current rolling Sharpe ratio
double rolling_mean_return = 0.0;     // Mean return of last N trades
double rolling_std_return = 0.0;      // Std dev of returns
double rolling_win_rate = 0.0;        // Win rate of last N trades
int rolling_wins = 0;                 // Wins in buffer
int rolling_losses = 0;               // Losses in buffer

// Instrumentation counters for Performance Gate
int perf_signals_full_trade = 0;      // Signals that traded at full size
int perf_signals_reduced = 0;         // Signals that traded at reduced size
int perf_signals_blocked = 0;         // Signals blocked by performance gate
int perf_tier_transitions = 0;        // Number of tier changes
double perf_min_sharpe_observed = 999.0;  // Minimum rolling Sharpe observed
double perf_max_sharpe_observed = -999.0; // Maximum rolling Sharpe observed

// ADX SLOPE (Experiment 2)
enum ENUM_ADX_SLOPE_STATE { ADX_SLOPE_RISING=0, ADX_SLOPE_FLAT=1, ADX_SLOPE_FALLING=2 };
double current_adx_slope = 0.0;
ENUM_ADX_SLOPE_STATE current_adx_slope_state = ADX_SLOPE_FLAT;
int adx_slope_signals_rising = 0;
int adx_slope_signals_flat = 0;
int adx_slope_signals_falling = 0;
int adx_slope_blocked_count = 0;
double adx_slope_min_observed = 999.0;
double adx_slope_max_observed = -999.0;

// ATR STABILITY (Experiment 3)
enum ENUM_ATR_STABILITY_STATE { ATR_STABLE=0, ATR_VOLATILE=1, ATR_EXTREME=2 };
double current_atr_ratio = 1.0;
double current_atr_volatility = 0.0;
ENUM_ATR_STABILITY_STATE current_atr_state = ATR_STABLE;
int atr_stability_signals_stable = 0;
int atr_stability_signals_volatile = 0;
int atr_stability_signals_extreme = 0;
int atr_stability_blocked_count = 0;
double atr_ratio_min_observed = 999.0;
double atr_ratio_max_observed = -999.0;

// BB SQUEEZE (Experiment 4)
enum ENUM_BB_SQUEEZE_STATE { BB_SQUEEZE_NONE=0, BB_SQUEEZE_ACTIVE=1, BB_SQUEEZE_BREAKOUT=2 };
double current_bb_width_atr = 0.0; // Current BB Width normalized by ATR
ENUM_BB_SQUEEZE_STATE current_bb_squeeze_state = BB_SQUEEZE_NONE;
bool was_in_squeeze = false; // State for breakout detection
int bb_squeeze_signals_allowed = 0;
int bb_squeeze_signals_reduced = 0;
int bb_squeeze_signals_blocked = 0;
int bb_squeeze_breakouts_detected = 0;
double bb_width_min_observed = 999.0;
double bb_width_max_observed = -999.0;

// ADAPTIVE FILTER SYSTEM
enum ENUM_FILTER_REGIME {
   REGIME_FULL,           // MR + Exp 1+2+3
   REGIME_NO_EXP2,        // MR + Exp 1+3 (volatile but trending)
   REGIME_EXP1_ONLY,      // Exp 1 only (ADX unreliable, stable vol)
   REGIME_EXP3_ONLY,      // Exp 3 only (ADX unreliable, volatile - like OOS mini3)
   REGIME_EXP1_EXP3,      // Exp 1+3 (safe default)
   REGIME_NONE            // All filters off
};
ENUM_FILTER_REGIME current_filter_regime = REGIME_FULL;
double adx_reliability_score = 1.0;
// Instrumentation counters
int regime_full_count = 0;
int regime_no_exp2_count = 0;
int regime_exp1_only_count = 0;
int regime_exp3_only_count = 0;
int regime_exp1_exp3_count = 0;
int regime_none_count = 0;
int regime_change_count = 0;
double adx_reliability_min = 999.0;
double adx_reliability_max = -999.0;
double adx_reliability_sum = 0.0;
int adx_reliability_samples = 0;

//+------------------------------------------------------------------+
//| VALIDATED PARAMETERS - Internal copies for runtime use           |
//| Input parameters cannot be modified, so we copy and validate     |
//+------------------------------------------------------------------+
int validated_kijun_period;              // Clamped copy of ichimoku_kijun_sen_period
double validated_grid_spacing;           // Capped copy of grid_spacing_atr_multiplier
double validated_min_candle_size;        // Clamped copy of min_candle_size_atr
double validated_atr_sl_multiplier;      // Clamped copy of atr_sl_multiplier

double first_grid_price = 0;
double last_grid_price = 0;
int current_grid_count = 0;
double base_risk_amount = 0;    // Base risk amount from first order


// Total Max Drawdown Protection variables
double total_dd_peak_equity = 0.0;     // Highest equity since EA started
bool total_dd_exceeded = false;        // Flag when total DD threshold hit

// Daily Drawdown Tiered Management variables
double daily_start_balance = 0;      // Balance at start of day
double daily_start_equity = 0;       // Equity at start of day
datetime last_daily_check_date = 0;  // Last date checked for daily reset
ENUM_DD_TIER current_dd_tier = DD_TIER_SAFE; // Current drawdown tier
double current_dd_percent = 0.0;     // Current drawdown percentage
bool daily_drawdown_exceeded = false; // Flag to stop trading when tier 3 exceeded (deprecated, use current_dd_tier)

// [v4] TRAILING PROFIT PROTECTION variables
double daily_peak_profit_percent = 0.0;  // Highest profit reached today (%)
double dynamic_dd_tier3 = 0.0;           // Dynamic circuit breaker threshold
bool profit_protection_active = false;   // Is profit protection currently active?
int profit_protection_triggers = 0;      // Count of times profit protection triggered

// Trading Session Management variables
datetime last_session_check_time = 0; // Last time session was checked
bool session_positions_closed = false; // Flag to track if positions were closed at session end

// Swap Avoidance System
ENUM_TIMEFRAMES current_timeframe;     // Current chart timeframe
int swap_safe_close_minutes;           // Buffer minutes before 22:00 GMT rollover
bool swap_avoidance_active = false;    // Flag to block new positions near rollover

// Bar tracking to keep behaviour identical across modelling modes
datetime last_processed_bar_time = 0;

// Enhanced Risk Management variables
double equity_peak_value = 0.0;        // Peak equity value for trailing stop
double equity_peak_percent = 0.0;      // Peak equity as % of initial
bool equity_trailing_active = false;   // Is equity trailing stop active?
int same_direction_trade_count = 0;    // Count of trades in same direction
ENUM_ORDER_TYPE last_trade_direction = WRONG_VALUE; // Last trade direction
int perf_consecutive_loss_cooldown_bars = 0; // Cooldown counter after block
datetime perf_last_loss_time = 0;     // Time of last loss (for time-based recovery)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //+------------------------------------------------------------------+
   //| PARAMETER VALIDATION - Stress Test Safety Constraints            |
   //| Based on report_StressTest.xlsx (113 days backtest)              |
   //+------------------------------------------------------------------+

   Print("=== STRESS TEST SAFETY VALIDATION ===");

   // CLIFF PROTECTION: Kijun Sen Period [38-42 PEAK PERFORMANCE ZONE]
   // Create validated copy (input parameters are read-only constants)
   // Analysis: kijun=38-42 shows CONSISTENT PEAK (Sharpe 2.34-5.23, Calmar 6.46-9.20, MaxDD ≤3.69%)
   validated_kijun_period = ichimoku_kijun_sen_period;

   if(validated_kijun_period < 38 || validated_kijun_period > 42)
   {
      Print("🔴 CLIFF ALERT: kijun_sen_period=", validated_kijun_period, " outside peak range [38-42]");
      Print("   Stress test showed OPTIMAL ZONE: Sharpe 2.34-5.23, Calmar 6.46-9.20");
      Print("   Auto-clamping to peak boundary...");

      if(validated_kijun_period < 38)
         validated_kijun_period = 38;
      else if(validated_kijun_period > 42)
         validated_kijun_period = 42;

      Print("   ✅ Clamped to: ", validated_kijun_period);
   }
   else
   {
      Print("✅ kijun_sen_period=", validated_kijun_period, " within peak range [38-42]");
   }

   // SENSITIVE PROTECTION: Grid Spacing [0.85-1.025 SAFE RANGE]
   // Create validated copy (input parameters are read-only constants)
   validated_grid_spacing = grid_spacing_atr_multiplier;

   if(validated_grid_spacing < 0.85 || validated_grid_spacing > 1.025)
   {
      Print("⚠️ SENSITIVE ALERT: grid_spacing=", validated_grid_spacing, " outside safe range [0.85-1.025]");
      Print("   Stress test showed degradation: Calmar drops 56% at 1.05");
      Print("   Best performance at 0.95 (Calmar 11.87 vs baseline 8.37)");
      Print("   Auto-capping to safe boundary...");

      if(validated_grid_spacing < 0.85)
         validated_grid_spacing = 0.85;
      else if(validated_grid_spacing > 1.025)
         validated_grid_spacing = 1.025;

      Print("   ✅ Capped to: ", validated_grid_spacing);
   }
   else
   {
      Print("✅ grid_spacing=", validated_grid_spacing, " within safe range [0.85-1.025]");
   }

   // CLIFF PROTECTION: Min Candle Size [0.1-0.9 PEAK PERFORMANCE ZONE]
   // Create validated copy (input parameters are read-only constants)
   // Analysis: min_candle ≥1.3 causes CALMAR COLLAPSE (negative), ≥3.7 NO TRADES
   validated_min_candle_size = min_candle_size_atr;

   if(validated_min_candle_size < 0.1 || validated_min_candle_size > 0.9)
   {
      Print("🔴 CLIFF ALERT: min_candle_size_atr=", validated_min_candle_size, " outside peak range [0.1-0.9]");
      Print("   Stress test showed CLIFF: Calmar NEGATIVE at ≥1.3, NO TRADES at ≥3.7");
      Print("   Peak performance: [0.1-0.9] with Sharpe 3.33-4.31, Calmar 3.83-9.25");
      Print("   Auto-clamping to peak boundary...");

      if(validated_min_candle_size < 0.1)
         validated_min_candle_size = 0.1;
      else if(validated_min_candle_size > 0.9)
         validated_min_candle_size = 0.9;

      Print("   ✅ Clamped to: ", validated_min_candle_size);
   }
   else
   {
      Print("✅ min_candle_size_atr=", validated_min_candle_size, " within peak range [0.1-0.9]");
   }

   // CLIFF PROTECTION: ATR SL Multiplier [1.8-2.5 SAFE ZONE]
   // Create validated copy (input parameters are read-only constants)
   // Analysis: <1.5 causes LOSS (Sharpe -5.00 to 0.83), ≥3.2 causes negative Sharpe
   // Peak: [2.0-2.2] with Sharpe 3.15-3.82, Calmar 8.27-10.27, MaxDD 3.54-4.34%
   validated_atr_sl_multiplier = atr_sl_multiplier;

   if(validated_atr_sl_multiplier < 1.8 || validated_atr_sl_multiplier > 2.5)
   {
      Print("🔴 CLIFF ALERT: atr_sl_multiplier=", validated_atr_sl_multiplier, " outside safe range [1.8-2.5]");
      Print("   Stress test showed CLIFF: <1.5 causes LOSS, ≥3.2 negative Sharpe");
      Print("   Peak performance: [2.0-2.2] with Sharpe 3.15-3.82, Calmar 8.27-10.27");
      Print("   Auto-clamping to safe boundary...");

      if(validated_atr_sl_multiplier < 1.8)
         validated_atr_sl_multiplier = 1.8;
      else if(validated_atr_sl_multiplier > 2.5)
         validated_atr_sl_multiplier = 2.5;

      Print("   ✅ Clamped to: ", validated_atr_sl_multiplier);
   }
   else
   {
      Print("✅ atr_sl_multiplier=", validated_atr_sl_multiplier, " within safe range [1.8-2.5]");
   }

   Print("=== VALIDATION COMPLETE ===");
   Print("");

   // Initialize ATRs
   atr_sl_tp_handle = iATR(_Symbol, atr_timeframe, atr_sl_tp_period);
   atr_trailing_handle = iATR(_Symbol, atr_timeframe, atr_trailing_period);
   if(atr_sl_tp_handle == INVALID_HANDLE || atr_trailing_handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicators");
      return INIT_FAILED;
   }
   
   // Initialize Grid ATR if grid trading is enabled
   if(grid_trading_enabled && use_atr_for_grid_spacing)
   {
      grid_atr_handle = iATR(_Symbol, grid_atr_timeframe, grid_atr_period);
      if(grid_atr_handle == INVALID_HANDLE)
      {
         Print("Error creating Grid ATR indicator");
         return INIT_FAILED;
      }
      Print("Grid ATR initialized - Period:", grid_atr_period, " Multiplier:", grid_spacing_atr_multiplier);
   }
   
   // Initialize HTF Trend Bias
   if(enable_htf_trend_bias)
   {
      htf_ema_fast_handle = iMA(_Symbol, htf_timeframe, htf_ema_fast, 0, MODE_EMA, PRICE_CLOSE);
      htf_ema_slow_handle = iMA(_Symbol, htf_timeframe, htf_ema_slow, 0, MODE_EMA, PRICE_CLOSE);
      htf_atr_handle = iATR(_Symbol, htf_timeframe, htf_atr_period);

      if(htf_ema_fast_handle == INVALID_HANDLE || htf_ema_slow_handle == INVALID_HANDLE || htf_atr_handle == INVALID_HANDLE)
      {
         Print("Error creating HTF Trend Bias indicators");
         return INIT_FAILED;
      }

      current_htf_bias = HTF_BIAS_UNKNOWN;
      htf_trades_aligned = 0;
      htf_trades_neutral = 0;
      htf_trades_counter = 0;

      Print("=== HTF TREND BIAS INITIALIZED ===");
      Print("Timeframe: ", EnumToString(htf_timeframe),
            " | EMA Fast: ", htf_ema_fast,
            " | EMA Slow: ", htf_ema_slow,
            " | ATR: ", htf_atr_period);
      Print("Neutral Buffer: ATR x", DoubleToString(htf_neutral_buffer_atr, 2),
            " | Countertrend Mult: ", DoubleToString(htf_countertrend_mult, 2),
            " | Neutral Mult: ", DoubleToString(htf_neutral_mult, 2));
   }
   
   // Initialize Market Regime Filter (ADX)
   if(enable_market_regime_filter)
   {
      mr_adx_handle = iADX(_Symbol, PERIOD_CURRENT, adx_period);
      if(mr_adx_handle == INVALID_HANDLE)
      {
         Print("Error creating ADX indicator for Market Regime Filter");
         return INIT_FAILED;
      }
      Print("=== MARKET REGIME FILTER INITIALIZED ===");
      Print("Method: ADX (Average Directional Index)");
      Print("ADX Period: ", adx_period);
      Print("Trending Threshold: ", adx_trending_threshold, " (ADX >= ", adx_trending_threshold, " = Strong Trend)");
      Print("Weak Trend Threshold: ", adx_weak_trend_threshold, " (ADX ", adx_weak_trend_threshold, "-", adx_trending_threshold, " = Weak Trend)");
      Print("Block Weak Trends: ", (block_weak_trends ? "YES" : "NO"));
      Print("Ranging Threshold: ADX < ", adx_weak_trend_threshold, " = Ranging Market (BLOCKED)");
   }
   else
   {
      Print("Market Regime Filter: DISABLED (Trading in all market conditions)");
   }

   // Initialize RSI Momentum Filter
   if(enable_rsi_filter)
   {
      rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
      if(rsi_handle == INVALID_HANDLE)
      {
         Print("Error creating RSI indicator for Momentum Filter");
         return INIT_FAILED;
      }
      Print("=== RSI MOMENTUM FILTER INITIALIZED ===");
      Print("RSI Period: ", rsi_period);
      Print("Overbought Level: ", rsi_overbought, " (Block BUY when RSI > ", rsi_overbought, ")");
      Print("Oversold Level: ", rsi_oversold, " (Block SELL when RSI < ", rsi_oversold, ")");
      Print("Neutral Zone: ", rsi_neutral_zone_low, "-", rsi_neutral_zone_high, " (Preferred trading zone)");
      Print("Divergence Detection: ", (rsi_use_divergence ? "ENABLED" : "DISABLED"));
   }
   else
   {
      Print("RSI Momentum Filter: DISABLED");
   }

   // Initialize ROC Filter
   if(enable_roc_filter)
   {
      roc_handle = iMomentum(_Symbol, PERIOD_CURRENT, roc_period, PRICE_CLOSE);
      if(roc_handle == INVALID_HANDLE)
      {
         Print("Error creating ROC indicator");
         return INIT_FAILED;
      }
      Print("=== ROC FILTER INITIALIZED ===");
      Print("ROC Period: ", roc_period, " | MinAbs(ATR): ", DoubleToString(roc_min_abs_atr, 2), " | CounterMult: ", DoubleToString(roc_countertrend_mult, 2));
   }
   else
   {
      Print("ROC Filter: DISABLED");
   }

   // Initialize KDJ Filter (via Stochastic)
   if(enable_kdj_filter)
   {
      kdj_handle = iStochastic(_Symbol, PERIOD_CURRENT, kdj_k_period, kdj_d_period, kdj_slowing, MODE_SMA, STO_LOWHIGH);
      if(kdj_handle == INVALID_HANDLE)
      {
         Print("Error creating Stochastic indicator for KDJ Filter");
         return INIT_FAILED;
      }
      Print("=== KDJ FILTER INITIALIZED ===");
      Print("KDJ (Stoch) K/D/Slow: ", kdj_k_period, "/", kdj_d_period, "/", kdj_slowing,
            " | J OB/OS: ", DoubleToString(kdj_overbought, 1), "/", DoubleToString(kdj_oversold, 1),
            " | ReduceInExtreme: ", (kdj_reduce_in_extreme ? "YES" : "NO"),
            " | ReduceMult: ", DoubleToString(kdj_extreme_reduce_mult, 2));
   }
   else
   {
      Print("KDJ Filter: DISABLED");
   }

   // Initialize MACD Filter (Option E)
   if(enable_macd_filter)
   {
      macd_handle = iMACD(_Symbol, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, PRICE_CLOSE);
      if(macd_handle == INVALID_HANDLE)
      {
         Print("Error creating MACD indicator for MACD Filter");
         return INIT_FAILED;
      }
      macd_signals_passed = 0;
      macd_signals_blocked = 0;
      Print("=== MACD FILTER INITIALIZED (Option E - BLOCK) ===");
      Print("MACD: ", macd_fast, "/", macd_slow, "/", macd_signal);
   }
   else
   {
      Print("MACD Filter: DISABLED");
   }

   // Initialize ADX Slope (Experiment 2)
   if(enable_adx_slope_filter)
   {
      current_adx_slope = 0.0;
      current_adx_slope_state = ADX_SLOPE_FLAT;
      adx_slope_signals_rising = 0;
      adx_slope_signals_flat = 0;
      adx_slope_signals_falling = 0;
      adx_slope_blocked_count = 0;
      Print("=== ADX SLOPE INITIALIZED (Exp 2) === Lookback:", adx_slope_lookback,
            " Rising>=", adx_slope_rising_threshold, " Falling<=", adx_slope_falling_threshold);
   }

   // Initialize ATR Stability (Experiment 3)
   if(enable_atr_stability_filter)
   {
      current_atr_ratio = 1.0;
      current_atr_volatility = 0.0;
      current_atr_state = ATR_STABLE;
      atr_stability_signals_stable = 0;
      atr_stability_signals_volatile = 0;
      atr_stability_signals_extreme = 0;
      atr_stability_blocked_count = 0;
      atr_ratio_min_observed = 999.0;
      atr_ratio_max_observed = -999.0;
      Print("=== ATR STABILITY INITIALIZED (Exp 3) === Period:", atr_stability_period,
            " Ratio:", atr_ratio_lower, "-", atr_ratio_upper, " VolThreshold:", atr_volatility_threshold);
   }

   // Initialize BB Squeeze (Experiment 4)
   if(enable_bb_squeeze_filter)
   {
      bb_squeeze_handle = iBands(_Symbol, PERIOD_CURRENT, bb_period, 0, bb_deviation, PRICE_CLOSE);
      if(bb_squeeze_handle == INVALID_HANDLE)
      {
         Print("Error creating Bollinger Bands indicator for BB Squeeze Filter");
         return INIT_FAILED;
      }
      current_bb_width_atr = 0.0;
      current_bb_squeeze_state = BB_SQUEEZE_NONE;
      was_in_squeeze = false;
      bb_squeeze_signals_allowed = 0;
      bb_squeeze_signals_reduced = 0;
      bb_squeeze_signals_blocked = 0;
      bb_squeeze_breakouts_detected = 0;
      bb_width_min_observed = 999.0;
      bb_width_max_observed = -999.0;
      Print("=== BB SQUEEZE INITIALIZED (Exp 4) === Period:", bb_period,
            " Dev:", bb_deviation,
            " Threshold(ATR):", DoubleToString(bb_squeeze_threshold_atr, 2),
            " Mode:", EnumToString(bb_squeeze_mode),
            " ReduceMult:", DoubleToString(bb_squeeze_risk_mult, 2),
            " TradeBreakout:", (bb_squeeze_trade_breakout ? "YES" : "NO"));
   }

   // Initialize Rolling Performance Gate (Experiment 1)
   if(enable_performance_gate)
   {
      // Initialize circular buffer for trade returns
      ArrayResize(perf_trade_returns, perf_lookback_trades);
      ArrayInitialize(perf_trade_returns, 0.0);
      perf_buffer_index = 0;
      perf_total_trades_tracked = 0;
      perf_consecutive_losses = 0;
      perf_consecutive_loss_cooldown_bars = 0;
      perf_last_loss_time = 0;
      current_perf_tier = PERF_TIER_FULL;

      // Initialize rolling metrics
      rolling_sharpe = 0.0;
      rolling_mean_return = 0.0;
      rolling_std_return = 0.0;
      rolling_win_rate = 0.0;
      rolling_wins = 0;
      rolling_losses = 0;

      // Reset instrumentation
      perf_signals_full_trade = 0;
      perf_signals_reduced = 0;
      perf_signals_blocked = 0;
      perf_tier_transitions = 0;
      perf_min_sharpe_observed = 999.0;
      perf_max_sharpe_observed = -999.0;

      Print("=== ROLLING PERFORMANCE GATE INITIALIZED (Experiment 1) ===");
      Print("Lookback Period: ", perf_lookback_trades, " trades");
      Print("Sharpe Thresholds: Full >= ", perf_sharpe_full_trade,
            " | Reduced >= ", perf_sharpe_reduced,
            " | Block < ", perf_sharpe_block);
      Print("Reduced Risk Multiplier: ", DoubleToString(perf_reduced_risk_multiplier * 100, 0), "%");
      Print("Min Trades Required: ", perf_min_trades_required);
      Print("Consecutive Loss Limit: ", perf_consecutive_loss_limit);
      Print("Consecutive Loss Cooldown: ", perf_consecutive_loss_cooldown, " bars");
   }
   else
   {
      Print("Rolling Performance Gate: DISABLED");
   }

   // Initialize Enhanced Risk Management
   if(enable_equity_curve_protection)
   {
      equity_peak_value = AccountInfoDouble(ACCOUNT_EQUITY);
      equity_peak_percent = 0.0;
      equity_trailing_active = false;
      Print("=== EQUITY CURVE PROTECTION INITIALIZED ===");
      Print("Trailing Start: ", equity_trailing_start, "% | Step: ", equity_trailing_step, "% | Stop: ", equity_trailing_stop, "%");
   }
   
   if(enable_correlation_risk_management)
   {
      same_direction_trade_count = 0;
      last_trade_direction = WRONG_VALUE;
      Print("=== CORRELATION RISK MANAGEMENT INITIALIZED ===");
      Print("Max Same Direction Trades: ", max_same_direction_trades, " | Risk Multiplier: ", correlation_risk_multiplier);
   }
   
   if(enable_volatility_position_sizing)
   {
      Print("=== VOLATILITY POSITION SIZING INITIALIZED ===");
      Print("Volatility Threshold: ", volatility_reduce_threshold, "x ATR | Risk Multiplier: ", volatility_reduce_multiplier);
   }

   // Initialize Ichimoku Cloud strategy
   if(!initialize_single_strategy(single_strategy))
      return INIT_FAILED;
   
   // Initialize trade object
   trade.SetExpertMagicNumber(123456);
   trade.SetDeviationInPoints(10);
   
   // Initialize Daily Drawdown Management
   if(daily_drawdown_mode != DD_MODE_DISABLED)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      last_daily_check_date = StructToTime(dt);
      daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      daily_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      current_dd_tier = DD_TIER_SAFE;
      current_dd_percent = 0.0;
      daily_drawdown_exceeded = false;

      
      if(daily_drawdown_mode == DD_MODE_TIERED)
      {
         Print("Daily Drawdown initialized - Mode: TIERED SYSTEM");
         Print("  Tier 1 (Warning): ", dd_tier1_threshold, "% → Risk ", DoubleToString(dd_tier1_risk_multiplier * 100, 0), "%");
         Print("  Tier 2 (Danger): ", dd_tier2_threshold, "% → Risk ", DoubleToString(dd_tier2_risk_multiplier * 100, 0), "%");
         Print("  Tier 3 (Stop): ", dd_tier3_threshold, "% → Trading STOPPED");
         Print("  Start Balance: ", daily_start_balance, " | Start Equity: ", daily_start_equity);
      }
   }
   else
   {
      Print("Daily Drawdown: DISABLED");
   }
   
   // Initialize Trading Session Management
   if(trading_session != SESSION_DISABLED)
   {
      last_session_check_time = TimeCurrent();
      session_positions_closed = false;
      Print("Trading Session initialized - Session: ", EnumToString(trading_session),
            " | Stop trading ", IntegerToString(candles_before_session_end), " candles before session end",
            " | Close positions on session end: ", (close_positions_on_session_end ? "Yes" : "No"));
   }

   // Initialize Swap Avoidance System
   current_timeframe = Period();
   switch(current_timeframe)
   {
      case PERIOD_M1:  swap_safe_close_minutes = 15;   break;  // 21:58 GMT
      case PERIOD_M5:  swap_safe_close_minutes = 15;   break;  // 21:55 GMT
      case PERIOD_M15: swap_safe_close_minutes = 15;  break;  // 21:45 GMT
      case PERIOD_M30: swap_safe_close_minutes = 30;  break;  // 21:30 GMT
      case PERIOD_H1:  swap_safe_close_minutes = 60;  break;  // 21:00 GMT
      case PERIOD_H4:  swap_safe_close_minutes = 240; break;  // 18:00 GMT
      default:         swap_safe_close_minutes = 15;  break;  // Safe default
   }

   int close_hour = (22 * 60 - swap_safe_close_minutes) / 60;
   int close_min = (22 * 60 - swap_safe_close_minutes) % 60;

   Print("=== SWAP AVOIDANCE SYSTEM ===");
   Print("Timeframe: ", EnumToString(current_timeframe));
   Print("Daily close time: ", close_hour, ":", StringFormat("%02d", close_min), " GMT");
   Print("Rollover: 22:00 GMT | Buffer: ", swap_safe_close_minutes, " minutes");

   string init_msg = "Ichimoku Cloud EA initialized - Mode: SINGLE | Strategy: Ichimoku Cloud";
   
   // Add Grid Trading info
   if(grid_trading_enabled)
   {
      init_msg += " | Grid: ON";
      init_msg += " | Mode: Anti-Trend";
      init_msg += " | Max Orders: " + IntegerToString(max_grid_orders);
      init_msg += " | Spacing: " + (use_atr_for_grid_spacing ? ("ATR x" + DoubleToString(grid_spacing_atr_multiplier, 1)) : 
                                                                (DoubleToString(grid_spacing_percentage * 100, 2) + "%"));
      init_msg += " | Risk Multiplier: " + DoubleToString(grid_risk_multiplier, 1);
   }
   else
   {
      init_msg += " | Grid: OFF";
   }


   Print(init_msg);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //+------------------------------------------------------------------+
   //| INSTRUMENTATION REPORT: Parameter Sensitivity Activation Metrics |
   //+------------------------------------------------------------------+
   Print("");
   Print("========================================================================");
   Print("   PARAMETER SENSITIVITY - ACTIVATION METRICS REPORT");
   Print("   Proving NO-EFFECT claims with actual backtest data");
   Print("========================================================================");
   Print("");

   // 1. Take Profit Usage (reward_risk_ratio NO-EFFECT verification)
   Print("--- [1] TAKE PROFIT USAGE (reward_risk_ratio) ---");
   Print("  Total Trades Opened: ", total_trades_opened);
   Print("  Trades WITH TP > 0:  ", trades_with_tp, " (",
         (total_trades_opened > 0 ? DoubleToString(100.0 * trades_with_tp / total_trades_opened, 2) : "0.00"), "%)");
   Print("  Trades WITHOUT TP:   ", trades_without_tp, " (",
         (total_trades_opened > 0 ? DoubleToString(100.0 * trades_without_tp / total_trades_opened, 2) : "0.00"), "%)");
   Print("  Conclusion: ", (trades_without_tp > 0.95 * total_trades_opened ? "CONFIRMED NO-EFFECT (trailing mode)" :
                            "WARNING: TP used more than expected"));
   Print("");

   // 2. Trailing Stop Activation (atr_trailing_* NO-EFFECT verification)
   Print("--- [2] TRAILING STOP ACTIVATION (atr_trailing_*) ---");
   Print("  Trailing Activated:  ", trailing_activated_count, " trades (",
         (total_trades_opened > 0 ? DoubleToString(100.0 * trailing_activated_count / total_trades_opened, 2) : "0.00"), "%)");
   Print("  Trailing Modified:   ", trailing_modified_count, " times");
   Print("  Avg Modifies/Trade:  ", (trailing_activated_count > 0 ? DoubleToString(1.0 * trailing_modified_count / trailing_activated_count, 2) : "0.00"));
   Print("  Conclusion: ", (trailing_activated_count < 0.20 * total_trades_opened ? "CONFIRMED NO-EFFECT (rarely activates)" :
                            "WARNING: Trailing activates frequently"));
   Print("");

   // 3. Grid Depth Distribution (max_grid_orders NO-EFFECT verification)
   Print("--- [3] GRID DEPTH DISTRIBUTION (max_grid_orders) ---");
   Print("  Max Grid Depth Reached: ", max_grid_depth_reached);
   Print("  Grid Depth Histogram:");
   for(int i = 0; i < 10; i++)
   {
      if(grid_depth_histogram[i] > 0)
         Print("    Depth ", i, ": ", grid_depth_histogram[i], " occurrences");
   }
   Print("  Conclusion: ", (max_grid_depth_reached <= 2 ? "CONFIRMED NO-EFFECT (depth ≤2, non-binding)" :
                            "WARNING: Grid depth reaches limit"));
   Print("");

   // 4. Daily Drawdown Tier Triggers (dd_tier2 activation verification)
   Print("--- [4] DAILY DRAWDOWN TIERS (dd_tier2_risk_multiplier) ---");
   Print("  Tier 1 (Warning) Triggered: ", dd_tier1_triggered_count, " times");
   Print("  Tier 2 (Danger) Triggered:  ", dd_tier2_triggered_count, " times");
   Print("  Tier 3 (Stop) Triggered:    ", dd_tier3_triggered_count, " times");
   Print("  Conclusion Tier2: ", (dd_tier2_triggered_count == 0 ? "CONFIRMED NO-EFFECT (never triggered)" :
                                   "ACTIVATED - parameter has effect"));
   Print("");

   // 5. Market Regime Filter Effectiveness (ADX-based filtering)
   Print("--- [5] MARKET REGIME FILTER EFFECTIVENESS (ADX) ---");
   Print("  Filter Status: ", (enable_market_regime_filter ? "ENABLED" : "DISABLED"));
   if(enable_market_regime_filter)
   {
      Print("  Total Ichimoku Signals: ", total_signals_checked);
      Print("  Signals PASSED (Trending): ", signals_passed_regime, " (",
            (total_signals_checked > 0 ? DoubleToString(100.0 * signals_passed_regime / total_signals_checked, 2) : "0.00"), "%)");
      Print("  Signals BLOCKED (Ranging): ", signals_blocked_ranging, " (",
            (total_signals_checked > 0 ? DoubleToString(100.0 * signals_blocked_ranging / total_signals_checked, 2) : "0.00"), "%)");
      Print("  Signals BLOCKED (Weak Trend): ", signals_blocked_weak_trend, " (",
            (total_signals_checked > 0 ? DoubleToString(100.0 * signals_blocked_weak_trend / total_signals_checked, 2) : "0.00"), "%)");
      Print("  Filter Rate: ", 
            (total_signals_checked > 0 ? DoubleToString(100.0 * (signals_blocked_ranging + signals_blocked_weak_trend) / total_signals_checked, 2) : "0.00"), 
            "% of signals filtered");
      Print("  Conclusion: ", (signals_blocked_ranging + signals_blocked_weak_trend > 0 ? 
                                "ACTIVE - Filter is working" : 
                                "INACTIVE - All markets were trending"));
   }
   else
   {
      Print("  (Filter was disabled - no data collected)");
   }
   Print("");

   // 5.5. RSI Momentum Filter Effectiveness
   Print("--- [5.5] RSI MOMENTUM FILTER EFFECTIVENESS ---");
   Print("  Filter Status: ", (enable_rsi_filter ? "ENABLED" : "DISABLED"));
   if(enable_rsi_filter)
   {
      int total_rsi_checks = rsi_signals_passed + rsi_signals_blocked_overbought + 
                            rsi_signals_blocked_oversold + rsi_signals_blocked_momentum;
      Print("  Configuration:");
      Print("    RSI Period: ", rsi_period);
      Print("    Overbought Level: ", rsi_overbought);
      Print("    Oversold Level: ", rsi_oversold);
      Print("    Neutral Zone: ", rsi_neutral_zone_low, "-", rsi_neutral_zone_high);
      Print("    Divergence Detection: ", (rsi_use_divergence ? "ENABLED" : "DISABLED"));
      Print("");
      Print("  Filter Actions:");
      Print("    Signals PASSED: ", rsi_signals_passed, " (",
            (total_rsi_checks > 0 ? DoubleToString(100.0 * rsi_signals_passed / total_rsi_checks, 2) : "0.00"), "%)");
      Print("    Signals BLOCKED (Overbought): ", rsi_signals_blocked_overbought, " (",
            (total_rsi_checks > 0 ? DoubleToString(100.0 * rsi_signals_blocked_overbought / total_rsi_checks, 2) : "0.00"), "%)");
      Print("    Signals BLOCKED (Oversold): ", rsi_signals_blocked_oversold, " (",
            (total_rsi_checks > 0 ? DoubleToString(100.0 * rsi_signals_blocked_oversold / total_rsi_checks, 2) : "0.00"), "%)");
      Print("    Signals BLOCKED (Momentum): ", rsi_signals_blocked_momentum, " (",
            (total_rsi_checks > 0 ? DoubleToString(100.0 * rsi_signals_blocked_momentum / total_rsi_checks, 2) : "0.00"), "%)");
      Print("    Total Filter Rate: ",
            (total_rsi_checks > 0 ? DoubleToString(100.0 * (rsi_signals_blocked_overbought + rsi_signals_blocked_oversold + rsi_signals_blocked_momentum) / total_rsi_checks, 2) : "0.00"),
            "% of signals filtered");
      Print("  Conclusion: ", ((rsi_signals_blocked_overbought + rsi_signals_blocked_oversold + rsi_signals_blocked_momentum) > 0 ?
                                "ACTIVE - Filter is working to improve signal quality" :
                                "INACTIVE - All signals had favorable RSI conditions"));
   }
   else
   {
      Print("  (Filter was disabled - no data collected)");
   }
   Print("");

   // 6. Rolling Performance Gate Effectiveness (Experiment 1)
   Print("--- [6] ROLLING PERFORMANCE GATE (Experiment 1) ---");
   Print("  Filter Status: ", (enable_performance_gate ? "ENABLED" : "DISABLED"));
   if(enable_performance_gate)
   {
      Print("  Configuration:");
      Print("    Lookback Trades: ", perf_lookback_trades);
      Print("    Sharpe Full Trade: >= ", perf_sharpe_full_trade);
      Print("    Sharpe Reduced: >= ", perf_sharpe_reduced);
      Print("    Sharpe Block: < ", perf_sharpe_block);
      Print("    Consecutive Loss Limit: ", perf_consecutive_loss_limit);
      Print("");
      Print("  Performance Metrics:");
      Print("    Total Trades Tracked: ", perf_total_trades_tracked);
      Print("    Final Rolling Sharpe: ", DoubleToString(rolling_sharpe, 2));
      Print("    Final Rolling Win Rate: ", DoubleToString(rolling_win_rate, 1), "%");
      Print("    Min Sharpe Observed: ", DoubleToString(perf_min_sharpe_observed, 2));
      Print("    Max Sharpe Observed: ", DoubleToString(perf_max_sharpe_observed, 2));
      Print("");
      Print("  Gate Actions:");
      int total_gate_decisions = perf_signals_full_trade + perf_signals_reduced + perf_signals_blocked;
      Print("    Signals at FULL trade: ", perf_signals_full_trade, " (",
            (total_gate_decisions > 0 ? DoubleToString(100.0 * perf_signals_full_trade / total_gate_decisions, 2) : "0.00"), "%)");
      Print("    Signals at REDUCED trade: ", perf_signals_reduced, " (",
            (total_gate_decisions > 0 ? DoubleToString(100.0 * perf_signals_reduced / total_gate_decisions, 2) : "0.00"), "%)");
      Print("    Signals BLOCKED: ", perf_signals_blocked, " (",
            (total_gate_decisions > 0 ? DoubleToString(100.0 * perf_signals_blocked / total_gate_decisions, 2) : "0.00"), "%)");
      Print("    Tier Transitions: ", perf_tier_transitions);
      Print("");
      Print("  Conclusion: ", (perf_signals_blocked + perf_signals_reduced > 0 ?
                                "ACTIVE - Performance Gate filtered trades" :
                                "INACTIVE - All trades at full size"));
   }
   else
   {
      Print("  (Filter was disabled - no data collected)");
   }
   Print("");

   // 7. ADX Slope (Experiment 2)
   Print("--- [7] ADX SLOPE (Experiment 2) ---");
   if(enable_adx_slope_filter)
   {
      Print("  Lookback:", adx_slope_lookback, " Rising>=", adx_slope_rising_threshold, " Falling<=", adx_slope_falling_threshold);
      Print("  Min/Max Slope: ", DoubleToString(adx_slope_min_observed, 2), "/", DoubleToString(adx_slope_max_observed, 2));
      Print("  Rising:", adx_slope_signals_rising, " Flat:", adx_slope_signals_flat, " Falling:", adx_slope_signals_falling);
      Print("  Blocked:", adx_slope_blocked_count);
   }
   else Print("  DISABLED");
   Print("");

   // 8. ATR Stability (Experiment 3)
   Print("--- [8] ATR STABILITY (Experiment 3) ---");
   if(enable_atr_stability_filter)
   {
      Print("  Period:", atr_stability_period, " Ratio Range:", DoubleToString(atr_ratio_lower, 2), "-", DoubleToString(atr_ratio_upper, 2),
            " Vol Threshold:", DoubleToString(atr_volatility_threshold, 2));
      Print("  Observed ATR Ratio Min/Max: ", DoubleToString(atr_ratio_min_observed, 3), "/", DoubleToString(atr_ratio_max_observed, 3));
      Print("  Current ATR Ratio: ", DoubleToString(current_atr_ratio, 3), " | Volatility: ", DoubleToString(current_atr_volatility, 3));
      int total_atr_signals = atr_stability_signals_stable + atr_stability_signals_volatile + atr_stability_signals_extreme;
      Print("  States - Stable:", atr_stability_signals_stable, " (",
            (total_atr_signals > 0 ? DoubleToString(100.0 * atr_stability_signals_stable / total_atr_signals, 1) : "0.0"), "%)");
      Print("         - Volatile:", atr_stability_signals_volatile, " (",
            (total_atr_signals > 0 ? DoubleToString(100.0 * atr_stability_signals_volatile / total_atr_signals, 1) : "0.0"), "%)");
      Print("         - Extreme:", atr_stability_signals_extreme, " (",
            (total_atr_signals > 0 ? DoubleToString(100.0 * atr_stability_signals_extreme / total_atr_signals, 1) : "0.0"), "%)");
      Print("  Blocked (Extreme): ", atr_stability_blocked_count);
      Print("  Conclusion: ", (atr_stability_signals_volatile + atr_stability_blocked_count > 0 ?
                                "ACTIVE - ATR Stability filtered trades" :
                                "INACTIVE - All signals in stable ATR zone"));
   }
   else Print("  DISABLED");
   Print("");

   // 9. Adaptive Filter System
   Print("--- [9] ADAPTIVE FILTER SYSTEM ---");
   if(enable_adaptive_filters)
   {
      Print("  Lookback Bars:", adaptive_lookback_bars,
            " | ADX Rel High:", DoubleToString(adx_reliability_high, 2),
            " | ADX Rel Low:", DoubleToString(adx_reliability_low, 2),
            " | ATR Vol Thresh:", DoubleToString(adaptive_atr_vol_threshold, 2));
      Print("");
      Print("  ADX Reliability Score:");
      Print("    Min/Max: ", DoubleToString(adx_reliability_min, 2), " / ", DoubleToString(adx_reliability_max, 2));
      Print("    Average: ", (adx_reliability_samples > 0 ? DoubleToString(adx_reliability_sum / adx_reliability_samples, 2) : "N/A"));
      Print("    Samples: ", adx_reliability_samples);
      Print("");
      Print("  Regime Distribution:");
      int total_regime_samples = regime_full_count + regime_no_exp2_count + regime_exp1_only_count +
                                  regime_exp3_only_count + regime_exp1_exp3_count + regime_none_count;
      Print("    FULL (MR+1+2+3): ", regime_full_count, " (",
            (total_regime_samples > 0 ? DoubleToString(100.0 * regime_full_count / total_regime_samples, 1) : "0"), "%)");
      Print("    NO_EXP2 (MR+1+3): ", regime_no_exp2_count, " (",
            (total_regime_samples > 0 ? DoubleToString(100.0 * regime_no_exp2_count / total_regime_samples, 1) : "0"), "%)");
      Print("    EXP1_ONLY: ", regime_exp1_only_count, " (",
            (total_regime_samples > 0 ? DoubleToString(100.0 * regime_exp1_only_count / total_regime_samples, 1) : "0"), "%)");
      Print("    EXP3_ONLY: ", regime_exp3_only_count, " (",
            (total_regime_samples > 0 ? DoubleToString(100.0 * regime_exp3_only_count / total_regime_samples, 1) : "0"), "%)");
      Print("    EXP1+EXP3: ", regime_exp1_exp3_count, " (",
            (total_regime_samples > 0 ? DoubleToString(100.0 * regime_exp1_exp3_count / total_regime_samples, 1) : "0"), "%)");
      Print("    NONE: ", regime_none_count, " (",
            (total_regime_samples > 0 ? DoubleToString(100.0 * regime_none_count / total_regime_samples, 1) : "0"), "%)");
      Print("");
      Print("  Regime Changes: ", regime_change_count);
      Print("  Final Regime: ", EnumToString(current_filter_regime));
   }
   else Print("  DISABLED");
   Print("");

   // 10. Time Filter (v5 NEW!)
   Print("--- [10] 🕐 TIME FILTER (v5 NEW!) ---");
   if(enable_time_filter)
   {
      Print("  Filter Status: ENABLED");
      Print("  Configuration:");
      Print("    Danger Zone 1: ", danger_hour1_start, ":00 - ", danger_hour1_end, ":00 UTC (Early Asian)");
      Print("    Danger Zone 2: ", danger_hour2_start, ":00 - ", danger_hour2_end, ":00 UTC (NY Close)");
      Print("    Filter Mode: ", EnumToString(time_filter_mode));
      if(time_filter_mode == TIME_FILTER_REDUCE_SIZE)
         Print("    Size Multiplier: ", DoubleToString(time_filter_size_mult * 100, 0), "%");
      if(time_filter_mode == TIME_FILTER_LIMIT_GRID)
         Print("    Max Grid Load: ", DoubleToString(time_filter_max_grid_load, 2), "%");
      Print("");
      Print("  Filter Actions:");
      Print("    Signals BLOCKED: ", time_filter_blocked_count);
      Print("    Signals REDUCED: ", time_filter_reduced_count);
      Print("    Emergency Close: ", (time_filter_close_on_danger ? "ENABLED" : "DISABLED"));
      Print("");
      Print("  Expected Impact: ~55% reduction in extreme events");
      Print("  Conclusion: ", (time_filter_blocked_count + time_filter_reduced_count > 0 ?
                                "ACTIVE - Time Filter affected trading" :
                                "INACTIVE - No trades during dangerous hours OR no dangerous hours occurred"));
   }
   else
   {
      Print("  Filter Status: DISABLED");
      Print("  (Enable to avoid trading during dangerous hours)");
   }
   Print("");

   // 11. Grid Expansion Control (v6 NEW!)
   Print("--- [11] 🚨 GRID EXPANSION CONTROL (v6 NEW!) ---");
   if(enable_grid_expansion_filter)
   {
      Print("  Filter Status: ENABLED");
      Print("  Configuration:");
      Print("    Max DL Threshold: ", DoubleToString(grid_expansion_max_dl, 2), "%");
      Print("    Block in Danger Zone: ", (grid_expansion_block_in_danger ? "YES" : "NO"));
      Print("    Emergency Spike Detection: ", (grid_expansion_close_on_spike ? "ENABLED" : "DISABLED"));
      if(grid_expansion_close_on_spike)
         Print("    Spike Threshold: ", DoubleToString(grid_expansion_spike_threshold, 2), "%");
      Print("");
      Print("  Filter Actions:");
      Print("    Grid Expansions BLOCKED: ", grid_expansion_blocked_count);
      Print("    DL Spikes Detected: ", grid_expansion_spike_detected);
      if(grid_expansion_spike_detected > 0)
         Print("    ⚠️  Emergency closes triggered: ", grid_expansion_spike_detected);
      Print("");
      Print("  Problem Solved:");
      Print("    • Prevents grid expansion in danger zones");
      Print("    • Blocks expansion when DL > threshold");
      Print("    • Detects sudden DL spikes (like 2026.01.19 20:25)");
      Print("  Conclusion: ", (grid_expansion_blocked_count > 0 ?
                                "ACTIVE - Grid expansion was controlled" :
                                "INACTIVE - No grid expansions attempted OR all allowed"));
   }
   else
   {
      Print("  Filter Status: DISABLED");
      Print("  ⚠️  WARNING: Grid can expand even in danger zones!");
      Print("  (Enable to prevent grid expansion bugs)");
   }
   Print("");

   Print("========================================================================");
   Print("   END OF INSTRUMENTATION REPORT");
   Print("========================================================================");
   Print("");

   // Release indicator handles
   if(atr_sl_tp_handle != INVALID_HANDLE) IndicatorRelease(atr_sl_tp_handle);
   if(atr_trailing_handle != INVALID_HANDLE) IndicatorRelease(atr_trailing_handle);
   if(grid_atr_handle != INVALID_HANDLE) IndicatorRelease(grid_atr_handle);

   // Release HTF Bias handles
   if(htf_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(htf_ema_fast_handle);
   if(htf_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(htf_ema_slow_handle);
   if(htf_atr_handle != INVALID_HANDLE) IndicatorRelease(htf_atr_handle);

   // Release Market Regime Filter handles
   if(mr_adx_handle != INVALID_HANDLE) IndicatorRelease(mr_adx_handle);
   if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);

   // Release ROC / KDJ handles
   if(roc_handle != INVALID_HANDLE) IndicatorRelease(roc_handle);
   if(kdj_handle != INVALID_HANDLE) IndicatorRelease(kdj_handle);

   if(macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
   if(bb_squeeze_handle != INVALID_HANDLE) IndicatorRelease(bb_squeeze_handle);

   ArrayFree(managed_positions);
   ArrayFree(loss_trackers);
   ArrayFree(grid_positions);
   ArrayFree(perf_trade_returns);
}

//+------------------------------------------------------------------+
//| OnTrade - Track consecutive wins/losses (V2 - Smart System)     |
//+------------------------------------------------------------------+
void OnTrade()
{

   if(!HistorySelect(0, TimeCurrent()))
      return;

   int total_deals = HistoryDealsTotal();
   if(total_deals <= 0)
      return;

   ulong deal_ticket = HistoryDealGetTicket(total_deals - 1);
   if(deal_ticket <= 0)
      return;

   if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;

   double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
   double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
   double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
   double net_profit = profit + swap + commission;

   long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   bool is_buy_close = (deal_type == DEAL_TYPE_SELL);
   bool is_sell_close = (deal_type == DEAL_TYPE_BUY);

   // ROLLING PERFORMANCE GATE: Track trade result
   // Get current equity for calculating return percentage
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   add_trade_to_performance_buffer(net_profit, current_equity);
}

//+------------------------------------------------------------------+
//| Check Total Max Drawdown and Close Losers if Exceeded            |
//+------------------------------------------------------------------+
void check_total_max_dd()
{
   if(!enable_total_max_dd)
      return;

   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(total_dd_peak_equity <= 0)
      total_dd_peak_equity = current_equity;

   if(current_equity > total_dd_peak_equity)
      total_dd_peak_equity = current_equity;

   double current_dd = 0.0;
   if(total_dd_peak_equity > 0)
      current_dd = (total_dd_peak_equity - current_equity) / total_dd_peak_equity * 100.0;

   if(current_dd >= total_max_dd_percent)
   {
      if(!total_dd_exceeded)
      {
         total_dd_exceeded = true;
         Print("🛑 TOTAL MAX DD EXCEEDED: ", DoubleToString(current_dd, 2), "% | Peak: ", total_dd_peak_equity, " | Current: ", current_equity);
      }

      if(total_dd_close_losers)
      {
         static datetime last_close_time = 0;
         if(TimeCurrent() - last_close_time >= 5)
         {
            int closed_count = 0;
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               ulong ticket = PositionGetTicket(i);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetDouble(POSITION_PROFIT) < 0)
                  {
                     if(trade.PositionClose(ticket))
                        closed_count++;
                  }
               }
            }

            if(closed_count > 0)
               Print("🛡️ TOTAL MAX DD: Closed ", closed_count, " losing positions. Winners kept running.");

            last_close_time = TimeCurrent();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Daily Drawdown and Reset if New Day                        |
//+------------------------------------------------------------------+
void check_daily_drawdown()
{
   if(daily_drawdown_mode == DD_MODE_DISABLED)
      return;

   datetime current_time = TimeCurrent();
   MqlDateTime current_dt, last_dt;
   TimeToStruct(current_time, current_dt);
   TimeToStruct(last_daily_check_date, last_dt);

   // Check if it's a new day (reset at start of new day)
   bool is_new_day = (current_dt.day != last_dt.day ||
                      current_dt.mon != last_dt.mon ||
                      current_dt.year != last_dt.year);

   if(is_new_day)
   {
      // Reset for new day
      daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      daily_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      current_dd_tier = DD_TIER_SAFE;
      current_dd_percent = 0.0;
      daily_drawdown_exceeded = false;
      
      // [v4] Reset profit protection for new day
      daily_peak_profit_percent = 0.0;
      dynamic_dd_tier3 = dd_tier3_threshold;  // Reset to default
      profit_protection_active = false;
      
      // Reset Equity Curve Protection (if enabled) - Allow fresh start each day
      if(enable_equity_curve_protection)
      {
         equity_peak_value = AccountInfoDouble(ACCOUNT_EQUITY);
         equity_peak_percent = 0.0;
         equity_trailing_active = false;
         Print("=== EQUITY CURVE PROTECTION: Daily reset - Fresh start ===");
      }

      // Update last check date to start of current day
      current_dt.hour = 0;
      current_dt.min = 0;
      current_dt.sec = 0;
      last_daily_check_date = StructToTime(current_dt);

      Print("=== NEW DAY - Daily Drawdown Tiered System Reset ===");
      Print("Start Balance: ", daily_start_balance, " | Start Equity: ", daily_start_equity);
      Print("DD Tier: SAFE | Risk Multiplier: 1.00 (100%)");
      if(enable_profit_protection)
         Print("💰 Profit Protection: ENABLED (trigger @ ", profit_protect_trigger, "%)");
   }

   // Calculate current drawdown
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Use the higher of balance or equity at start of day as reference
   double start_reference = MathMax(daily_start_balance, daily_start_equity);
   double current_reference = MathMax(current_balance, current_equity);

   // Calculate drawdown percentage (negative = profit, positive = loss)
   double drawdown_amount = start_reference - current_reference;
   current_dd_percent = 0;

   if(start_reference > 0)
   {
      current_dd_percent = (drawdown_amount / start_reference) * 100.0;
   }
   
   // [v4] TRAILING PROFIT PROTECTION LOGIC
   // Negative dd_percent = profit, so profit_percent = -current_dd_percent
   double current_profit_percent = -current_dd_percent;
   
   if(enable_profit_protection && current_profit_percent > 0)
   {
      // Track peak profit
      if(current_profit_percent > daily_peak_profit_percent)
      {
         daily_peak_profit_percent = current_profit_percent;
      }
      
      // Check if should activate profit protection
      if(daily_peak_profit_percent >= profit_protect_trigger)
      {
         // Calculate dynamic circuit breaker
         // Example: Peak profit 1.0%, keep 60% = lock in 0.6%
         // So max allowed loss from peak = 1.0% - 0.6% = 0.4%
         // But we also need a minimum buffer to avoid closing too early
         double profit_to_keep = daily_peak_profit_percent * profit_protect_keep_ratio;
         double allowed_drawdown_from_peak = daily_peak_profit_percent - profit_to_keep;
         
         // Ensure minimum buffer
         allowed_drawdown_from_peak = MathMax(allowed_drawdown_from_peak, profit_protect_min_buffer);
         
         // The dynamic threshold = -(peak_profit - allowed_drawdown)
         // If peak was 1.0% and we allow 0.4% drawdown from peak
         // Current profit of 0.6% would be the trigger point
         // That's equivalent to dd_percent of -0.6%
         // We want to close when current_dd_percent >= -profit_to_keep
         // But the tier system checks dd_percent >= threshold
         // So dynamic_dd_tier3 should be the max loss from day start, not from peak
         
         // Simplified: If currently at 0.5% profit and peak was 1.0%
         // We've given back 0.5% from peak
         // If allowed_drawdown_from_peak is 0.4%, we should close
         double given_back_from_peak = daily_peak_profit_percent - current_profit_percent;
         
         if(given_back_from_peak >= allowed_drawdown_from_peak && !profit_protection_active)
         {
            profit_protection_active = true;
            profit_protection_triggers++;
            Print("💰 PROFIT PROTECTION TRIGGERED!");
            Print("   Peak Profit: ", DoubleToString(daily_peak_profit_percent, 2), "%");
            Print("   Current Profit: ", DoubleToString(current_profit_percent, 2), "%");
            Print("   Given Back: ", DoubleToString(given_back_from_peak, 2), "% (max allowed: ", DoubleToString(allowed_drawdown_from_peak, 2), "%)");
            Print("   Action: Closing all positions to lock in ", DoubleToString(current_profit_percent, 2), "% profit");
            
            // Close all positions to lock in profit
            close_all_positions();
            daily_drawdown_exceeded = true;  // Stop further trading today
            return;
         }
      }
   }

   // === MODE 2: TIERED MODE ===
   if(daily_drawdown_mode == DD_MODE_TIERED)
   {
      // Store previous tier to detect changes
      ENUM_DD_TIER previous_tier = current_dd_tier;

      // Determine current DD tier based on thresholds
      if(current_dd_percent >= dd_tier3_threshold)
      {
         current_dd_tier = DD_TIER_STOPPED;
         daily_drawdown_exceeded = true; // For backward compatibility
      }
      else if(current_dd_percent >= dd_tier2_threshold)
      {
         current_dd_tier = DD_TIER_DANGER;
         daily_drawdown_exceeded = false;
      }
      else if(current_dd_percent >= dd_tier1_threshold)
      {
         current_dd_tier = DD_TIER_WARNING;
         daily_drawdown_exceeded = false;
      }
      else
      {
         current_dd_tier = DD_TIER_SAFE;
         daily_drawdown_exceeded = false;
      }

      // INSTRUMENTATION: Track DD tier transitions
      if(current_dd_tier != previous_dd_tier)
      {
         // Count tier activations (count upward transitions)
         if(previous_dd_tier == DD_TIER_SAFE && current_dd_tier == DD_TIER_WARNING)
            dd_tier1_triggered_count++;
         else if(previous_dd_tier <= DD_TIER_WARNING && current_dd_tier == DD_TIER_DANGER)
            dd_tier2_triggered_count++;
         else if(previous_dd_tier <= DD_TIER_DANGER && current_dd_tier == DD_TIER_STOPPED)
            dd_tier3_triggered_count++;

         previous_dd_tier = current_dd_tier;  // Update tracking
      }

      // Print tier change notification
      if(current_dd_tier != previous_tier)
      {
         Print("=== DAILY DRAWDOWN TIER CHANGED ===");
         Print("Previous Tier: ", EnumToString(previous_tier), " → New Tier: ", EnumToString(current_dd_tier));
         Print("Current DD: ", DoubleToString(current_dd_percent, 2), "% | Start: ", start_reference, " | Current: ", current_reference);

         switch(current_dd_tier)
         {
            case DD_TIER_SAFE:
               Print("✅ SAFE ZONE - Normal trading (100% position size)");
               break;

            case DD_TIER_WARNING:
               Print("⚠️ WARNING ZONE - Reduced position size (", DoubleToString(dd_tier1_risk_multiplier * 100, 0), "%)");
               Print("Threshold: ", dd_tier1_threshold, "% | Risk Multiplier: ", dd_tier1_risk_multiplier);
               break;

            case DD_TIER_DANGER:
               Print("🔴 DANGER ZONE - Heavily reduced position size (", DoubleToString(dd_tier2_risk_multiplier * 100, 0), "%)");
               Print("Threshold: ", dd_tier2_threshold, "% | Risk Multiplier: ", dd_tier2_risk_multiplier);
               break;

            case DD_TIER_STOPPED:
               Print("🛑 CRITICAL ZONE - Trading STOPPED!");
               Print("Threshold: ", dd_tier3_threshold, "% exceeded | Closing all positions...");
               close_all_positions();
               break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Risk Multiplier based on current DD Tier                    |
//+------------------------------------------------------------------+
double get_risk_multiplier_by_dd_tier()
{
   if(daily_drawdown_mode == DD_MODE_DISABLED)
      return 1.0; // No DD system, return 100%

   // For TIERED mode: gradual reduction based on tier
   switch(current_dd_tier)
   {
      case DD_TIER_SAFE:
         return 1.0; // 100% normal risk

      case DD_TIER_WARNING:
         return dd_tier1_risk_multiplier; // e.g., 0.75 = 75%

      case DD_TIER_DANGER:
         return dd_tier2_risk_multiplier; // e.g., 0.50 = 50%

      case DD_TIER_STOPPED:
         return 0.0; // No trading allowed

      default:
         return 1.0; // Default to normal risk
   }
}

//+------------------------------------------------------------------+
//| ROLLING PERFORMANCE GATE - Core Functions (Experiment 1)         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Add trade result to rolling performance buffer                   |
//| Called from OnTrade() when a position is closed                  |
//+------------------------------------------------------------------+
void add_trade_to_performance_buffer(double net_profit, double equity_at_close)
{
   if(!enable_performance_gate)
      return;

   // Calculate return as percentage of equity
   double trade_return = 0.0;
   if(equity_at_close > 0)
      trade_return = (net_profit / equity_at_close) * 100.0; // Return as percentage

   // Track consecutive losses
   if(net_profit < 0)
   {
      perf_consecutive_losses++;
      rolling_losses++;
   }
   else
   {
      perf_consecutive_losses = 0; // Reset on win
      rolling_wins++;
   }

   // Add to circular buffer
   perf_trade_returns[perf_buffer_index] = trade_return;
   perf_buffer_index = (perf_buffer_index + 1) % perf_lookback_trades;
   perf_total_trades_tracked++;

   // Recalculate rolling metrics
   calculate_rolling_metrics();

   // Update performance tier
   update_performance_tier();

   // Debug output
   Print("📊 PERF GATE: Trade added | Return: ", DoubleToString(trade_return, 4), "% | ",
         "Consecutive Losses: ", perf_consecutive_losses, " | ",
         "Rolling Sharpe: ", DoubleToString(rolling_sharpe, 2), " | ",
         "Tier: ", EnumToString(current_perf_tier));
}

//+------------------------------------------------------------------+
//| Calculate rolling metrics from buffer                            |
//+------------------------------------------------------------------+
void calculate_rolling_metrics()
{
   int trades_to_use = MathMin(perf_total_trades_tracked, perf_lookback_trades);

   if(trades_to_use < perf_min_trades_required)
   {
      // Not enough trades yet, set neutral values
      rolling_sharpe = 0.0;
      rolling_mean_return = 0.0;
      rolling_std_return = 0.0;
      rolling_win_rate = 0.0;
      return;
   }

   // Calculate mean return
   double sum = 0.0;
   int wins = 0;
   int losses = 0;

   for(int i = 0; i < trades_to_use; i++)
   {
      sum += perf_trade_returns[i];
      if(perf_trade_returns[i] >= 0)
         wins++;
      else
         losses++;
   }

   rolling_mean_return = sum / trades_to_use;
   rolling_wins = wins;
   rolling_losses = losses;
   rolling_win_rate = (double)wins / trades_to_use * 100.0;

   // Calculate standard deviation
   double sum_sq_diff = 0.0;
   for(int i = 0; i < trades_to_use; i++)
   {
      double diff = perf_trade_returns[i] - rolling_mean_return;
      sum_sq_diff += diff * diff;
   }

   rolling_std_return = MathSqrt(sum_sq_diff / trades_to_use);

   // Calculate Sharpe ratio (annualized assumption not needed for comparison)
   // Using simple Sharpe = mean / std
   if(rolling_std_return > 0.0001) // Avoid division by zero
      rolling_sharpe = rolling_mean_return / rolling_std_return;
   else
      rolling_sharpe = (rolling_mean_return > 0) ? 10.0 : -10.0; // Extreme value if no variance

   // Track min/max for instrumentation
   if(rolling_sharpe < perf_min_sharpe_observed)
      perf_min_sharpe_observed = rolling_sharpe;
   if(rolling_sharpe > perf_max_sharpe_observed)
      perf_max_sharpe_observed = rolling_sharpe;
}

//+------------------------------------------------------------------+
//| Update performance tier based on rolling metrics                 |
//+------------------------------------------------------------------+
void update_performance_tier()
{
   ENUM_PERF_TIER previous_tier = current_perf_tier;

   // Check consecutive loss cooldown first
   if(perf_consecutive_loss_cooldown_bars > 0)
   {
      perf_consecutive_loss_cooldown_bars--;
      if(perf_consecutive_loss_cooldown_bars > 0)
      {
         current_perf_tier = PERF_TIER_BLOCKED;
         return; // Still in cooldown
      }
      else
      {
         Print("✅ PERF GATE: Cooldown period ended. Resuming trading.");
         perf_consecutive_losses = 0; // Reset after cooldown
      }
   }

   // Check consecutive loss limit first (highest priority block)
   if(perf_consecutive_losses >= perf_consecutive_loss_limit)
   {
      current_perf_tier = PERF_TIER_BLOCKED;
      perf_consecutive_loss_cooldown_bars = perf_consecutive_loss_cooldown;
      if(previous_tier != current_perf_tier)
      {
         Print("🛑 PERF GATE: BLOCKED due to ", perf_consecutive_losses, " consecutive losses");
         Print("   Cooldown period: ", perf_consecutive_loss_cooldown, " bars");
         perf_tier_transitions++;
      }
      return;
   }

   // Not enough trades yet - allow full trading
   if(perf_total_trades_tracked < perf_min_trades_required)
   {
      current_perf_tier = PERF_TIER_FULL;
      return;
   }

   // Determine tier based on rolling Sharpe
   if(rolling_sharpe >= perf_sharpe_full_trade)
   {
      current_perf_tier = PERF_TIER_FULL;
   }
   else if(rolling_sharpe >= perf_sharpe_reduced)
   {
      current_perf_tier = PERF_TIER_REDUCED;
   }
   else if(rolling_sharpe < perf_sharpe_block)
   {
      current_perf_tier = PERF_TIER_BLOCKED;
   }
   else
   {
      // Between perf_sharpe_block and perf_sharpe_reduced
      current_perf_tier = PERF_TIER_REDUCED;
   }

   // Log tier transitions
   if(previous_tier != current_perf_tier)
   {
      perf_tier_transitions++;
      Print("📊 PERF GATE: Tier changed from ", EnumToString(previous_tier),
            " to ", EnumToString(current_perf_tier),
            " | Rolling Sharpe: ", DoubleToString(rolling_sharpe, 2),
            " | Win Rate: ", DoubleToString(rolling_win_rate, 1), "%");
   }
}

//+------------------------------------------------------------------+
//| Get Risk Multiplier based on Rolling Performance                 |
//| Returns: 1.0 (full), 0.5 (reduced), or 0.0 (blocked)            |
//+------------------------------------------------------------------+
double get_performance_risk_multiplier()
{
   if(!enable_performance_gate)
      return 1.0; // Disabled, return full risk

   // Not enough trades yet - allow full trading
   if(perf_total_trades_tracked < perf_min_trades_required)
      return 1.0;

   switch(current_perf_tier)
   {
      case PERF_TIER_FULL:
         perf_signals_full_trade++;
         return 1.0;

      case PERF_TIER_REDUCED:
         perf_signals_reduced++;
         return perf_reduced_risk_multiplier;

      case PERF_TIER_BLOCKED:
         perf_signals_blocked++;
         return 0.0;

      default:
         return 1.0;
   }
}

//+------------------------------------------------------------------+
//| 🕐 TIME FILTER: Check if current hour is in dangerous zone (v5)  |
//+------------------------------------------------------------------+
//| Returns: true if in dangerous time, false if safe                |
//| Updates: is_in_dangerous_time global variable                    |
//+------------------------------------------------------------------+
bool check_dangerous_time()
{
   if(!enable_time_filter)
   {
      is_in_dangerous_time = false;
      current_time_filter_multiplier = 1.0;
      return false;
   }
   
   datetime current_time = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   int current_hour = dt.hour;
   
   // Check Danger Zone 1 (Early Asian: default 03:00-06:00)
   bool in_danger_zone_1 = false;
   if(danger_hour1_start < danger_hour1_end)
   {
      // Normal range (e.g., 03:00-06:00)
      in_danger_zone_1 = (current_hour >= danger_hour1_start && current_hour < danger_hour1_end);
   }
   else
   {
      // Wrap around midnight (e.g., 22:00-02:00)
      in_danger_zone_1 = (current_hour >= danger_hour1_start || current_hour < danger_hour1_end);
   }
   
   // Check Danger Zone 2 (NY Close: default 17:00-20:00)
   bool in_danger_zone_2 = false;
   if(danger_hour2_start < danger_hour2_end)
   {
      // Normal range (e.g., 17:00-20:00)
      in_danger_zone_2 = (current_hour >= danger_hour2_start && current_hour < danger_hour2_end);
   }
   else
   {
      // Wrap around midnight
      in_danger_zone_2 = (current_hour >= danger_hour2_start || current_hour < danger_hour2_end);
   }
   
   is_in_dangerous_time = (in_danger_zone_1 || in_danger_zone_2);
   
   // Set multiplier based on mode
   if(is_in_dangerous_time)
   {
      switch(time_filter_mode)
      {
         case TIME_FILTER_BLOCK_ENTRY:
            current_time_filter_multiplier = 0.0; // Block completely
            break;
         case TIME_FILTER_REDUCE_SIZE:
            current_time_filter_multiplier = time_filter_size_mult; // Reduce size
            break;
         case TIME_FILTER_LIMIT_GRID:
            current_time_filter_multiplier = 1.0; // Normal size, but grid limited
            break;
      }
   }
   else
   {
      current_time_filter_multiplier = 1.0;
   }
   
   return is_in_dangerous_time;
}

//+------------------------------------------------------------------+
//| 🕐 Get current Deposit Load percentage                           |
//| Deposit Load = Used Margin / Balance * 100                       |
//+------------------------------------------------------------------+
double get_current_deposit_load()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return 0;
   
   // Get total margin used (for all positions on this account)
   double used_margin = AccountInfoDouble(ACCOUNT_MARGIN);
   
   return (used_margin / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| 🕐 Check if should block grid due to time filter                 |
//+------------------------------------------------------------------+
bool should_block_grid_by_time_filter()
{
   if(!enable_time_filter || !is_in_dangerous_time)
      return false;
   
   if(time_filter_mode == TIME_FILTER_LIMIT_GRID)
   {
      double current_load = get_current_deposit_load();
      if(current_load >= time_filter_max_grid_load)
      {
         // Grid load exceeds limit during dangerous time
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 🚨 GRID EXPANSION CONTROL: Check if grid expansion allowed (v6) |
//+------------------------------------------------------------------+
//| Returns: true if grid expansion is allowed, false if blocked     |
//|                                                                  |
//| This function prevents the critical bug where grid expands       |
//| even when TIME FILTER blocks new entries.                       |
//+------------------------------------------------------------------+
bool should_allow_grid_expansion()
{
   if(!enable_grid_expansion_filter)
      return true; // Filter disabled, allow expansion
   
   double current_load = get_current_deposit_load();
   datetime current_time = TimeCurrent();

   // Check 0: Exposure cap (Anti-Overfit) - only affects GRID EXPANSION
   if(enable_grid_exposure_cap)
   {
      // 0a) Block expansion if deposit load already high
      if(current_load >= grid_exposure_max_dl_for_expansion)
      {
         grid_exposure_cap_blocked_count++;
         static datetime last_exposure_dl_log = 0;
         if(current_time - last_exposure_dl_log > 1800)
         {
            Print("🧱 GRID EXPOSURE CAP: Block expansion (DL ", DoubleToString(current_load, 2),
                  "% >= ", DoubleToString(grid_exposure_max_dl_for_expansion, 2), "%)");
            last_exposure_dl_log = current_time;
         }
         return false;
      }

      // 0b) Block expansion if too many positions overall
      int total_positions = PositionsTotal();
      if(total_positions >= grid_exposure_max_positions_total)
      {
         grid_exposure_cap_blocked_count++;
         static datetime last_exposure_total_log = 0;
         if(current_time - last_exposure_total_log > 1800)
         {
            Print("🧱 GRID EXPOSURE CAP: Block expansion (PositionsTotal=", total_positions,
                  " >= ", grid_exposure_max_positions_total, ")");
            last_exposure_total_log = current_time;
         }
         return false;
      }

      // 0c) Block expansion if too many positions on same side for this symbol
      int side_count = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

         long pos_type = PositionGetInteger(POSITION_TYPE);
         if((current_grid_direction == ORDER_TYPE_BUY && pos_type == POSITION_TYPE_BUY) ||
            (current_grid_direction == ORDER_TYPE_SELL && pos_type == POSITION_TYPE_SELL))
            side_count++;
      }
      if(side_count >= grid_exposure_max_positions_side)
      {
         grid_exposure_cap_blocked_count++;
         static datetime last_exposure_side_log = 0;
         if(current_time - last_exposure_side_log > 1800)
         {
            Print("🧱 GRID EXPOSURE CAP: Block expansion (", (current_grid_direction==ORDER_TYPE_BUY?"BUY":"SELL"),
                  " positions=", side_count, " >= ", grid_exposure_max_positions_side, ")");
            last_exposure_side_log = current_time;
         }
         return false;
      }
   }
   
   // Check 1: Block in dangerous time zone
   if(grid_expansion_block_in_danger && is_in_dangerous_time)
   {
      grid_expansion_blocked_count++;
      
      // Log occasionally
      static datetime last_log_time = 0;
      if(current_time - last_log_time > 3600) // Log once per hour max
      {
         MqlDateTime dt;
         TimeToStruct(TimeGMT(), dt);
         Print("🚨 GRID EXPANSION BLOCKED: In danger zone (", dt.hour, ":00 UTC). Current DL: ", 
               DoubleToString(current_load, 2), "%");
         last_log_time = current_time;
      }
      return false; // Block expansion in danger zone
   }
   
   // Check 2: Block if DL exceeds threshold
   if(current_load >= grid_expansion_max_dl)
   {
      grid_expansion_blocked_count++;
      
      static datetime last_dl_block_log = 0;
      if(current_time - last_dl_block_log > 1800) // Log once per 30min
      {
         Print("🚨 GRID EXPANSION BLOCKED: DL ", DoubleToString(current_load, 2), 
               "% exceeds threshold ", DoubleToString(grid_expansion_max_dl, 2), "%");
         last_dl_block_log = current_time;
      }
      return false; // Block if DL too high
   }
   
   // Check 3: Emergency spike detection
   if(grid_expansion_close_on_spike && last_deposit_load > 0)
   {
      double load_change = current_load - last_deposit_load;
      
      // Check if DL spiked suddenly (within reasonable time window)
      if(current_time - last_dl_check_time < 3600) // Within 1 hour
      {
         if(load_change >= grid_expansion_spike_threshold)
         {
            grid_expansion_spike_detected++;
            Print("🚨 EMERGENCY: DL spiked from ", DoubleToString(last_deposit_load, 2), 
                  "% to ", DoubleToString(current_load, 2), "% (+", 
                  DoubleToString(load_change, 2), "%)! Closing all positions!");
            
            // Emergency close all positions
            close_all_positions();
            return false;
         }
      }
   }
   
   // Update tracking variables
   last_deposit_load = current_load;
   last_dl_check_time = current_time;
   
   return true; // Allow expansion
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session                  |
//+------------------------------------------------------------------+
bool is_within_trading_session()
{
   if(trading_session == SESSION_DISABLED)
      return true; // Trading 24/7

   datetime current_time = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);

   int current_hour = dt.hour;
   int current_minute = dt.min;
   int current_time_minutes = current_hour * 60 + current_minute;
   
   // Calculate rollover close time (22:00 GMT - buffer)
   int rollover_close_minutes = 22 * 60 - swap_safe_close_minutes;

   switch(trading_session)
   {
      
      case SESSION_FULL_DAY:
         // Full Day: 00:00-23:59 GMT BUT close before rollover
         if(current_time_minutes >= 0 && current_time_minutes < 24 * 60)
         {
            // Override: Force session end if near rollover
            if(current_time_minutes >= rollover_close_minutes)
               return false;
            return true;
         }
         return false;

      default:
         return true;
   }
}

//+------------------------------------------------------------------+
//| Get session end time in minutes from midnight                    |
//+------------------------------------------------------------------+
int get_session_end_minutes()
{
   switch(trading_session)
   {
      
         
      case SESSION_FULL_DAY:
         return 20 * 60 + 59; // 23:59 GMT
         
      default:
         return 0;
   }
}

//+------------------------------------------------------------------+
//| Get session start time in minutes from midnight                  |
//+------------------------------------------------------------------+
int get_session_start_minutes()
{
   switch(trading_session)
   {
         
      case SESSION_FULL_DAY:
         return 0; // 00:00 GMT
         
      default:
         return 0;
   }
}

//+------------------------------------------------------------------+
//| Check if we should stop trading (N candles before session end)  |
//+------------------------------------------------------------------+
bool should_stop_trading_before_session_end()
{
   if(trading_session == SESSION_DISABLED)
      return false;
   
   if(!is_within_trading_session())
      return true; // Already outside session
   
   // Get current time
   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   
   int current_hour = dt.hour;
   int current_minute = dt.min;
   int current_time_minutes = current_hour * 60 + current_minute;
   
   // Get session start and end times
   int session_start_minutes = get_session_start_minutes();
   int session_end_minutes = get_session_end_minutes();
   
   // Calculate minutes until session end
   int minutes_until_end = 0;
   
   if(session_end_minutes > session_start_minutes)
   {
      // Normal case: session starts and ends on same day
      minutes_until_end = session_end_minutes - current_time_minutes;
   }
   else
   {
      // Session spans midnight (end < start means it wraps around)
      if(current_time_minutes >= session_start_minutes)
      {
         // We're after start time, session ends tomorrow
         minutes_until_end = (24 * 60 - current_time_minutes) + session_end_minutes;
      }
      else
      {
         // We're before start time, session ends today
         minutes_until_end = session_end_minutes - current_time_minutes;
      }
   }
   
   // Get current timeframe period in minutes
   ENUM_TIMEFRAMES tf = Period();
   int period_minutes = PeriodSeconds(tf) / 60;
   
   if(period_minutes <= 0)
      period_minutes = 1; // Safety check
   
   // Calculate candles until session end
   int candles_until_end = (int)(minutes_until_end / period_minutes);
   
   // Stop trading if we're within N candles of session end
   return (candles_until_end <= candles_before_session_end);
}

//+------------------------------------------------------------------+
//| Check if current day is valid for trading                        |
//+------------------------------------------------------------------+
bool is_valid_trading_day()
{
   if(trading_days == TRADING_DAYS_ALL_WEEK)
      return true; // Trading all week
   
   // Get current day of week (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   
   int day_of_week = dt.day_of_week;
   
   return true; // Default: allow trading
}

//+------------------------------------------------------------------+
//| Check trading session and manage positions                       |
//+------------------------------------------------------------------+
void check_trading_session()
{
   if(trading_session == SESSION_DISABLED)
   {
      session_positions_closed = false;
      return; // No session control
   }

   datetime current_time = TimeGMT();
   bool is_in_session = is_within_trading_session();

   // Special handling for SESSION_FULL_DAY: Close positions 2 candles before session end
   if(trading_session == SESSION_FULL_DAY && is_in_session && close_positions_on_session_end)
   {
      MqlDateTime dt;
      TimeToStruct(current_time, dt);
      int current_hour = dt.hour;
      int current_minute = dt.min;
      int current_time_minutes = current_hour * 60 + current_minute;
      
      // Session ends at 23:59 GMT
      int session_end_minutes = 20 * 60 + 59;
      int minutes_until_end = session_end_minutes - current_time_minutes;
      
      // Only proceed if we haven't passed session end time
      if(minutes_until_end >= 0)
      {
         // Get current timeframe period in minutes
         ENUM_TIMEFRAMES tf = Period();
         int period_minutes = PeriodSeconds(tf) / 60;
         
         if(period_minutes <= 0)
            period_minutes = 1; // Safety check
         
         // Calculate candles until session end
         int candles_until_end = (int)(minutes_until_end / period_minutes);
         
         // Close all positions if we're within 2 candles of session end
         if(candles_until_end <= 4 && !session_positions_closed && PositionsTotal() > 0)
         {
            Print("=== SESSION_FULL_DAY: Closing all positions (", candles_until_end, " candles before session end) ===");
            close_all_positions();
            session_positions_closed = true;
         }
      }
   }
   
   // Check if session just ended (check every tick but only close once)
   if(!is_in_session && !session_positions_closed && close_positions_on_session_end)
   {
      // Check if we have any open positions before closing
      if(PositionsTotal() > 0)
      {
         Print("=== TRADING SESSION ENDED - Closing all positions ===");
         close_all_positions();
      }
      session_positions_closed = true;
   }
   
   // If we entered a new session, reset the flag
   if(is_in_session && session_positions_closed)
   {
      Print("=== NEW TRADING SESSION STARTED ===");
      session_positions_closed = false;
   }
   
   last_session_check_time = current_time;
}

//+------------------------------------------------------------------+
//| Close All Open Positions                                         |
//+------------------------------------------------------------------+
void close_all_positions()
{
   int closed_count = 0;
   
   // Close all managed positions
   for(int i = ArraySize(managed_positions) - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(managed_positions[i].ticket))
      {
         if(trade.PositionClose(managed_positions[i].ticket))
         {
            closed_count++;
            Print("Closed position: Ticket ", managed_positions[i].ticket);
         }
         else
         {
            Print("Failed to close position: Ticket ", managed_positions[i].ticket, 
                  " | Error: ", trade.ResultRetcodeDescription());
         }
      }
   }
   
   // Close all grid positions
   for(int i = ArraySize(grid_positions) - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(grid_positions[i].ticket))
      {
         if(trade.PositionClose(grid_positions[i].ticket))
         {
            closed_count++;
            Print("Closed grid position: Ticket ", grid_positions[i].ticket);
         }
         else
         {
            Print("Failed to close grid position: Ticket ", grid_positions[i].ticket,
                  " | Error: ", trade.ResultRetcodeDescription());
         }
      }
   }
   
   // Also close any other positions that might exist (not in our arrays)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            if(trade.PositionClose(ticket))
            {
               closed_count++;
               Print("Closed additional position: Ticket ", ticket);
            }
         }
      }
   }
   
   Print("Total positions closed: ", closed_count);
   
   // Reset grid trading state
   if(grid_trading_enabled)
   {
      grid_active = false;
      current_grid_count = 0;
      Print("Grid trading stopped due to daily drawdown limit");
   }
}

//+------------------------------------------------------------------+
//| Initialize single strategy                                       |
//+------------------------------------------------------------------+
bool initialize_single_strategy(ENUM_SINGLE_STRATEGY strategy)
{
   switch(strategy)
   {
      case SINGLE_ICHIMOKU:
         return initialize_lead_strategy(LEAD_ICHIMOKU);
      
   }
   return false;
}

//+------------------------------------------------------------------+
//| Initialize lead strategy                                         |
//+------------------------------------------------------------------+
bool initialize_lead_strategy(ENUM_LEAD_STRATEGY strategy)
{
   switch(strategy)
   {
      
      case LEAD_ICHIMOKU:
         // Ichimoku Cloud will be calculated manually
         Print("Ichimoku Cloud Strategy initialized - Tenkan-sen:", ichimoku_tenkan_sen_period,
               " Kijun-sen:", validated_kijun_period, " Senkou Span B:", ichimoku_senkou_span_b_period);
         break;
         
      
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check and log swap when swap > 0                                 |
//+------------------------------------------------------------------+
void check_and_log_swap()
{
   // Loop through all open positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            double swap = PositionGetDouble(POSITION_SWAP);
            
            // Check if swap is positive
            if(swap > 0)
            {
               datetime time_current = TimeCurrent();
               datetime time_gmt = TimeGMT();
               
               Print("=== POSITIVE SWAP DETECTED ===");
               Print("Ticket: ", ticket);
               Print("Swap: ", NormalizeDouble(swap, 2));
               Print("TimeCurrent: ", TimeToString(time_current, TIME_DATE|TIME_SECONDS), " (", time_current, ")");
               Print("TimeGMT: ", TimeToString(time_gmt, TIME_DATE|TIME_SECONDS), " (", time_gmt, ")");
               Print("=============================");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Daily Swap Avoidance - Close positions before 22:00 GMT rollover |
//+------------------------------------------------------------------+
void check_daily_swap_avoidance()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // Calculate current GMT time in minutes since midnight
   int current_minutes = dt.hour * 60 + dt.min;

   // Rollover at 22:00 GMT = 1320 minutes
   int rollover_minutes = 22 * 60;

   // Close time = rollover - buffer
   int close_time_minutes = rollover_minutes - swap_safe_close_minutes;

   // FRIDAY SPECIAL: Close MUCH earlier to avoid weekend market closure
   // Friday = 5 in MQL5 (Sunday=0, Monday=1, ..., Friday=5)
   if(dt.day_of_week == 5)
   {
      // On Friday, close at 20:30 GMT to ensure positions close before weekend
      close_time_minutes = 20 * 60 + 30;  // 20:30 GMT
   }

   // Check if we're at or past close time AND have open positions
   if(current_minutes >= close_time_minutes && current_minutes < rollover_minutes)
   {
      if(PositionsTotal() > 0 && !swap_avoidance_active)
      {
         if(dt.day_of_week == 5)
         {
            Print("=== FRIDAY SWAP AVOIDANCE: Closing all positions (WEEKEND) ===");
         }
         else
         {
            Print("=== SWAP AVOIDANCE: Closing all positions ===");
         }
         Print("Current time: ", dt.hour, ":", StringFormat("%02d", dt.min), " GMT");
         Print("Day of week: ", dt.day_of_week, " (5=Friday)");
         Print("Rollover in ", rollover_minutes - current_minutes, " minutes");

         close_all_positions();
         swap_avoidance_active = true;
      }
   }

   // Reset flag after rollover (after 22:05 GMT or before 01:00 GMT)
   if(current_minutes >= rollover_minutes + 5 || current_minutes < 60)
   {
      if(swap_avoidance_active)
      {
         swap_avoidance_active = false;
         Print("=== SWAP AVOIDANCE: Trading window reopened after rollover ===");
      }
   }
}

//+------------------------------------------------------------------+
//| Check if Tuesday near rollover (avoid Wednesday 3x swap)        |
//| OR Friday near rollover (avoid weekend swap)                    |
//+------------------------------------------------------------------+
bool is_tuesday_near_rollover()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   int current_minutes = dt.hour * 60 + dt.min;

   // FRIDAY = 5: Stop trading earlier to avoid weekend swap
   // Friday market closes early, need to stop opening positions by 19:00 GMT
   if(dt.day_of_week == 5)
   {
      int friday_stop_minutes = 19 * 60;  // 19:00 GMT Friday
      if(current_minutes >= friday_stop_minutes)
      {
         return true;
      }
   }

   // TUESDAY = 2: Stop trading to avoid Wednesday 3x swap
   if(dt.day_of_week == 2)
   {
      int tuesday_stop_minutes = 21 * 60;  // 21:00 GMT Tuesday
      // Stop opening new positions from 21:00 GMT Tuesday
      // This ensures positions don't carry into Wednesday rollover (3x swap)
      if(current_minutes >= tuesday_stop_minutes)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Detect new bar so entries run once per candle in all modelling modes
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool is_new_bar = (current_bar_time != last_processed_bar_time);
   if(is_new_bar)
      last_processed_bar_time = current_bar_time;

   // Daily swap avoidance check (MUST run before trading logic)
   check_daily_swap_avoidance();

   // Check trading session
   check_trading_session();

   // Check daily drawdown limit
   check_daily_drawdown();
   
   // Check total max drawdown protection (block new entries, close losers)
   check_total_max_dd();
   
   // Update equity peak for trailing stop (every tick)
   if(enable_equity_curve_protection)
   {
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(current_equity > equity_peak_value)
      {
         equity_peak_value = current_equity;
         double initial_equity = AccountInfoDouble(ACCOUNT_BALANCE);
         equity_peak_percent = ((current_equity - initial_equity) / initial_equity) * 100.0;
         
         // Activate trailing if profit >= start threshold
         if(equity_peak_percent >= equity_trailing_start && !equity_trailing_active)
         {
            equity_trailing_active = true;
            Print("📈 EQUITY CURVE: Trailing stop activated at ", DoubleToString(equity_peak_percent, 2), "% profit");
         }
      }
   }
   
   // 🕐 [v5] Check dangerous time filter
   check_dangerous_time();
   
   // 🕐 [v5] Emergency close if entering danger zone with high load
   if(time_filter_close_on_danger && is_in_dangerous_time)
   {
      double current_load = get_current_deposit_load();
      if(current_load >= time_filter_max_grid_load * 2)
      {
         // Emergency: Close all positions when load is very high in danger zone
         Print("⚠️ TIME FILTER EMERGENCY: Closing all positions! Load=", 
               DoubleToString(current_load, 2), "% in dangerous time zone");
         close_all_positions();
      }
   }
   
   // Update managed positions array
   update_managed_positions();
   
   // Update grid positions array
   if(grid_trading_enabled)
   {
      update_grid_positions();
   }
   
   // Check and log swap when swap > 0
   check_and_log_swap();
   
   // Update trailing stops for existing positions
   if(atr_trailing_stop_enabled)
   {
      update_trailing_stops();
      if(grid_trading_enabled)
         update_grid_trailing_stops();
   }
   
   // Check if we can trade (drawdown limit not exceeded AND within trading session AND not too close to session end AND valid trading day)
   bool can_trade = !daily_drawdown_exceeded && !total_dd_exceeded;
   
   if(trading_session != SESSION_DISABLED)
   {
      // Check if we're within trading session
      if(!is_within_trading_session())
      {
         can_trade = false; // Outside trading session
      }
      // Check if we should stop trading before session end
      else if(should_stop_trading_before_session_end())
      {
         can_trade = false; // Too close to session end
      }
   }
   
   // Check if current day is valid for trading
   if(!is_valid_trading_day())
   {
      can_trade = false; // Not a valid trading day
   }
   
   // 🕐 [v5] Apply time filter - block new entries in dangerous hours
   if(can_trade && is_in_dangerous_time && time_filter_mode == TIME_FILTER_BLOCK_ENTRY)
   {
      can_trade = false; // Block new entries during dangerous hours
      time_filter_blocked_count++;
      
      // Log occasionally (not every tick)
      static datetime last_time_filter_log = 0;
      if(TimeCurrent() - last_time_filter_log > 3600) // Log once per hour max
      {
         MqlDateTime dt;
         TimeToStruct(TimeGMT(), dt);
         Print("🕐 TIME FILTER: Blocking new entries during dangerous hour (", dt.hour, ":00 UTC). Total blocked: ", time_filter_blocked_count);
         last_time_filter_log = TimeCurrent();
      }
   }
   
   // Check for new trading signals (only if allowed and on a new bar)
   if(can_trade && is_new_bar)
   {
      check_trading_signals();
      
      // Check for grid level triggers (with time filter check)
      if(grid_trading_enabled && grid_active)
      {
         // 🕐 [v5] Check if grid should be blocked by time filter
         if(!should_block_grid_by_time_filter())
         {
            check_grid_levels();
         }
         else
         {
            // Grid blocked due to time filter + high load
            static datetime last_grid_block_log = 0;
            if(TimeCurrent() - last_grid_block_log > 1800) // Log once per 30min
            {
               Print("🕐 TIME FILTER: Grid expansion blocked - Load ", 
                     DoubleToString(get_current_deposit_load(), 2), "% exceeds limit ",
                     DoubleToString(time_filter_max_grid_load, 2), "% during dangerous hours");
               last_grid_block_log = TimeCurrent();
            }
         }
      }
   }
   else
   {
      // Trading not allowed - no new trades
      // Existing positions will be managed (trailing stops, etc.) but no new signals
   }
}

//+------------------------------------------------------------------+
//| Update managed positions array                                   |
//+------------------------------------------------------------------+
void update_managed_positions()
{
   // Remove closed positions from managed array
   for(int i = ArraySize(managed_positions) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(managed_positions[i].ticket))
      {
         // Position closed, remove from array
         ArrayRemove(managed_positions, i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| WIN RATE BOOSTER - Price Action Filter                          |
//| Filters out candles that are too small or too large vs ATR      |
//+------------------------------------------------------------------+
bool check_price_action_quality(ENUM_SIGNAL_TYPE signal)
{
   if(!use_price_action_filter)
      return true; // Filter disabled

   // Get current candle and ATR
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) != 2)
   {
      Print("ERROR - Price Action Filter: Failed to copy rates");
      return false;
   }

   // Calculate candle range
   double candle_range = rates[1].high - rates[1].low;

   // Get ATR value
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(atr_sl_tp_handle == INVALID_HANDLE || CopyBuffer(atr_sl_tp_handle, 0, 1, 1, atr_buffer) != 1)
   {
      Print("ERROR - Price Action Filter: Failed to get ATR value");
      return false;
   }

   double atr_value = atr_buffer[0];
   if(atr_value <= 0)
   {
      Print("ERROR - Price Action Filter: Invalid ATR value");
      return false;
   }

   double candle_atr_ratio = candle_range / atr_value;

   // Check if candle is within acceptable size range
   if(candle_atr_ratio < validated_min_candle_size)
   {
      Print("DEBUG - PRICE ACTION BLOCKED: Candle too small (",
            DoubleToString(candle_atr_ratio, 2), "x ATR < ",
            DoubleToString(validated_min_candle_size, 2), "x minimum)");
      return false;
   }

   if(candle_atr_ratio > max_candle_size_atr)
   {
      Print("DEBUG - PRICE ACTION BLOCKED: Candle too large (",
            DoubleToString(candle_atr_ratio, 2), "x ATR > ",
            DoubleToString(max_candle_size_atr, 2), "x maximum) - Likely spike/gap");
      return false;
   }

   Print("DEBUG - PRICE ACTION PASSED: Candle size ",
         DoubleToString(candle_atr_ratio, 2), "x ATR is acceptable");
   return true;
}

//+------------------------------------------------------------------+
//| ROC Momentum Filter (NEW)                                       |
//+------------------------------------------------------------------+
double get_roc_risk_multiplier(ENUM_SIGNAL_TYPE signal)
{
   if(!enable_roc_filter || roc_handle == INVALID_HANDLE) return 1.0;

   double roc_buffer[];
   ArraySetAsSeries(roc_buffer, true);
   if(CopyBuffer(roc_handle, 0, 1, 1, roc_buffer) != 1) // Use closed bar [1]
   {
      Print("ERROR - ROC Filter: Failed to get ROC value");
      return 1.0; // Fail-safe
   }
   double roc_value = roc_buffer[0];

   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(atr_sl_tp_handle == INVALID_HANDLE || CopyBuffer(atr_sl_tp_handle, 0, 1, 1, atr_buffer) != 1)
   {
      Print("ERROR - ROC Filter: Failed to get ATR value");
      return 1.0; // Fail-safe
   }
   double atr_value = atr_buffer[0];
   if(atr_value <= 0) return 1.0; // Avoid division by zero

   // 1. Dead market filter
   if(MathAbs(roc_value) / atr_value < roc_min_abs_atr)
   {
      Print("🚀 ROC FILTER BLOCKED: Dead market | |ROC/ATR| ", DoubleToString(MathAbs(roc_value) / atr_value, 2), " < ", roc_min_abs_atr);
      return 0.0; // BLOCK
   }

   // 2. Counter-trend filter
   if((signal == SIGNAL_BUY && roc_value < 0) || (signal == SIGNAL_SELL && roc_value > 0))
   {
      Print("🚀 ROC FILTER REDUCED: Counter-momentum | Signal: ", EnumToString(signal), " ROC: ", DoubleToString(roc_value, 4));
      return roc_countertrend_mult; // REDUCE
   }

   return 1.0; // PASS
}

//+------------------------------------------------------------------+
//| KDJ Filter (Stochastic-based, NEW)                              |
//+------------------------------------------------------------------+
double get_kdj_risk_multiplier(ENUM_SIGNAL_TYPE signal)
{
   if(!enable_kdj_filter || kdj_handle == INVALID_HANDLE) return 1.0;

   double k_buffer[], d_buffer[];
   ArraySetAsSeries(k_buffer, true);
   ArraySetAsSeries(d_buffer, true);

   if(CopyBuffer(kdj_handle, 0, 1, 1, k_buffer) != 1 || CopyBuffer(kdj_handle, 1, 1, 1, d_buffer) != 1) // Use closed bar [1]
   {
      Print("ERROR - KDJ Filter: Failed to get Stochastic values");
      return 1.0; // Fail-safe
   }

   double k = k_buffer[0];
   double d = d_buffer[0];
   double j = 3 * k - 2 * d;

   // 1. Extreme Overbought/Oversold Filter
   if(signal == SIGNAL_BUY && j >= kdj_overbought)
   {
      Print("🧭 KDJ FILTER: BUY in Overbought zone | J=", DoubleToString(j, 1), " >= ", kdj_overbought);
      if(kdj_reduce_in_extreme)
         return kdj_extreme_reduce_mult; // REDUCE
      return 0.0; // BLOCK
   }

   if(signal == SIGNAL_SELL && j <= kdj_oversold)
   {
      Print("🧭 KDJ FILTER: SELL in Oversold zone | J=", DoubleToString(j, 1), " <= ", kdj_oversold);
      if(kdj_reduce_in_extreme)
         return kdj_extreme_reduce_mult; // REDUCE
      return 0.0; // BLOCK
   }

   return 1.0; // PASS
}

//+------------------------------------------------------------------+
//| RSI Momentum Filter - Check if RSI confirms the signal          |
//+------------------------------------------------------------------+
bool check_rsi_filter(ENUM_SIGNAL_TYPE signal)
{
   if(!enable_rsi_filter)
      return true; // Filter disabled

   // Check if RSI handle is valid
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("ERROR - RSI Filter: RSI handle is invalid");
      return false;
   }

   // Get RSI value
   double rsi_buffer[];
   ArraySetAsSeries(rsi_buffer, true);
   if(CopyBuffer(rsi_handle, 0, 0, 2, rsi_buffer) != 2)
   {
      Print("ERROR - RSI Filter: Failed to get RSI values");
      return false;
   }

   double rsi_current = rsi_buffer[0];
   double rsi_previous = rsi_buffer[1];

   // Validate RSI value
   if(rsi_current < 0 || rsi_current > 100)
   {
      Print("ERROR - RSI Filter: Invalid RSI value (", rsi_current, ")");
      return false;
   }

   // Check signal based on RSI levels
   if(signal == SIGNAL_BUY)
   {
      // Block BUY if RSI is overbought
      if(rsi_current >= rsi_overbought)
      {
         rsi_signals_blocked_overbought++;
         Print("DEBUG - RSI FILTER BLOCKED: BUY signal rejected - RSI overbought (",
               DoubleToString(rsi_current, 2), " >= ", rsi_overbought, ")");
         return false;
      }

      // Optional: Prefer trades in neutral zone (40-60)
      // This helps avoid entering at extremes
      if(rsi_current < rsi_neutral_zone_low)
      {
         // RSI is oversold - might be good for BUY, but check if it's recovering
         if(rsi_current > rsi_previous)
         {
            // RSI is rising from oversold - good momentum for BUY
            rsi_signals_passed++;
            Print("DEBUG - RSI FILTER PASSED: BUY signal - RSI recovering from oversold (",
                  DoubleToString(rsi_current, 2), " rising from ", DoubleToString(rsi_previous, 2), ")");
            return true;
         }
         else
         {
            // RSI still falling - wait for recovery
            rsi_signals_blocked_momentum++;
            Print("DEBUG - RSI FILTER BLOCKED: BUY signal - RSI still falling (",
                  DoubleToString(rsi_current, 2), " < ", DoubleToString(rsi_previous, 2), ")");
            return false;
         }
      }

      // RSI in neutral or slightly overbought zone - good for BUY
      rsi_signals_passed++;
      Print("DEBUG - RSI FILTER PASSED: BUY signal - RSI in acceptable zone (",
            DoubleToString(rsi_current, 2), ")");
      return true;
   }
   else if(signal == SIGNAL_SELL)
   {
      // Block SELL if RSI is oversold
      if(rsi_current <= rsi_oversold)
      {
         rsi_signals_blocked_oversold++;
         Print("DEBUG - RSI FILTER BLOCKED: SELL signal rejected - RSI oversold (",
               DoubleToString(rsi_current, 2), " <= ", rsi_oversold, ")");
         return false;
      }

      // Optional: Prefer trades in neutral zone (40-60)
      if(rsi_current > rsi_neutral_zone_high)
      {
         // RSI is overbought - might be good for SELL, but check if it's declining
         if(rsi_current < rsi_previous)
         {
            // RSI is falling from overbought - good momentum for SELL
            rsi_signals_passed++;
            Print("DEBUG - RSI FILTER PASSED: SELL signal - RSI declining from overbought (",
                  DoubleToString(rsi_current, 2), " falling from ", DoubleToString(rsi_previous, 2), ")");
            return true;
         }
         else
         {
            // RSI still rising - wait for decline
            rsi_signals_blocked_momentum++;
            Print("DEBUG - RSI FILTER BLOCKED: SELL signal - RSI still rising (",
                  DoubleToString(rsi_current, 2), " > ", DoubleToString(rsi_previous, 2), ")");
            return false;
         }
      }

      // RSI in neutral or slightly oversold zone - good for SELL
      rsi_signals_passed++;
      Print("DEBUG - RSI FILTER PASSED: SELL signal - RSI in acceptable zone (",
            DoubleToString(rsi_current, 2), ")");
      return true;
   }

   return true; // No signal or unknown signal type
}

//+------------------------------------------------------------------+
//| Enhanced Risk Management Functions                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Equity Curve Protection - Trailing Stop for Equity         |
//+------------------------------------------------------------------+
bool check_equity_curve_protection()
{
   if(!enable_equity_curve_protection)
      return true; // Protection disabled

   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double initial_equity = AccountInfoDouble(ACCOUNT_BALANCE); // Use balance as reference
   
   // Update peak equity
   if(current_equity > equity_peak_value)
   {
      equity_peak_value = current_equity;
      equity_peak_percent = ((current_equity - initial_equity) / initial_equity) * 100.0;
      
      // Activate trailing if profit >= start threshold
      if(equity_peak_percent >= equity_trailing_start && !equity_trailing_active)
      {
         equity_trailing_active = true;
         Print("📈 EQUITY CURVE: Trailing stop activated at ", DoubleToString(equity_peak_percent, 2), "% profit");
      }
   }
   
   // Check trailing stop if active
   if(equity_trailing_active)
   {
      // RESET MECHANISM: If equity recovers above previous peak, reset protection
      if(current_equity > equity_peak_value)
      {
         // Equity recovered - reset trailing stop
         equity_peak_value = current_equity;
         equity_peak_percent = ((current_equity - initial_equity) / initial_equity) * 100.0;
         Print("✅ EQUITY CURVE: Recovery detected - Reset trailing stop. New peak: ", 
               DoubleToString(equity_peak_percent, 2), "%");
         return true; // Allow trading
      }
      
      double drawdown_from_peak = ((equity_peak_value - current_equity) / equity_peak_value) * 100.0;
      
      if(drawdown_from_peak >= equity_trailing_stop)
      {
         Print("🛑 EQUITY CURVE PROTECTION: Drawdown from peak ", DoubleToString(drawdown_from_peak, 2), 
               "% >= ", equity_trailing_stop, "% - Trading BLOCKED");
         Print("   Peak was: ", DoubleToString(equity_peak_value, 2), " | Current: ", DoubleToString(current_equity, 2));
         return false; // Block trading
      }
      
      // Update trailing stop level (step-based)
      static double last_trailing_level = 0.0;
      double current_profit = equity_peak_percent;
      double new_trailing_level = MathFloor(current_profit / equity_trailing_step) * equity_trailing_step;
      
      if(new_trailing_level > last_trailing_level)
      {
         last_trailing_level = new_trailing_level;
         Print("📊 EQUITY CURVE: Trailing stop updated to ", DoubleToString(new_trailing_level, 2), "%");
      }
   }
   
   return true; // Allow trading
}

//+------------------------------------------------------------------+
//| Get Volatility-Based Position Size Multiplier                    |
//+------------------------------------------------------------------+
double get_volatility_position_multiplier()
{
   if(!enable_volatility_position_sizing)
      return 1.0; // No adjustment
   
   if(atr_sl_tp_handle == INVALID_HANDLE)
      return 1.0;
   
   // Get current ATR and average ATR
   double atr_current[], atr_values[];
   ArraySetAsSeries(atr_current, true);
   ArraySetAsSeries(atr_values, true);
   
   if(CopyBuffer(atr_sl_tp_handle, 0, 0, 1, atr_current) != 1)
      return 1.0;
   
   if(CopyBuffer(atr_sl_tp_handle, 0, 0, 20, atr_values) != 20)
      return 1.0;
   
   // Calculate average ATR
   double atr_sum = 0.0;
   for(int i = 0; i < 20; i++)
      atr_sum += atr_values[i];
   double atr_avg = atr_sum / 20.0;
   
   if(atr_avg <= 0)
      return 1.0;
   
   // Calculate volatility ratio
   double volatility_ratio = atr_current[0] / atr_avg;
   
   // Reduce position size if volatility is high
   if(volatility_ratio >= volatility_reduce_threshold)
   {
      Print("📉 VOLATILITY SIZING: High volatility detected (", DoubleToString(volatility_ratio, 2), 
            "x avg) - Reducing position size to ", DoubleToString(volatility_reduce_multiplier * 100, 0), "%");
      return volatility_reduce_multiplier;
   }
   
   return 1.0; // Normal size
}

//+------------------------------------------------------------------+
//| Get Correlation-Based Risk Multiplier                            |
//+------------------------------------------------------------------+
double get_correlation_risk_multiplier(ENUM_ORDER_TYPE order_type)
{
   if(!enable_correlation_risk_management)
      return 1.0; // No adjustment
   
   // Check if too many trades in same direction
   if(last_trade_direction == order_type)
   {
      same_direction_trade_count++;
   }
   else
   {
      // Direction changed, reset counter
      same_direction_trade_count = 1;
      last_trade_direction = order_type;
   }
   
   // Reduce risk if too many same direction trades
   if(same_direction_trade_count > max_same_direction_trades)
   {
      Print("⚠️ CORRELATION RISK: ", same_direction_trade_count, " trades in same direction - ",
            "Reducing risk to ", DoubleToString(correlation_risk_multiplier * 100, 0), "%");
      return correlation_risk_multiplier;
   }
   
   return 1.0; // Normal risk
}

//+------------------------------------------------------------------+
//| ADX SLOPE - Core Functions (Experiment 2)                        |
//+------------------------------------------------------------------+
void calculate_adx_slope()
{
   if(!enable_adx_slope_filter || mr_adx_handle == INVALID_HANDLE) return;
   double adx_values[];
   ArraySetAsSeries(adx_values, true);
   if(CopyBuffer(mr_adx_handle, 0, 0, adx_slope_lookback + 1, adx_values) != adx_slope_lookback + 1) return;
   current_adx_slope = (adx_values[0] - adx_values[adx_slope_lookback]) / adx_slope_lookback;
   if(current_adx_slope < adx_slope_min_observed) adx_slope_min_observed = current_adx_slope;
   if(current_adx_slope > adx_slope_max_observed) adx_slope_max_observed = current_adx_slope;
   if(current_adx_slope >= adx_slope_rising_threshold) current_adx_slope_state = ADX_SLOPE_RISING;
   else if(current_adx_slope <= adx_slope_falling_threshold) current_adx_slope_state = ADX_SLOPE_FALLING;
   else current_adx_slope_state = ADX_SLOPE_FLAT;
}

double get_adx_slope_risk_multiplier()
{
   if(!enable_adx_slope_filter) return 1.0;
   calculate_adx_slope();
   if(current_adx_slope_state == ADX_SLOPE_RISING) { adx_slope_signals_rising++; return 1.0; }
   if(current_adx_slope_state == ADX_SLOPE_FLAT) { adx_slope_signals_flat++; return 1.0; }
   if(current_adx_slope_state == ADX_SLOPE_FALLING)
   {
      adx_slope_signals_falling++;
      if(adx_slope_block_falling) { adx_slope_blocked_count++; Print("📉 ADX SLOPE BLOCKED | Slope=", current_adx_slope); return 0.0; }
      else return adx_slope_falling_risk_mult;
   }
   return 1.0;
}

//+------------------------------------------------------------------+
//| ATR STABILITY - Core Functions (Experiment 3)                    |
//+------------------------------------------------------------------+
void calculate_atr_stability()
{
   if(!enable_atr_stability_filter || atr_sl_tp_handle == INVALID_HANDLE) return;

   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   if(CopyBuffer(atr_sl_tp_handle, 0, 0, atr_stability_period + 1, atr_values) != atr_stability_period + 1) return;

   // Calculate ATR SMA
   double atr_sum = 0.0;
   for(int i = 1; i <= atr_stability_period; i++) atr_sum += atr_values[i];
   double atr_sma = atr_sum / atr_stability_period;
   if(atr_sma <= 0) return;

   // Calculate ATR ratio (current vs SMA)
   current_atr_ratio = atr_values[0] / atr_sma;

   // Calculate ATR volatility (StdDev / SMA)
   double sum_sq = 0.0;
   for(int i = 1; i <= atr_stability_period; i++)
   {
      double diff = atr_values[i] - atr_sma;
      sum_sq += diff * diff;
   }
   current_atr_volatility = MathSqrt(sum_sq / atr_stability_period) / atr_sma;

   // Track min/max
   if(current_atr_ratio < atr_ratio_min_observed) atr_ratio_min_observed = current_atr_ratio;
   if(current_atr_ratio > atr_ratio_max_observed) atr_ratio_max_observed = current_atr_ratio;

   // Determine state
   if(current_atr_ratio > atr_ratio_upper || current_atr_ratio < atr_ratio_lower)
      current_atr_state = ATR_EXTREME;
   else if(current_atr_volatility > atr_volatility_threshold)
      current_atr_state = ATR_VOLATILE;
   else
      current_atr_state = ATR_STABLE;
}

double get_atr_stability_risk_multiplier()
{
   if(!enable_atr_stability_filter) return 1.0;
   calculate_atr_stability();

   switch(current_atr_state)
   {
      case ATR_STABLE:
         atr_stability_signals_stable++;
         return 1.0;

      case ATR_VOLATILE:
         atr_stability_signals_volatile++;
         Print("⚡ ATR VOLATILE | Ratio:", DoubleToString(current_atr_ratio, 2),
               " Vol:", DoubleToString(current_atr_volatility, 2), " | Reduced");
         return atr_stability_reduce_mult;

      case ATR_EXTREME:
         atr_stability_signals_extreme++;
         if(atr_stability_block_extreme)
         {
            atr_stability_blocked_count++;
            Print("🚫 ATR EXTREME BLOCKED | Ratio:", DoubleToString(current_atr_ratio, 2),
                  " (range:", atr_ratio_lower, "-", atr_ratio_upper, ")");
            return 0.0;
         }
         else return atr_stability_reduce_mult;
   }
   return 1.0;
}

//+------------------------------------------------------------------+
//| BB SQUEEZE - Core Functions (Experiment 4)                       |
//+------------------------------------------------------------------+
void calculate_bb_squeeze()
{
   if(!enable_bb_squeeze_filter || bb_squeeze_handle == INVALID_HANDLE) return;

   double upper[], lower[];
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);

   if(CopyBuffer(bb_squeeze_handle, 0, 0, 2, upper) != 2) return; // Upper band
   if(CopyBuffer(bb_squeeze_handle, 2, 0, 2, lower) != 2) return; // Lower band

   double close_prices[];
   ArraySetAsSeries(close_prices, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, close_prices) != 2) return;

   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   if(CopyBuffer(atr_sl_tp_handle, 0, 0, 2, atr_values) != 2) return;

   double atr = atr_values[1];
   if(atr <= 0) return;

   double width = upper[1] - lower[1];
   current_bb_width_atr = width / atr;

   if(current_bb_width_atr < bb_width_min_observed) bb_width_min_observed = current_bb_width_atr;
   if(current_bb_width_atr > bb_width_max_observed) bb_width_max_observed = current_bb_width_atr;

   bool in_squeeze = (current_bb_width_atr < bb_squeeze_threshold_atr);

   if(in_squeeze)
      current_bb_squeeze_state = BB_SQUEEZE_ACTIVE;
   else
      current_bb_squeeze_state = BB_SQUEEZE_NONE;

   if(was_in_squeeze && !in_squeeze)
   {
      current_bb_squeeze_state = BB_SQUEEZE_BREAKOUT;
      bb_squeeze_breakouts_detected++;
   }

   was_in_squeeze = in_squeeze;
}

double get_bb_squeeze_risk_multiplier()
{
   if(!enable_bb_squeeze_filter) return 1.0;
   calculate_bb_squeeze();

   if(current_bb_squeeze_state == BB_SQUEEZE_BREAKOUT)
   {
      if(bb_squeeze_trade_breakout)
      {
         bb_squeeze_signals_allowed++;
         return 1.0;
      }
      // fallthrough: treat as normal non-squeeze if not trading breakouts
      bb_squeeze_signals_allowed++;
      return 1.0;
   }

   if(current_bb_squeeze_state == BB_SQUEEZE_ACTIVE)
   {
      if(bb_squeeze_mode == BB_SQUEEZE_BLOCK)
      {
         bb_squeeze_signals_blocked++;
         Print("🧬 BB SQUEEZE BLOCKED | Width/ATR=", DoubleToString(current_bb_width_atr, 2),
               " < ", DoubleToString(bb_squeeze_threshold_atr, 2));
         return 0.0;
      }
      else
      {
         bb_squeeze_signals_reduced++;
         Print("🧬 BB SQUEEZE REDUCE | Width/ATR=", DoubleToString(current_bb_width_atr, 2),
               " < ", DoubleToString(bb_squeeze_threshold_atr, 2),
               " | Mult=", DoubleToString(bb_squeeze_risk_mult, 2));
         return bb_squeeze_risk_mult;
      }
   }

   bb_squeeze_signals_allowed++;
   return 1.0;
}

//+------------------------------------------------------------------+
//| HTF TREND BIAS - Core Functions (Option C)                       |
//+------------------------------------------------------------------+
double get_htf_trend_bias_multiplier(ENUM_ORDER_TYPE order_type)
{
   if(!enable_htf_trend_bias || order_type == WRONG_VALUE)
      return 1.0;

   if(htf_ema_fast_handle == INVALID_HANDLE || htf_ema_slow_handle == INVALID_HANDLE || htf_atr_handle == INVALID_HANDLE)
      return 1.0;

   double ema_fast[], ema_slow[], atr[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(atr, true);

   // Use last CLOSED H1 bar (shift=1) to avoid lookahead
   if(CopyBuffer(htf_ema_fast_handle, 0, 1, 1, ema_fast) != 1) return 1.0;
   if(CopyBuffer(htf_ema_slow_handle, 0, 1, 1, ema_slow) != 1) return 1.0;
   if(CopyBuffer(htf_atr_handle, 0, 1, 1, atr) != 1) return 1.0;

   double diff = ema_fast[0] - ema_slow[0];
   double buffer = atr[0] * htf_neutral_buffer_atr;

   ENUM_HTF_BIAS new_bias = HTF_BIAS_UNKNOWN;
   if(atr[0] <= 0)
      new_bias = HTF_BIAS_UNKNOWN;
   else if(MathAbs(diff) <= buffer)
      new_bias = HTF_BIAS_NEUTRAL;
   else if(diff > 0)
      new_bias = HTF_BIAS_UP;
   else
      new_bias = HTF_BIAS_DOWN;

   if(new_bias != current_htf_bias)
   {
      Print("📐 HTF BIAS changed: ", EnumToString(current_htf_bias), " → ", EnumToString(new_bias),
            " | diff=", DoubleToString(diff, 5),
            " | buffer=", DoubleToString(buffer, 5));
      current_htf_bias = new_bias;
   }

   switch(new_bias)
   {
      case HTF_BIAS_NEUTRAL:
         htf_trades_neutral++;
         return htf_neutral_mult;

      case HTF_BIAS_UP:
         if(order_type == ORDER_TYPE_BUY) { htf_trades_aligned++; return 1.0; }
         htf_trades_counter++; return htf_countertrend_mult;

      case HTF_BIAS_DOWN:
         if(order_type == ORDER_TYPE_SELL) { htf_trades_aligned++; return 1.0; }
         htf_trades_counter++; return htf_countertrend_mult;

      default:
         return 1.0;
   }
}

//+------------------------------------------------------------------+
//| MICROSTRUCTURE GUARD - Core Functions (Option D)                 |
//+------------------------------------------------------------------+
double get_microstructure_guard_multiplier()
{
   if(!enable_microstructure_guard)
      return 1.0;

   long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return 1.0;

   if(spread_points <= (long)max_spread_points)
      return 1.0;

   static datetime last_log = 0;
   if(TimeCurrent() - last_log > 300)
   {
      Print("🛡️ SPREAD GUARD: spread=", spread_points, " points > ", (long)max_spread_points,
            " | mode=", EnumToString(spread_guard_mode));
      last_log = TimeCurrent();
   }

   return (spread_guard_mode == SPREAD_GUARD_REDUCE) ? spread_reduce_mult : 0.0;
}

//+------------------------------------------------------------------+
//| ADAPTIVE FILTER SYSTEM - Core Functions                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate ADX Reliability Score                                   |
//| Measures if ADX signals match actual price behavior               |
//+------------------------------------------------------------------+
double calculate_adx_reliability()
{
   if(!enable_adaptive_filters) return 1.0;
   if(mr_adx_handle == INVALID_HANDLE) return 1.0;

   double adx_values[];
   double high_prices[], low_prices[], open_prices[], close_prices[];
   ArraySetAsSeries(adx_values, true);
   ArraySetAsSeries(high_prices, true);
   ArraySetAsSeries(low_prices, true);
   ArraySetAsSeries(open_prices, true);
   ArraySetAsSeries(close_prices, true);

   if(CopyBuffer(mr_adx_handle, 0, 0, adaptive_lookback_bars, adx_values) != adaptive_lookback_bars)
      return 1.0;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, adaptive_lookback_bars, high_prices) != adaptive_lookback_bars)
      return 1.0;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, adaptive_lookback_bars, low_prices) != adaptive_lookback_bars)
      return 1.0;
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, adaptive_lookback_bars, open_prices) != adaptive_lookback_bars)
      return 1.0;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, adaptive_lookback_bars, close_prices) != adaptive_lookback_bars)
      return 1.0;

   int adx_trending_bars = 0;
   int price_directional_bars = 0;

   for(int i = 0; i < adaptive_lookback_bars; i++)
   {
      // ADX says trending?
      if(adx_values[i] > adx_trending_threshold)
         adx_trending_bars++;

      // Price actually directional? (body > 40% of range)
      double range = high_prices[i] - low_prices[i];
      double body = MathAbs(close_prices[i] - open_prices[i]);
      if(range > 0 && body > 0.4 * range)
         price_directional_bars++;
   }

   double adx_trending_rate = (double)adx_trending_bars / adaptive_lookback_bars;
   double price_directional_rate = (double)price_directional_bars / adaptive_lookback_bars;

   double reliability = 0.6;  // Default neutral

   // ADX reliable if it matches price behavior
   if(adx_trending_rate > 0.5 && price_directional_rate < 0.3)
      reliability = 0.3;  // ADX says trending but price choppy - UNRELIABLE
   else if(adx_trending_rate > 0.5 && price_directional_rate > 0.5)
      reliability = 0.9;  // Both agree trending - RELIABLE
   else if(adx_trending_rate < 0.3 && price_directional_rate < 0.3)
      reliability = 0.8;  // Both agree ranging - RELIABLE
   else if(adx_trending_rate < 0.3 && price_directional_rate > 0.5)
      reliability = 0.5;  // ADX says ranging but price moving - MIXED

   // Update stats
   if(reliability < adx_reliability_min) adx_reliability_min = reliability;
   if(reliability > adx_reliability_max) adx_reliability_max = reliability;
   adx_reliability_sum += reliability;
   adx_reliability_samples++;

   return reliability;
}

//+------------------------------------------------------------------+
//| Detect Current Market Regime and Update Filter Configuration     |
//+------------------------------------------------------------------+
ENUM_FILTER_REGIME detect_filter_regime()
{
   if(!enable_adaptive_filters)
      return REGIME_FULL;

   // Calculate metrics
   adx_reliability_score = calculate_adx_reliability();
   calculate_atr_stability();  // Updates current_atr_volatility

   bool adx_reliable = (adx_reliability_score >= adx_reliability_high);
   bool adx_unreliable = (adx_reliability_score < adx_reliability_low);
   bool atr_volatile = (current_atr_volatility > adaptive_atr_vol_threshold);

   ENUM_FILTER_REGIME new_regime;

   // Decision matrix based on observed data
   if(adx_reliable && !atr_volatile)
      new_regime = REGIME_FULL;           // MR + Exp 1+2+3
   else if(adx_reliable && atr_volatile)
      new_regime = REGIME_NO_EXP2;        // MR + Exp 1+3 (no ADX Slope when volatile)
   else if(adx_unreliable && !atr_volatile)
      new_regime = REGIME_EXP1_ONLY;      // Exp 1 only (ADX unreliable)
   else if(adx_unreliable && atr_volatile)
      new_regime = REGIME_EXP3_ONLY;      // Exp 3 only (like OOS mini3)
   else
      new_regime = REGIME_EXP1_EXP3;      // Safe default

   // Track regime changes
   if(new_regime != current_filter_regime)
   {
      regime_change_count++;
      Print("🔄 REGIME: ", EnumToString(current_filter_regime), " → ", EnumToString(new_regime),
            " | ADX Rel:", DoubleToString(adx_reliability_score, 2),
            " | ATR Vol:", DoubleToString(current_atr_volatility, 3));
   }

   // Update counters
   switch(new_regime)
   {
      case REGIME_FULL: regime_full_count++; break;
      case REGIME_NO_EXP2: regime_no_exp2_count++; break;
      case REGIME_EXP1_ONLY: regime_exp1_only_count++; break;
      case REGIME_EXP3_ONLY: regime_exp3_only_count++; break;
      case REGIME_EXP1_EXP3: regime_exp1_exp3_count++; break;
      case REGIME_NONE: regime_none_count++; break;
   }

   current_filter_regime = new_regime;
   return current_filter_regime;
}

//+------------------------------------------------------------------+
//| Get Effective Filter States Based on Current Regime              |
//+------------------------------------------------------------------+
void get_adaptive_filter_states(bool &mr_active, bool &exp1_active,
                                 bool &exp2_active, bool &exp3_active)
{
   if(!enable_adaptive_filters)
   {
      // If adaptive disabled, use original input settings
      mr_active = enable_market_regime_filter;
      exp1_active = enable_performance_gate;
      exp2_active = enable_adx_slope_filter;
      exp3_active = enable_atr_stability_filter;
      return;
   }

   ENUM_FILTER_REGIME regime = detect_filter_regime();

   switch(regime)
   {
      case REGIME_FULL:
         mr_active = enable_market_regime_filter;
         exp1_active = enable_performance_gate;
         exp2_active = enable_adx_slope_filter;
         exp3_active = enable_atr_stability_filter;
         break;

      case REGIME_NO_EXP2:
         mr_active = enable_market_regime_filter;
         exp1_active = enable_performance_gate;
         exp2_active = false;  // Disable Exp 2
         exp3_active = enable_atr_stability_filter;
         break;

      case REGIME_EXP1_ONLY:
         mr_active = false;    // Disable MR
         exp1_active = enable_performance_gate;
         exp2_active = false;  // Disable Exp 2
         exp3_active = false;  // Disable Exp 3
         break;

      case REGIME_EXP3_ONLY:
         mr_active = false;    // Disable MR (like OOS mini3)
         exp1_active = false;  // Disable Exp 1
         exp2_active = false;  // Disable Exp 2
         exp3_active = enable_atr_stability_filter;
         break;

      case REGIME_EXP1_EXP3:
         mr_active = false;    // Disable MR
         exp1_active = enable_performance_gate;
         exp2_active = false;  // Disable Exp 2
         exp3_active = enable_atr_stability_filter;
         break;

      case REGIME_NONE:
      default:
         mr_active = false;
         exp1_active = false;
         exp2_active = false;
         exp3_active = false;
         break;
   }
}

//+------------------------------------------------------------------+
//| Market Regime Filter - Check if market is trending (ADX-based)  |
//| Returns true if market is in trending regime, false if ranging  |
//+------------------------------------------------------------------+
bool is_trending_market()
{
   // ADAPTIVE FILTER SYSTEM: Check if MR Filter should be active
   bool mr_active, exp1_active, exp2_active, exp3_active;
   get_adaptive_filter_states(mr_active, exp1_active, exp2_active, exp3_active);

   // If adaptive system disabled MR Filter, allow all trades
   if(!mr_active)
   {
      Print("🤖 ADAPTIVE: MR Filter DISABLED for current regime (", EnumToString(current_filter_regime), ")");
      return true;
   }

   // If filter is disabled by user input, always return true (allow all trades)
   if(!enable_market_regime_filter)
      return true;
   
   // Check if ADX handle is valid
   if(mr_adx_handle == INVALID_HANDLE)
   {
      Print("ERROR - Market Regime Filter: ADX handle is invalid");
      return true; // Fail-safe: allow trade if filter fails
   }
   
   // Get ADX value (Main line - buffer 0)
   double adx_buffer[];
   ArraySetAsSeries(adx_buffer, true);
   if(CopyBuffer(mr_adx_handle, 0, 0, 2, adx_buffer) != 2)
   {
      Print("ERROR - Market Regime Filter: Failed to get ADX values");
      return true; // Fail-safe: allow trade if data copy fails
   }
   
   double adx_current = adx_buffer[0];
   
   // Validate ADX value
   if(adx_current < 0 || adx_current > 100)
   {
      Print("ERROR - Market Regime Filter: Invalid ADX value (", adx_current, ")");
      return true; // Fail-safe
   }
   
   // Determine market regime based on ADX value
   if(adx_current >= adx_trending_threshold)
   {
      // Strong Trend - Ichimoku works best
      Print("✅ MARKET REGIME: Strong Trend | ADX=", DoubleToString(adx_current, 1), 
            " (>= ", adx_trending_threshold, ") | Trade ALLOWED");
      signals_passed_regime++;
      return true;
   }
   else if(adx_current >= adx_weak_trend_threshold)
   {
      // Weak Trend - Trade with caution
      if(block_weak_trends)
      {
         Print("⚠️ MARKET REGIME: Weak Trend | ADX=", DoubleToString(adx_current, 1),
               " (", adx_weak_trend_threshold, "-", adx_trending_threshold, ") | Trade BLOCKED (weak trends disabled)");
         signals_blocked_weak_trend++;
         return false;
      }
      else
      {
         Print("⚠️ MARKET REGIME: Weak Trend | ADX=", DoubleToString(adx_current, 1),
               " (", adx_weak_trend_threshold, "-", adx_trending_threshold, ") | Trade ALLOWED (with caution)");
         signals_passed_regime++;
         return true;
      }
   }
   else
   {
      // Ranging Market - Ichimoku performs poorly
      Print("🔴 MARKET REGIME: Ranging Market | ADX=", DoubleToString(adx_current, 1),
            " (< ", adx_weak_trend_threshold, ") | Trade BLOCKED");
      signals_blocked_ranging++;
      return false;
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//| Route to appropriate strategy: Single or Combined strategies     |
//+------------------------------------------------------------------+
void check_trading_signals()
{
   // Only check Ichimoku Cloud signals
   check_single_strategy_signals(single_strategy);
}

//+------------------------------------------------------------------+
//| Check single strategy signals                                    |
//+------------------------------------------------------------------+
void check_single_strategy_signals(ENUM_SINGLE_STRATEGY strategy)
{
   ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;

   // Only Ichimoku Cloud strategy
   signal = get_ichimoku_signal();

   // Debug: Print Ichimoku signal
   Print("DEBUG - Ichimoku Cloud Strategy | Signal: ", EnumToString(signal));

   // If no signal from lead strategy, exit
   if(signal == SIGNAL_NONE)
   {
      Print("DEBUG - No lead signal, no trade");
      return;
   }

   // INSTRUMENTATION: Track total signals generated
   total_signals_checked++;

   // ==========================================
   // APPLY MARKET REGIME FILTER (ADX)
   // ==========================================
   // Ichimoku is a TREND-FOLLOWING strategy - requires trending market
   // Block trades in ranging/choppy markets to avoid whipsaws
   
   if(!is_trending_market())
   {
      Print("DEBUG - MARKET REGIME FILTER BLOCKED: Not in trending market");
      return;
   }
   
   // ==========================================
   // APPLY WIN RATE BOOSTER FILTERS
   // ==========================================

   // Filter 2: Price Action Quality
   if(!check_price_action_quality(signal))
   {
      Print("DEBUG - WIN RATE BOOSTER BLOCKED: Failed price action filter");
      return;
   }

   // Filter 3: RSI Momentum Confirmation
   if(!check_rsi_filter(signal))
   {
      Print("DEBUG - RSI MOMENTUM FILTER BLOCKED: RSI does not confirm signal");
      return;
   }

   // Filter 3b: MACD Confirmation (Option E - BLOCK)
   if(enable_macd_filter)
   {
      if(macd_handle == INVALID_HANDLE)
      {
         Print("DEBUG - MACD FILTER SKIPPED: MACD handle invalid");
      }
      else
      {
         double macd_main[], macd_signal_buf[];
         ArraySetAsSeries(macd_main, true);
         ArraySetAsSeries(macd_signal_buf, true);

         // Use closed bar (shift=1) to avoid lookahead
         if(CopyBuffer(macd_handle, 0, 1, 1, macd_main) != 1 || CopyBuffer(macd_handle, 1, 1, 1, macd_signal_buf) != 1)
         {
            Print("DEBUG - MACD FILTER SKIPPED: failed to read MACD buffers");
         }
         else
         {
            if(signal == SIGNAL_BUY)
            {
               if(macd_main[0] <= macd_signal_buf[0])
               {
                  macd_signals_blocked++;
                  Print("DEBUG - MACD FILTER BLOCKED: BUY rejected (main<=signal) | ",
                        DoubleToString(macd_main[0], 5), " <= ", DoubleToString(macd_signal_buf[0], 5));
                  return;
               }
            }
            else if(signal == SIGNAL_SELL)
            {
               if(macd_main[0] >= macd_signal_buf[0])
               {
                  macd_signals_blocked++;
                  Print("DEBUG - MACD FILTER BLOCKED: SELL rejected (main>=signal) | ",
                        DoubleToString(macd_main[0], 5), " >= ", DoubleToString(macd_signal_buf[0], 5));
                  return;
               }
            }
            macd_signals_passed++;
         }
      }
   }

   // Filter 4: Equity Curve Protection
   if(!check_equity_curve_protection())
   {
      Print("DEBUG - EQUITY CURVE PROTECTION BLOCKED: Drawdown from peak too large");
      return;
   }

   // ==========================================
   // ALL FILTERS PASSED - EXECUTE TRADE
   // ==========================================
   if(signal == SIGNAL_BUY)
   {
      Print("DEBUG - ✅ EXECUTING BUY (passed ALL filters: Market Regime [ADX] + Win Rate Booster + RSI Momentum)");
      open_position(ORDER_TYPE_BUY);
   }
   else if(signal == SIGNAL_SELL)
   {
      Print("DEBUG - ✅ EXECUTING SELL (passed ALL filters: Market Regime [ADX] + Win Rate Booster + RSI Momentum)");
      open_position(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Get lead signal based on the selected strategy                   |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE get_lead_signal(ENUM_LEAD_STRATEGY strategy)
{
   switch(strategy)
   {
      case LEAD_ICHIMOKU: return get_ichimoku_signal();
   }
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Get Ichimoku signal (helper function)                            |
//| 🔥 LEAD SIGNAL: Comprehensive trend analysis system              |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE get_ichimoku_signal()
{
   // Get high, low, and close prices for Ichimoku calculation
   double high_prices[], low_prices[], close_prices[];
   ArraySetAsSeries(high_prices, true);
   ArraySetAsSeries(low_prices, true);
   ArraySetAsSeries(close_prices, true);
   
   int required_bars = MathMax(ichimoku_tenkan_sen_period, MathMax(validated_kijun_period, ichimoku_senkou_span_b_period)) + 3;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, required_bars, high_prices) < required_bars ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, required_bars, low_prices) < required_bars ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, required_bars, close_prices) < required_bars)
      return SIGNAL_NONE;
   
   // Calculate Ichimoku components for current period
   double tenkan_sen_current = calculate_tenkan_sen(high_prices, low_prices, 1);
   double kijun_sen_current = calculate_kijun_sen(high_prices, low_prices, 1);
   double senkou_span_a_current = (tenkan_sen_current + kijun_sen_current) / 2.0;
   double senkou_span_b_current = calculate_senkou_span_b(high_prices, low_prices, 1);
   
   // Calculate Ichimoku components for previous period
   double tenkan_sen_previous = calculate_tenkan_sen(high_prices, low_prices, 2);
   double kijun_sen_previous = calculate_kijun_sen(high_prices, low_prices, 2);
   
   // Current close price
   double close_current = close_prices[1];
   
   // Check for invalid values
   if(tenkan_sen_current == EMPTY_VALUE || kijun_sen_current == EMPTY_VALUE ||
      tenkan_sen_previous == EMPTY_VALUE || kijun_sen_previous == EMPTY_VALUE ||
      senkou_span_a_current == EMPTY_VALUE || senkou_span_b_current == EMPTY_VALUE)
      return SIGNAL_NONE;
   
   // Determine cloud top and bottom
   double cloud_top = MathMax(senkou_span_a_current, senkou_span_b_current);
   double cloud_bottom = MathMin(senkou_span_a_current, senkou_span_b_current);
   
   // REVERTED: Strict Ichimoku signal logic (original - proven to work better)
   // Buy signal: Tenkan-sen crosses above Kijun-sen AND close price is above cloud
   // Tín hiệu mua: Tenkan-sen cắt lên trên Kijun-sen VÀ giá đóng cửa nằm trên Mây Kumo
   if(tenkan_sen_current > kijun_sen_current && 
      tenkan_sen_previous <= kijun_sen_previous && 
      close_current > cloud_top)
      return SIGNAL_BUY;
   
   // Sell signal: Tenkan-sen crosses below Kijun-sen AND close price is below cloud
   // Tín hiệu bán: Tenkan-sen cắt xuống dưới Kijun-sen VÀ giá đóng cửa nằm dưới Mây Kumo
   if(tenkan_sen_current < kijun_sen_current && 
      tenkan_sen_previous >= kijun_sen_previous && 
      close_current < cloud_bottom)
      return SIGNAL_SELL;
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Calculate Tenkan-sen (Conversion Line)                           |
//+------------------------------------------------------------------+
double calculate_tenkan_sen(const double &high_array[], const double &low_array[], int bar_index)
{
   if(bar_index + ichimoku_tenkan_sen_period > ArraySize(high_array) || 
      bar_index + ichimoku_tenkan_sen_period > ArraySize(low_array))
      return EMPTY_VALUE;
   
   double highest = high_array[bar_index];
   double lowest = low_array[bar_index];
   
   for(int i = 0; i < ichimoku_tenkan_sen_period; i++)
   {
      if(bar_index + i >= ArraySize(high_array) || bar_index + i >= ArraySize(low_array))
         return EMPTY_VALUE;
         
      if(high_array[bar_index + i] > highest) highest = high_array[bar_index + i];
      if(low_array[bar_index + i] < lowest) lowest = low_array[bar_index + i];
   }
   
   return (highest + lowest) / 2.0;
}

//+------------------------------------------------------------------+
//| Calculate Kijun-sen (Base Line)                                  |
//+------------------------------------------------------------------+
double calculate_kijun_sen(const double &high_array[], const double &low_array[], int bar_index)
{
   if(bar_index + validated_kijun_period > ArraySize(high_array) ||
      bar_index + validated_kijun_period > ArraySize(low_array))
      return EMPTY_VALUE;

   double highest = high_array[bar_index];
   double lowest = low_array[bar_index];

   for(int i = 0; i < validated_kijun_period; i++)
   {
      if(bar_index + i >= ArraySize(high_array) || bar_index + i >= ArraySize(low_array))
         return EMPTY_VALUE;
         
      if(high_array[bar_index + i] > highest) highest = high_array[bar_index + i];
      if(low_array[bar_index + i] < lowest) lowest = low_array[bar_index + i];
   }
   
   return (highest + lowest) / 2.0;
}

//+------------------------------------------------------------------+
//| Calculate Senkou Span B (Leading Span B)                        |
//+------------------------------------------------------------------+
double calculate_senkou_span_b(const double &high_array[], const double &low_array[], int bar_index)
{
   if(bar_index + ichimoku_senkou_span_b_period > ArraySize(high_array) || 
      bar_index + ichimoku_senkou_span_b_period > ArraySize(low_array))
      return EMPTY_VALUE;
   
   double highest = high_array[bar_index];
   double lowest = low_array[bar_index];
   
   for(int i = 0; i < ichimoku_senkou_span_b_period; i++)
   {
      if(bar_index + i >= ArraySize(high_array) || bar_index + i >= ArraySize(low_array))
         return EMPTY_VALUE;
         
      if(high_array[bar_index + i] > highest) highest = high_array[bar_index + i];
      if(low_array[bar_index + i] < lowest) lowest = low_array[bar_index + i];
   }
   
   return (highest + lowest) / 2.0;
}

//+------------------------------------------------------------------+
//| Open new position                                                |
//+------------------------------------------------------------------+
void open_position(ENUM_ORDER_TYPE order_type)
{
   // Block new positions if swap avoidance is active
   if(swap_avoidance_active)
   {
      Print("Trade blocked: Swap avoidance active (near daily rollover)");
      return;
   }

   // Block new positions on Tuesday/Friday near rollover (avoid 3x swap / weekend swap)
   if(is_tuesday_near_rollover())
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      if(dt.day_of_week == 5)
         Print("Trade blocked: Friday near rollover (avoid WEEKEND swap)");
      else if(dt.day_of_week == 2)
         Print("Trade blocked: Tuesday near rollover (avoid Wednesday 3x swap)");
      return;
   }

   // Check if daily drawdown limit is exceeded
   if(daily_drawdown_mode != DD_MODE_DISABLED && daily_drawdown_exceeded)
   {
      Print("Trade blocked: Daily drawdown limit exceeded. No new positions allowed.");
      return;
   }
   
   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get ATR value for SL/TP
   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   if(CopyBuffer(atr_sl_tp_handle, 0, 0, 2, atr_values) < 1)
   {
      Print("Error getting ATR values for SL/TP");
      return;
   }
   double atr_value = atr_values[1];
   
   Print("DEBUG - ATR Value: ", atr_value, " | ATR Multiplier: ", validated_atr_sl_multiplier, " | SL Distance: ", atr_value * validated_atr_sl_multiplier);
   
   // Calculate SL and TP
   double stop_loss, take_profit;
   calculate_sl_tp(order_type, price, atr_value, stop_loss, take_profit);
   
   // Calculate position size (pass order_type for correlation risk management)
   double lot_size = calculate_position_size(price, stop_loss, order_type);
   
   // DEBUG: Print calculated values
   Print("DEBUG - Entry: ", price, " | SL: ", stop_loss, " | Distance: ", MathAbs(price - stop_loss));
   Print("DEBUG - Lot size (before normalize): ", lot_size);
   
   // Normalize lot size
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   Print("DEBUG - Min lot: ", min_lot, " | Max lot: ", max_lot, " | Lot step: ", lot_step);
   
   lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
   lot_size = NormalizeDouble(lot_size / lot_step, 0) * lot_step;
   
   Print("DEBUG - Lot size (after normalize): ", lot_size);
   
   if(lot_size < min_lot)
   {
      Print("ERROR: Lot size (", lot_size, ") < Min lot (", min_lot, ") - Trade rejected!");
      return;
   }
   
   // Open position
   bool result = false;
   if(order_type == ORDER_TYPE_BUY)
   {
      if(atr_trailing_stop_enabled && !use_tp_with_trailing)
         result = trade.Buy(lot_size, _Symbol, price, stop_loss, 0);
      else
         result = trade.Buy(lot_size, _Symbol, price, stop_loss, take_profit);
   }
   else
   {
      if(atr_trailing_stop_enabled && !use_tp_with_trailing)
         result = trade.Sell(lot_size, _Symbol, price, stop_loss, 0);
      else
         result = trade.Sell(lot_size, _Symbol, price, stop_loss, take_profit);
   }
   
   if(result)
   {
      // INSTRUMENTATION: Track TP usage
      total_trades_opened++;
      if(atr_trailing_stop_enabled && !use_tp_with_trailing)
         trades_without_tp++;  // TP = 0 (trailing mode)
      else
         trades_with_tp++;     // TP > 0 (fixed TP)

      // Add to managed positions
      PositionData pos_data;
      pos_data.ticket = trade.ResultOrder();
      pos_data.entry_price = price;
      pos_data.stop_loss = stop_loss;
      pos_data.take_profit = take_profit;
      pos_data.atr_value = atr_value;
      pos_data.open_time = TimeCurrent();
      pos_data.trailing_active = false;
      // 🎯 Profit Harvesting init
      pos_data.max_floating_profit = 0;
      pos_data.partial_closed = false;
      pos_data.original_lot_size = 0;
      pos_data.use_tight_trail = false;

      ArrayResize(managed_positions, ArraySize(managed_positions) + 1);
      managed_positions[ArraySize(managed_positions) - 1] = pos_data;
      
      Print("Position opened: ", order_type == ORDER_TYPE_BUY ? "BUY" : "SELL", 
            " | Lot: ", lot_size, " | Price: ", price, " | SL: ", stop_loss, " | TP: ", take_profit);
      
      // Start Grid Trading if enabled and not already active
      if(grid_trading_enabled && !grid_active)
      {
         // Add first order to grid positions as well
         GridData grid_data;
         grid_data.ticket = trade.ResultOrder();
         grid_data.order_type = order_type;
         grid_data.entry_price = price;
         grid_data.stop_loss = stop_loss;
         grid_data.take_profit = take_profit;
         grid_data.atr_value = atr_value;
         grid_data.open_time = TimeCurrent();
         grid_data.trailing_active = false;
         grid_data.grid_level = 0; // First order is level 0
         grid_data.used_risk = AccountInfoDouble(ACCOUNT_EQUITY) * risk_per_trade;
         grid_data.is_grid_order = true;
         // 🎯 Profit Harvesting init
         grid_data.max_floating_profit = 0;
         grid_data.partial_closed = false;
         grid_data.original_lot_size = 0;
         grid_data.use_tight_trail = false;

         ArrayResize(grid_positions, ArraySize(grid_positions) + 1);
         grid_positions[ArraySize(grid_positions) - 1] = grid_data;
         
         // Start the grid
         start_grid_trading(order_type, price);
      }
   }
   else
   {
      Print("ERROR: Trade rejected by broker! Order: ", order_type == ORDER_TYPE_BUY ? "BUY" : "SELL",
            " | Lot: ", lot_size, " | Price: ", price, " | SL: ", stop_loss, " | TP: ", take_profit,
            " | Error Code: ", trade.ResultRetcode(), " | Error Description: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss and Take Profit                             |
//+------------------------------------------------------------------+
void calculate_sl_tp(ENUM_ORDER_TYPE order_type, double entry_price, double atr_value, double &stop_loss, double &take_profit)
{
   if(use_atr_for_sl_tp && atr_value > 0)
   {
      // ATR-based calculation
      double sl_distance = validated_atr_sl_multiplier * atr_value;
      double tp_distance = reward_risk_ratio * sl_distance;
      
      if(order_type == ORDER_TYPE_BUY)
      {
         stop_loss = entry_price - sl_distance;
         take_profit = entry_price + tp_distance;
      }
      else
      {
         stop_loss = entry_price + sl_distance;
         take_profit = entry_price - tp_distance;
      }
   }
   else
   {
      // Fixed percentage calculation (backup)
      if(order_type == ORDER_TYPE_BUY)
      {
         stop_loss = entry_price * (1 - sl_pct);
         take_profit = entry_price * (1 + tp_pct);
      }
      else
      {
         stop_loss = entry_price * (1 + sl_pct);
         take_profit = entry_price * (1 - tp_pct);
      }
   }
   
   // Normalize prices
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   stop_loss = NormalizeDouble(stop_loss, digits);
   take_profit = NormalizeDouble(take_profit, digits);
   
   // Get minimum stop level
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double min_stop_distance = (stops_level > 0) ? stops_level * point : 0;
   
   // Ensure SL is at least minimum stop level away from entry
   if(min_stop_distance > 0)
   {
      double actual_sl_distance = MathAbs(entry_price - stop_loss);
      if(actual_sl_distance < min_stop_distance)
      {
         // Adjust SL to meet minimum stop level requirement
         if(order_type == ORDER_TYPE_BUY)
         {
            stop_loss = entry_price - min_stop_distance;
         }
         else
         {
            stop_loss = entry_price + min_stop_distance;
         }
         stop_loss = NormalizeDouble(stop_loss, digits);
         
         // Recalculate TP based on new SL distance to maintain R:R ratio
         if(use_atr_for_sl_tp && atr_value > 0)
         {
            double new_sl_distance = min_stop_distance;
            double tp_distance = reward_risk_ratio * new_sl_distance;
            
            if(order_type == ORDER_TYPE_BUY)
            {
               take_profit = entry_price + tp_distance;
            }
            else
            {
               take_profit = entry_price - tp_distance;
            }
            take_profit = NormalizeDouble(take_profit, digits);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                           |
//+------------------------------------------------------------------+
double calculate_position_size(double entry_price, double stop_loss, ENUM_ORDER_TYPE order_type = WRONG_VALUE)
{
   double current_balance = AccountInfoDouble(ACCOUNT_EQUITY);

   // Apply DD tier risk multiplier
   double dd_risk_multiplier = get_risk_multiplier_by_dd_tier();
   
   // Apply Enhanced Risk Management multipliers
   double volatility_multiplier = get_volatility_position_multiplier();
   double correlation_multiplier = (order_type != WRONG_VALUE) ? get_correlation_risk_multiplier(order_type) : 1.0;

   // If DD tier is STOPPED, return 0 (no trading)
   if(current_dd_tier == DD_TIER_STOPPED)
   {
      Print("DEBUG - Position size = 0 (DD TIER STOPPED)");
      return 0;
   }

   // ===========================================
   // ADAPTIVE FILTER SYSTEM - Get current filter states
   // ===========================================
   bool mr_active, exp1_active, exp2_active, exp3_active;
   get_adaptive_filter_states(mr_active, exp1_active, exp2_active, exp3_active);

   // Apply Rolling Performance Gate multiplier (Experiment 1)
   double perf_risk_multiplier = 1.0;
   if(exp1_active)
   {
      perf_risk_multiplier = get_performance_risk_multiplier();
      // If Performance Gate is BLOCKED, return 0 (no trading)
      if(current_perf_tier == PERF_TIER_BLOCKED)
      {
         Print("DEBUG - Position size = 0 (PERF GATE BLOCKED)");
         return 0;
      }
   }

   // Apply ADX Slope multiplier (Experiment 2)
   double adx_slope_multiplier = 1.0;
   if(exp2_active)
   {
      adx_slope_multiplier = get_adx_slope_risk_multiplier();
      if(adx_slope_multiplier == 0.0 && enable_adx_slope_filter)
      {
         Print("DEBUG - Position size = 0 (ADX SLOPE BLOCKED)");
         return 0;
      }
   }

   // Apply ATR Stability multiplier (Experiment 3)
   double atr_stability_multiplier = 1.0;
   if(exp3_active)
   {
      atr_stability_multiplier = get_atr_stability_risk_multiplier();
      if(atr_stability_multiplier == 0.0 && enable_atr_stability_filter)
      {
         Print("DEBUG - Position size = 0 (ATR STABILITY BLOCKED - Extreme volatility)");
         return 0;
      }
   }

   // 🕐 [v5] Apply Time Filter multiplier (when in REDUCE_SIZE mode)
   double time_filter_multiplier = 1.0;
   if(enable_time_filter && is_in_dangerous_time && time_filter_mode == TIME_FILTER_REDUCE_SIZE)
   {
      time_filter_multiplier = current_time_filter_multiplier;
      time_filter_reduced_count++;
   }

   // BB Squeeze multiplier (Experiment 4)
   double bb_squeeze_multiplier = get_bb_squeeze_risk_multiplier();
   if(bb_squeeze_multiplier == 0.0)
   {
      Print("DEBUG - Position size = 0 (BB SQUEEZE BLOCKED)");
      return 0;
   }

   // HTF Trend Bias multiplier (Option C)
   double htf_bias_multiplier = get_htf_trend_bias_multiplier(order_type);
   if(htf_bias_multiplier == 0.0)
   {
      Print("DEBUG - Position size = 0 (HTF BIAS BLOCKED)");
      return 0;
   }

   // Microstructure guard multiplier (Option D)
   double microstructure_multiplier = get_microstructure_guard_multiplier();
   if(microstructure_multiplier == 0.0)
   {
      Print("DEBUG - Position size = 0 (SPREAD GUARD BLOCKED)");
      return 0;
   }

   // ROC / KDJ multipliers (NEW)
   double roc_multiplier = get_roc_risk_multiplier((order_type == ORDER_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL);
   if(roc_multiplier == 0.0)
   {
      Print("DEBUG - Position size = 0 (ROC BLOCKED)");
      return 0;
   }

   double kdj_multiplier = get_kdj_risk_multiplier((order_type == ORDER_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL);
   if(kdj_multiplier == 0.0)
   {
      Print("DEBUG - Position size = 0 (KDJ BLOCKED)");
      return 0;
   }

   // Combined = DD * Perf * ADX Slope * ATR Stability * BB Squeeze * HTF Bias * Spread * Time Filter * Volatility * Correlation * ROC * KDJ
   double combined_multiplier = dd_risk_multiplier * perf_risk_multiplier * adx_slope_multiplier * 
                                atr_stability_multiplier * bb_squeeze_multiplier * htf_bias_multiplier * 
                                microstructure_multiplier * time_filter_multiplier * 
                                volatility_multiplier * correlation_multiplier * 
                                roc_multiplier * kdj_multiplier;
   double risk_amount = current_balance * risk_per_trade * combined_multiplier;

   Print("DEBUG - Regime:", EnumToString(current_filter_regime),
         " | DD:", DoubleToString(dd_risk_multiplier, 2),
         " | Perf:", DoubleToString(perf_risk_multiplier, 2), (exp1_active ? "" : "[OFF]"),
         " | Slope:", DoubleToString(adx_slope_multiplier, 2), (exp2_active ? "" : "[OFF]"),
         " | ATR:", DoubleToString(atr_stability_multiplier, 2), (exp3_active ? "" : "[OFF]"),
         " | BB:", DoubleToString(bb_squeeze_multiplier, 2), (enable_bb_squeeze_filter ? "" : "[OFF]"),
         " | HTF:", DoubleToString(htf_bias_multiplier, 2), (enable_htf_trend_bias ? "" : "[OFF]"),
         " | Spr:", DoubleToString(microstructure_multiplier, 2), (enable_microstructure_guard ? "" : "[OFF]"),
         " | Time:", DoubleToString(time_filter_multiplier, 2), (enable_time_filter ? "" : "[OFF]"),
         " | ROC:", DoubleToString(roc_multiplier, 2), (enable_roc_filter ? "" : "[OFF]"),
         " | KDJ:", DoubleToString(kdj_multiplier, 2), (enable_kdj_filter ? "" : "[OFF]"),
         " | Comb:", DoubleToString(combined_multiplier * 100, 0), "%");

   double distance = MathAbs(entry_price - stop_loss);
   if(distance <= 0) return 0;
   
   // Get symbol properties for correct lot size calculation
   double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // DEBUG: Print symbol properties
   Print("DEBUG - Symbol Properties: Contract Size=", contract_size, " | Tick Size=", tick_size, " | Tick Value=", tick_value, " | Point=", point);
   
   // Calculate lot size correctly for both Forex and Crypto
   // Formula depends on how tick_value is calculated by broker:
   // Option 1: If tick_value is per 1 lot: lot_size = risk_amount / (distance_in_ticks * tick_value)
   // Option 2: More universal: lot_size = (risk_amount * tick_size) / (distance * tick_value)
   // Option 3: Using point value: lot_size = risk_amount / (distance / point * point_value_per_lot)
   
   if(tick_size <= 0 || tick_value <= 0)
   {
      Print("ERROR: Invalid tick_size (", tick_size, ") or tick_value (", tick_value, ")");
      return 0;
   }
   
   // Calculate point value per lot (more universal formula)
   // Point value = value of 1 point movement for 1 lot
   // Formula: point_value_per_lot = tick_value * (point / tick_size)
   // This works because tick_value is the value of 1 tick movement for 1 lot
   double point_value_per_lot = tick_value * (point / tick_size);
   
   // Calculate lot size using point value (most accurate for all brokers)
   double distance_in_points = distance / point;
   double lot_size = risk_amount / (distance_in_points * point_value_per_lot);
   
   // DEBUG: Print calculation details
   Print("DEBUG - Risk Amount: ", risk_amount, " | Distance: ", distance, " | Distance in Points: ", distance_in_points, 
         " | Point Value per Lot: ", point_value_per_lot, " | Calculated Lot Size: ", lot_size);
   
   // Apply slippage adjustment
   lot_size = lot_size * (1 - slippage);
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Update trailing stops for all positions                         |
//+------------------------------------------------------------------+
void update_trailing_stops()
{
   double current_price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Get current ATR value for trailing
   double atr_trailing_values[];
   ArraySetAsSeries(atr_trailing_values, true);
   if(CopyBuffer(atr_trailing_handle, 0, 0, 2, atr_trailing_values) < 1)
      return;
   double current_atr = atr_trailing_values[1];

   for(int i = 0; i < ArraySize(managed_positions); i++)
   {
      if(PositionSelectByTicket(managed_positions[i].ticket))
      {
         double current_price = position.PositionType() == POSITION_TYPE_BUY ? current_price_bid : current_price_ask;
         double entry_price = managed_positions[i].entry_price;
         double current_sl = position.StopLoss();
         double current_lot = position.Volume();

         // Calculate current profit in price units
         double profit = 0;
         if(position.PositionType() == POSITION_TYPE_BUY)
            profit = current_price - entry_price;
         else
            profit = entry_price - current_price;

         // 🎯 [FIX B] MFE Tracking - Update max floating profit
         if(profit > managed_positions[i].max_floating_profit)
            managed_positions[i].max_floating_profit = profit;

         // 🎯 [FIX B] Profit Harvesting System
         if(enable_profit_harvesting && profit > 0)
         {
            double partial_tp_distance = current_atr * partial_tp_atr_mult;
            double profit_retrace_distance = current_atr * profit_retrace_atr_mult;

            // --- PARTIAL TAKE PROFIT ---
            if(!managed_positions[i].partial_closed && profit >= partial_tp_distance)
            {
               // Store original lot size before partial close
               if(managed_positions[i].original_lot_size == 0)
                  managed_positions[i].original_lot_size = current_lot;

               double close_lot = NormalizeDouble(current_lot * partial_tp_percent / 100.0, 2);
               double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

               if(close_lot >= min_lot && (current_lot - close_lot) >= min_lot)
               {
                  if(trade.PositionClosePartial(managed_positions[i].ticket, close_lot))
                  {
                     managed_positions[i].partial_closed = true;
                     managed_positions[i].use_tight_trail = true;  // Tighten trail after partial
                     Print("🎯 PARTIAL TP: Closed ", DoubleToString(partial_tp_percent, 0), "% (",
                           DoubleToString(close_lot, 2), " lots) at ", DoubleToString(profit/_Point, 1), " pips profit");
                  }
               }
            }

            // --- PROFIT RETRACEMENT EXIT ---
            double profit_retrace = managed_positions[i].max_floating_profit - profit;
            if(managed_positions[i].max_floating_profit > partial_tp_distance &&
               profit_retrace >= profit_retrace_distance && profit > 0)
            {
               // Close entire remaining position if profit retraces too much from MFE
               if(trade.PositionClose(managed_positions[i].ticket))
               {
                  Print("🎯 PROFIT RETRACE EXIT: MFE=", DoubleToString(managed_positions[i].max_floating_profit/_Point, 1),
                        " pips, Retrace=", DoubleToString(profit_retrace/_Point, 1), " pips");
                  continue;  // Position closed, move to next
               }
            }
         }

         // --- TRAILING STOP LOGIC ---
         double start_trailing_distance = current_atr * atr_trailing_start_multiplier;

         if(profit >= start_trailing_distance)
         {
            // INSTRUMENTATION: Track trailing activation
            if(!managed_positions[i].trailing_active)
            {
               trailing_activated_count++;  // First time becoming active
            }
            managed_positions[i].trailing_active = true;

            // [v3] REVERTED: Use same logic as F6_KhongSua
            // ATR-based trailing with 0.5% minimum (gives price room to breathe)
            double trailing_distance = current_atr * atr_trailing_multiplier;
            double min_trailing_distance = entry_price * 0.005; // 0.5% - KEY FIX!
            trailing_distance = MathMax(trailing_distance, min_trailing_distance);

            double new_stop = 0;
            bool should_update = false;

            if(position.PositionType() == POSITION_TYPE_BUY)
            {
               new_stop = current_price - trailing_distance;
               should_update = (new_stop > current_sl);
            }
            else
            {
               new_stop = current_price + trailing_distance;
               should_update = (current_sl == 0 || new_stop < current_sl);
            }

            if(should_update)
            {
               double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
               double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
               double min_dist = MathMax(stops_level, freeze_level);

               if(tick_size <= 0)
                  tick_size = _Point;

               // Round to nearest tick size
               new_stop = MathRound(new_stop / tick_size) * tick_size;

               // Final validation against StopsLevel / FreezeLevel
               if(position.PositionType() == POSITION_TYPE_BUY)
               {
                  if(current_price - new_stop < min_dist)
                     new_stop = current_price - min_dist;
               }
               else
               {
                  if(new_stop - current_price < min_dist)
                     new_stop = current_price + min_dist;
               }

               new_stop = NormalizeDouble(new_stop, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

               // Only modify if there's a real change (avoid spam + invalid stops)
               if(MathAbs(new_stop - current_sl) > tick_size / 2.0)
               {
                  if(trade.PositionModify(managed_positions[i].ticket, new_stop, position.TakeProfit()))
                  {
                     // INSTRUMENTATION: Track SL modifications
                     trailing_modified_count++;

                     managed_positions[i].stop_loss = new_stop;
                     Print("Trailing stop updated for ticket ", managed_positions[i].ticket, " | New SL: ", new_stop);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update grid positions array                                      |
//+------------------------------------------------------------------+
void update_grid_positions()
{
   // Remove closed positions from grid array
   for(int i = ArraySize(grid_positions) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(grid_positions[i].ticket))
      {
         // Position closed, remove from array
         ArrayRemove(grid_positions, i, 1);
         current_grid_count--;
      }
   }
   
   // Check if all grid positions are closed
   if(ArraySize(grid_positions) == 0 && grid_active)
   {
      // Reset grid state
      grid_active = false;
      current_grid_count = 0;
      first_grid_price = 0;
      last_grid_price = 0;
      base_risk_amount = 0;
      Print("Grid Trading stopped - All positions closed");
   }
}

//+------------------------------------------------------------------+
//| Update trailing stops for grid positions                        |
//+------------------------------------------------------------------+
void update_grid_trailing_stops()
{
   double current_price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Get current ATR value for trailing
   double atr_trailing_values[];
   ArraySetAsSeries(atr_trailing_values, true);
   if(CopyBuffer(atr_trailing_handle, 0, 0, 2, atr_trailing_values) < 1)
      return;
   double current_atr = atr_trailing_values[1];

   for(int i = 0; i < ArraySize(grid_positions); i++)
   {
      if(PositionSelectByTicket(grid_positions[i].ticket))
      {
         double current_price = position.PositionType() == POSITION_TYPE_BUY ? current_price_bid : current_price_ask;
         double entry_price = grid_positions[i].entry_price;
         double current_sl = position.StopLoss();
         double current_lot = position.Volume();

         // Calculate current profit in price units
         double profit = 0;
         if(position.PositionType() == POSITION_TYPE_BUY)
            profit = current_price - entry_price;
         else
            profit = entry_price - current_price;

         // 🎯 MFE Tracking
         if(profit > grid_positions[i].max_floating_profit)
            grid_positions[i].max_floating_profit = profit;

         // 🎯 Profit Harvesting for Grid
         if(enable_profit_harvesting && profit > 0)
         {
            double partial_tp_distance = current_atr * partial_tp_atr_mult;
            double profit_retrace_distance = current_atr * profit_retrace_atr_mult;

            // --- PARTIAL TAKE PROFIT ---
            if(!grid_positions[i].partial_closed && profit >= partial_tp_distance)
            {
               if(grid_positions[i].original_lot_size == 0)
                  grid_positions[i].original_lot_size = current_lot;

               double close_lot = NormalizeDouble(current_lot * partial_tp_percent / 100.0, 2);
               double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

               if(close_lot >= min_lot && (current_lot - close_lot) >= min_lot)
               {
                  if(trade.PositionClosePartial(grid_positions[i].ticket, close_lot))
                  {
                     grid_positions[i].partial_closed = true;
                     grid_positions[i].use_tight_trail = true;
                     Print("🎯 GRID PARTIAL TP: Level ", grid_positions[i].grid_level,
                           " | Closed ", DoubleToString(close_lot, 2), " lots at ",
                           DoubleToString(profit/_Point, 1), " pips profit");
                  }
               }
            }

            // --- PROFIT RETRACEMENT EXIT ---
            double profit_retrace = grid_positions[i].max_floating_profit - profit;
            if(grid_positions[i].max_floating_profit > partial_tp_distance &&
               profit_retrace >= profit_retrace_distance && profit > 0)
            {
               if(trade.PositionClose(grid_positions[i].ticket))
               {
                  Print("🎯 GRID RETRACE EXIT: Level ", grid_positions[i].grid_level,
                        " | MFE=", DoubleToString(grid_positions[i].max_floating_profit/_Point, 1), " pips");
                  continue;
               }
            }
         }

         // --- TRAILING STOP LOGIC ---
         double start_trailing_distance = current_atr * atr_trailing_start_multiplier;

         if(profit >= start_trailing_distance)
         {
            grid_positions[i].trailing_active = true;

            // [v3] REVERTED: Use same logic as F6_KhongSua
            double trailing_distance = current_atr * atr_trailing_multiplier;
            double min_trailing_distance = entry_price * 0.005; // 0.5% - KEY FIX!
            trailing_distance = MathMax(trailing_distance, min_trailing_distance);

            double new_stop = 0;
            bool should_update = false;

            if(position.PositionType() == POSITION_TYPE_BUY)
            {
               new_stop = current_price - trailing_distance;
               should_update = (new_stop > current_sl);
            }
            else
            {
               new_stop = current_price + trailing_distance;
               should_update = (current_sl == 0 || new_stop < current_sl);
            }

            if(should_update)
            {
               double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
               double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
               double min_dist = MathMax(stops_level, freeze_level);

               if(tick_size <= 0)
                  tick_size = _Point;

               // Round to nearest tick size
               new_stop = MathRound(new_stop / tick_size) * tick_size;

               // Final validation against StopsLevel / FreezeLevel
               if(position.PositionType() == POSITION_TYPE_BUY)
               {
                  if(current_price - new_stop < min_dist)
                     new_stop = current_price - min_dist;
               }
               else
               {
                  if(new_stop - current_price < min_dist)
                     new_stop = current_price + min_dist;
               }

               new_stop = NormalizeDouble(new_stop, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

               // Only modify if there's a real change (avoid spam + invalid stops)
               if(MathAbs(new_stop - current_sl) > tick_size / 2.0)
               {
                  if(trade.PositionModify(grid_positions[i].ticket, new_stop, position.TakeProfit()))
                  {
                     grid_positions[i].stop_loss = new_stop;
                     Print("Grid trailing stop updated for ticket ", grid_positions[i].ticket,
                           " | Grid Level: ", grid_positions[i].grid_level, " | New SL: ", new_stop);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for grid level triggers                                    |
//+------------------------------------------------------------------+
void check_grid_levels()
{
   if(!grid_active || current_grid_count >= max_grid_orders)
      return;
   
   // 🚨 [v6] GRID EXPANSION CONTROL: Check if expansion is allowed
   if(!should_allow_grid_expansion())
   {
      // Grid expansion blocked by filter
      return; // Don't expand grid
   }
   
   double current_price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current_price = (current_grid_direction == ORDER_TYPE_BUY) ? current_price_ask : current_price_bid;
   
   // Calculate grid spacing
   double grid_spacing = calculate_grid_spacing();
   if(grid_spacing <= 0)
      return;
   
   bool should_open_grid = false;
   double target_price = 0;
   
   if(grid_mode == GRID_ANTI_TREND)
   {
      // Anti-Trend: Open new orders in the same direction when price moves against
      if(current_grid_direction == ORDER_TYPE_BUY)
      {
         target_price = last_grid_price - grid_spacing;
         should_open_grid = (current_price <= target_price);
      }
      else // SELL
      {
         target_price = last_grid_price + grid_spacing;
         should_open_grid = (current_price >= target_price);
      }
   }
   
   if(should_open_grid)
   {
      open_grid_position(current_grid_direction, current_grid_count);
   }
}

//+------------------------------------------------------------------+
//| Start grid trading                                               |
//+------------------------------------------------------------------+
void start_grid_trading(ENUM_ORDER_TYPE order_type, double first_order_price)
{
   if(!grid_trading_enabled || grid_active)
      return;
   
   grid_active = true;
   current_grid_direction = order_type;
   first_grid_price = first_order_price;
   last_grid_price = first_order_price;
   current_grid_count = 1; // First order is already opened
   base_risk_amount = AccountInfoDouble(ACCOUNT_EQUITY) * risk_per_trade;
   
   Print("Grid Trading started - Direction: ", (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), 
         " | Mode: Anti-Trend",
         " | First Price: ", first_order_price, " | Max Orders: ", max_grid_orders);
}

//+------------------------------------------------------------------+
//| Calculate grid spacing                                           |
//+------------------------------------------------------------------+
double calculate_grid_spacing()
{
   if(use_atr_for_grid_spacing)
   {
      // ATR-based spacing
      double atr_values[];
      ArraySetAsSeries(atr_values, true);
      if(CopyBuffer(grid_atr_handle, 0, 0, 2, atr_values) < 1)
         return 0;
      
      return atr_values[1] * grid_spacing_atr_multiplier;
   }
   else
   {
      // Percentage-based spacing
      double current_price = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
      return current_price * grid_spacing_percentage;
   }
}

//+------------------------------------------------------------------+
//| Calculate grid position size                                     |
//+------------------------------------------------------------------+
double calculate_grid_position_size(double entry_price, double stop_loss, int grid_level)
{
   double risk_amount = 0;
   
   if(grid_size_mode == GRID_SIZE_MULTIPLY_FIRST)
   {
      // Multiply from first order risk
      risk_amount = base_risk_amount * MathPow(grid_risk_multiplier, grid_level);
   }
   else // GRID_SIZE_MULTIPLY_PREVIOUS
   {
      // Multiply from previous order risk
      if(grid_level == 0)
         risk_amount = base_risk_amount;
      else
      {
         // Get previous order risk and multiply
         double previous_risk = base_risk_amount;
         if(ArraySize(grid_positions) > 0)
         {
            // Find the most recent grid position
            for(int i = ArraySize(grid_positions) - 1; i >= 0; i--)
            {
               if(grid_positions[i].grid_level == grid_level - 1)
               {
                  previous_risk = grid_positions[i].used_risk;
                  break;
               }
            }
         }
         risk_amount = previous_risk * grid_risk_multiplier;
      }
   }
   
   double distance = MathAbs(entry_price - stop_loss);
   if(distance <= 0) return 0;
   
   // Get symbol properties for correct lot size calculation
   double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculate lot size correctly for both Forex and Crypto
   // Using point value per lot (most accurate for all brokers)
   if(tick_size <= 0 || tick_value <= 0)
   {
      Print("ERROR: Invalid tick_size (", tick_size, ") or tick_value (", tick_value, ")");
      return 0;
   }
   
   // Calculate point value per lot (more universal formula)
   // Point value = value of 1 point movement for 1 lot
   // Formula: point_value_per_lot = tick_value * (point / tick_size)
   double point_value_per_lot = tick_value * (point / tick_size);
   
   // Calculate lot size using point value
   double distance_in_points = distance / point;
   double lot_size = risk_amount / (distance_in_points * point_value_per_lot);
   
   // Apply slippage adjustment
   lot_size = lot_size * (1 - slippage);
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Open grid position                                               |
//+------------------------------------------------------------------+
void open_grid_position(ENUM_ORDER_TYPE order_type, int grid_level)
{
   // Block new grid positions if swap avoidance is active
   if(swap_avoidance_active)
   {
      Print("Grid trade blocked: Swap avoidance active (near daily rollover)");
      return;
   }

   // Block new grid positions on Tuesday/Friday near rollover
   if(is_tuesday_near_rollover())
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      if(dt.day_of_week == 5)
         Print("Grid trade blocked: Friday near rollover (avoid WEEKEND swap)");
      else if(dt.day_of_week == 2)
         Print("Grid trade blocked: Tuesday near rollover (avoid Wednesday 3x swap)");
      return;
   }

   // Check if daily drawdown limit is exceeded
   if(daily_drawdown_mode != DD_MODE_DISABLED && daily_drawdown_exceeded)
   {
      Print("Grid trade blocked: Daily drawdown limit exceeded. No new grid positions allowed.");
      return;
   }
   
   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get ATR value for SL/TP
   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   if(CopyBuffer(atr_sl_tp_handle, 0, 0, 2, atr_values) < 1)
   {
      Print("Error getting ATR values for Grid SL/TP");
      return;
   }
   double atr_value = atr_values[1];
   
   // Calculate SL and TP
   double stop_loss, take_profit;
   calculate_sl_tp(order_type, price, atr_value, stop_loss, take_profit);
   
   // Calculate grid position size
   double lot_size = calculate_grid_position_size(price, stop_loss, grid_level);
   
   // Normalize lot size
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
   lot_size = NormalizeDouble(lot_size / lot_step, 0) * lot_step;
   
   // Calculate actual risk amount used
   double distance = MathAbs(price - stop_loss);
   double actual_risk = lot_size * distance / (1 - slippage);
   
   // Open position
   bool result = false;
   if(order_type == ORDER_TYPE_BUY)
   {
      if(atr_trailing_stop_enabled && !use_tp_with_trailing)
         result = trade.Buy(lot_size, _Symbol, price, stop_loss, 0);
      else
         result = trade.Buy(lot_size, _Symbol, price, stop_loss, take_profit);
   }
   else
   {
      if(atr_trailing_stop_enabled && !use_tp_with_trailing)
         result = trade.Sell(lot_size, _Symbol, price, stop_loss, 0);
      else
         result = trade.Sell(lot_size, _Symbol, price, stop_loss, take_profit);
   }
   
   if(result)
   {
      // Add to grid positions array
      GridData grid_data;
      grid_data.ticket = trade.ResultOrder();
      grid_data.order_type = order_type;
      grid_data.entry_price = price;
      grid_data.stop_loss = stop_loss;
      grid_data.take_profit = take_profit;
      grid_data.atr_value = atr_value;
      grid_data.open_time = TimeCurrent();
      grid_data.trailing_active = false;
      grid_data.grid_level = grid_level;
      grid_data.used_risk = actual_risk;
      grid_data.is_grid_order = true;
      // 🎯 Profit Harvesting init
      grid_data.max_floating_profit = 0;
      grid_data.partial_closed = false;
      grid_data.original_lot_size = 0;
      grid_data.use_tight_trail = false;

      ArrayResize(grid_positions, ArraySize(grid_positions) + 1);
      grid_positions[ArraySize(grid_positions) - 1] = grid_data;
      
      // Update grid state
      current_grid_count++;
      last_grid_price = price;

      // INSTRUMENTATION: Track grid depth
      if(current_grid_count > max_grid_depth_reached)
         max_grid_depth_reached = current_grid_count;

      if(current_grid_count < 20)  // Histogram limit
         grid_depth_histogram[current_grid_count]++;
      
      Print("Grid Position opened: Level ", grid_level, " | ", (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " | Lot: ", lot_size, " | Price: ", price, " | SL: ", stop_loss, " | TP: ", take_profit,
            " | Risk: ", actual_risk, " | Mode: Anti-Trend");
   }
}

//+------------------------------------------------------------------+
//| OnTesterDeinit - Export test results to CSV file                 |
//| Called after strategy tester completes - writes to MQL5/Files/   |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
   // Get tester statistics
   double net_profit = TesterStatistics(STAT_PROFIT);
   double gross_profit = TesterStatistics(STAT_GROSS_PROFIT);
   double gross_loss = TesterStatistics(STAT_GROSS_LOSS);
   double profit_factor = TesterStatistics(STAT_PROFIT_FACTOR);
   double expected_payoff = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double max_drawdown = TesterStatistics(STAT_BALANCE_DD);
   double max_drawdown_pct = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
   double equity_dd = TesterStatistics(STAT_EQUITY_DD);
   double equity_dd_pct = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double recovery_factor = TesterStatistics(STAT_RECOVERY_FACTOR);
   double sharpe_ratio = TesterStatistics(STAT_SHARPE_RATIO);

   int total_trades = (int)TesterStatistics(STAT_TRADES);
   int profit_trades = (int)TesterStatistics(STAT_PROFIT_TRADES);
   int loss_trades = (int)TesterStatistics(STAT_LOSS_TRADES);
   double win_rate = (total_trades > 0) ? (100.0 * profit_trades / total_trades) : 0;

   double initial_deposit = TesterStatistics(STAT_INITIAL_DEPOSIT);
   double final_balance = initial_deposit + net_profit;
   double return_pct = (initial_deposit > 0) ? (100.0 * net_profit / initial_deposit) : 0;

   // Create filename with symbol and date range
   string filename = "backtest_results.csv";

   // Check if file exists to determine if we need header
   bool file_exists = FileIsExist(filename, FILE_COMMON);

   // Open file in append mode
   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot open file ", filename, " Error: ", GetLastError());
      return;
   }

   // If file is new, write header
   if(!file_exists || FileSize(handle) == 0)
   {
      FileWrite(handle,
         "Timestamp",
         "Symbol",
         "Timeframe",
         "FromDate",
         "ToDate",
         "InitialDeposit",
         "FinalBalance",
         "NetProfit",
         "ReturnPct",
         "GrossProfit",
         "GrossLoss",
         "ProfitFactor",
         "ExpectedPayoff",
         "MaxDrawdown",
         "MaxDrawdownPct",
         "EquityDD",
         "EquityDDPct",
         "RecoveryFactor",
         "SharpeRatio",
         "TotalTrades",
         "ProfitTrades",
         "LossTrades",
         "WinRate"
      );
   }

   // Move to end of file
   FileSeek(handle, 0, SEEK_END);

   // Get period as string
   string period_str = EnumToString(Period());

   // Write data row
   FileWrite(handle,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      _Symbol,
      period_str,
      "", // FromDate - will be filled by batch script if needed
      "", // ToDate - will be filled by batch script if needed
      DoubleToString(initial_deposit, 2),
      DoubleToString(final_balance, 2),
      DoubleToString(net_profit, 2),
      DoubleToString(return_pct, 2),
      DoubleToString(gross_profit, 2),
      DoubleToString(gross_loss, 2),
      DoubleToString(profit_factor, 2),
      DoubleToString(expected_payoff, 2),
      DoubleToString(max_drawdown, 2),
      DoubleToString(max_drawdown_pct, 2),
      DoubleToString(equity_dd, 2),
      DoubleToString(equity_dd_pct, 2),
      DoubleToString(recovery_factor, 2),
      DoubleToString(sharpe_ratio, 2),
      IntegerToString(total_trades),
      IntegerToString(profit_trades),
      IntegerToString(loss_trades),
      DoubleToString(win_rate, 2)
   );

   FileClose(handle);

   Print("=== TESTER RESULTS EXPORTED ===");
   Print("File: ", filename, " (in Terminal/Common/Files/)");
   Print("Net Profit: ", DoubleToString(net_profit, 2), " (", DoubleToString(return_pct, 2), "%)");
   Print("Profit Factor: ", DoubleToString(profit_factor, 2));
   Print("Max DD: ", DoubleToString(max_drawdown_pct, 2), "%");
   Print("Sharpe: ", DoubleToString(sharpe_ratio, 2));
   Print("Trades: ", total_trades, " | Win Rate: ", DoubleToString(win_rate, 2), "%");
}

//+------------------------------------------------------------------+
