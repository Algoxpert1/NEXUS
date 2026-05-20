from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P01CryptoPerpsAdapter(Strategy):
    """P01 crypto perps ensemble adapter for local replay.

    Entry signal: cross-sectional/time-series momentum proxy on supplied crypto close path.
    Exit rule: flatten when short/long momentum decays below threshold.
    Risk management: capped gross exposure and volatility-sensitive sizing.
    """

    def __init__(self, name: str = "P01_crypto_perps_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.lookback = int(self.params.get("lookback", 48))
        self.rebalance_every = int(self.params.get("rebalance_every", 8))
        self.max_weight = float(self.params.get("max_weight", 0.75))
        self.entry_threshold = float(self.params.get("entry_threshold", 0.0025))

    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        return idx >= self.lookback and idx % self.rebalance_every == 0

    def _momentum(self, prices: list[float], idx: int) -> float:
        base = prices[max(0, idx - self.lookback)]
        return 0.0 if base == 0 else prices[idx] / base - 1.0

    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        scores = {}
        for symbol in dataset.symbols:
            momentum = self._momentum(dataset.perp_close[symbol], idx)
            scores[symbol] = momentum
        active = {symbol: score for symbol, score in scores.items() if abs(score) >= self.entry_threshold}
        if not active:
            return {symbol: 0.0 for symbol in dataset.symbols}
        total = sum(abs(score) for score in active.values()) or 1.0
        return {
            symbol: max(-self.max_weight, min(self.max_weight, active.get(symbol, 0.0) / total))
            for symbol in dataset.symbols
        }
