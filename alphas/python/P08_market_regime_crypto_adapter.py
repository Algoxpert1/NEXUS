from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P08MarketRegimeCryptoAdapter(Strategy):
    """P08 crypto regime mixer adapter for local replay.

    Entry signal: crypto momentum when breadth proxy is positive.
    Exit rule: flatten when short momentum weakens.
    Risk management: lower exposure during choppy trend disagreement.
    """

    def __init__(self, name: str = "P08_market_regime_crypto_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.short = int(self.params.get("short", 24))
        self.long = int(self.params.get("long", 120))
        self.rebalance_every = int(self.params.get("rebalance_every", 6))
        self.max_weight = float(self.params.get("max_weight", 0.65))

    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        return idx >= self.long and idx % self.rebalance_every == 0

    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        weights = {}
        for symbol in dataset.symbols:
            prices = dataset.perp_close[symbol]
            short_ret = prices[idx] / prices[idx - self.short] - 1.0 if prices[idx - self.short] else 0.0
            long_ret = prices[idx] / prices[idx - self.long] - 1.0 if prices[idx - self.long] else 0.0
            if short_ret > 0 and long_ret > 0:
                weights[symbol] = self.max_weight
            elif short_ret > 0:
                weights[symbol] = self.max_weight * 0.35
            else:
                weights[symbol] = 0.0
        return weights
