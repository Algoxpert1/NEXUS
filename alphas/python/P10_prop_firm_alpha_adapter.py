from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P10PropFirmAlphaAdapter(Strategy):
    """P10 prop-firm TSMOM adapter for local replay.

    Entry signal: time-series momentum on supplied Gold/SPX/futures close path.
    Exit rule: flatten when momentum turns negative.
    Risk management: conservative cap for daily-loss/trailing-drawdown constraints.
    """

    def __init__(self, name: str = "P10_prop_firm_alpha_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.fast = int(self.params.get("fast", 42))
        self.slow = int(self.params.get("slow", 168))
        self.rebalance_every = int(self.params.get("rebalance_every", 5))
        self.max_weight = float(self.params.get("max_weight", 0.35))

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
