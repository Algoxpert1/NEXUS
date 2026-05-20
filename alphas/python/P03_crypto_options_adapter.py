from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P03CryptoOptionsAdapter(Strategy):
    """P03 crypto options VRP/skew adapter for local replay.

    Entry signal: realized-volatility compression proxy on supplied option/underlying close path.
    Exit rule: flatten after volatility expansion or when momentum shock appears.
    Risk management: low gross exposure because options require Greeks/fill evidence outside this adapter.
    """

    def __init__(self, name: str = "P03_crypto_options_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.lookback = int(self.params.get("lookback", 30))
        self.rebalance_every = int(self.params.get("rebalance_every", 3))
        self.max_weight = float(self.params.get("max_weight", 0.25))

    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        return idx >= self.lookback + 2 and idx % self.rebalance_every == 0

    @staticmethod
    def _abs_return_sum(prices: list[float], start: int, end: int) -> float:
        total = 0.0
        for i in range(max(1, start), end):
            prev = prices[i - 1]
            if prev:
                total += abs(prices[i] / prev - 1.0)
        return total

    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        weights = {}
        for symbol in dataset.symbols:
            prices = dataset.perp_close[symbol]
            recent_vol = self._abs_return_sum(prices, idx - 5, idx)
            base_vol = self._abs_return_sum(prices, idx - self.lookback, idx)
            compression = recent_vol < (base_vol / max(1, self.lookback)) * 8.0
            weights[symbol] = self.max_weight if compression else 0.0
        return weights
