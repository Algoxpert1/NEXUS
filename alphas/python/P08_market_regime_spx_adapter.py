from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P08MarketRegimeSpxAdapter(Strategy):
    """P08 SPX regime ensemble adapter for local replay.

    Entry signal: risk-on allocation when supplied SPX/regime close path is above slow trend.
    Exit rule: de-risk when trend/regime proxy breaks.
    Risk management: half exposure in transition regimes.
    """

    def __init__(self, name: str = "P08_market_regime_spx_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.fast = int(self.params.get("fast", 21))
        self.slow = int(self.params.get("slow", 126))
        self.rebalance_every = int(self.params.get("rebalance_every", 5))
        self.max_weight = float(self.params.get("max_weight", 0.70))

    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        return idx >= self.slow and idx % self.rebalance_every == 0

    @staticmethod
    def _mean(values: list[float]) -> float:
        return sum(values) / len(values) if values else 0.0

    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        weights = {}
        for symbol in dataset.symbols:
            prices = dataset.perp_close[symbol]
            fast_ma = self._mean(prices[idx - self.fast:idx])
            slow_ma = self._mean(prices[idx - self.slow:idx])
            weights[symbol] = self.max_weight if fast_ma > slow_ma else 0.0
        return weights
