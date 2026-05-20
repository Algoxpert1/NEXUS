from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P04SpxPcsAdapter(Strategy):
    """P04 SPX put-credit-spread adapter for local replay.

    Entry signal: mean-reversion proxy after mild selloffs on supplied SPX/options close path.
    Exit rule: flatten after rebound or risk-off breakdown.
    Risk management: small long-only exposure cap reflecting defined-risk spread sizing.
    """

    def __init__(self, name: str = "P04_spx_pcs_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.lookback = int(self.params.get("lookback", 20))
        self.rebalance_every = int(self.params.get("rebalance_every", 1))
        self.max_weight = float(self.params.get("max_weight", 0.20))

    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        return idx >= self.lookback and idx % self.rebalance_every == 0

    @staticmethod
    def _mean(values: list[float]) -> float:
        return sum(values) / len(values) if values else 0.0

    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        weights = {}
        for symbol in dataset.symbols:
            prices = dataset.perp_close[symbol]
            mean_price = self._mean(prices[idx - self.lookback:idx])
            drawdown = prices[idx] / mean_price - 1.0 if mean_price else 0.0
            weights[symbol] = self.max_weight if -0.035 <= drawdown <= -0.003 else 0.0
        return weights
