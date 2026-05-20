from __future__ import annotations

from .backtest_engine import MarketDataset, Strategy, Weights


class P27LlmQuantumAdapter(Strategy):
    """P27 LLM quantum research adapter for local replay.

    Entry signal: deterministic candidate-selection proxy over supplied close path.
    Exit rule: rebalance out when candidate score turns negative.
    Risk management: minimal exposure because the original alpha is research/non-verified.
    """

    def __init__(self, name: str = "P27_llm_quantum_adapter", params: dict | None = None) -> None:
        super().__init__(name=name, params=params or {})
        self.lookback = int(self.params.get("lookback", 60))
        self.rebalance_every = int(self.params.get("rebalance_every", 10))
        self.max_weight = float(self.params.get("max_weight", 0.15))

    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        return idx >= self.lookback and idx % self.rebalance_every == 0

    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        weights = {}
        for symbol in dataset.symbols:
            prices = dataset.perp_close[symbol]
            score = prices[idx] / prices[idx - self.lookback] - 1.0 if prices[idx - self.lookback] else 0.0
            weights[symbol] = self.max_weight if score > 0 else 0.0
        return weights
