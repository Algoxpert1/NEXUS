from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass(frozen=True)
class MarketDataset:
    """Multi-symbol aligned dataset for quantitative research."""

    provider: str
    timeline: List[int]
    symbols: List[str]
    perp_close: Dict[str, List[float]]
    spot_close: Optional[Dict[str, List[float]]] = None
    funding: Dict[str, Dict[int, float]] = field(default_factory=dict)
    fingerprint: str = ""
    market_type: str = "crypto"
    features: Dict[str, Any] = field(default_factory=dict)
    perp_volume: Optional[Dict[str, List[float]]] = None
    meta: Dict[str, Any] = field(default_factory=dict)

    @property
    def has_funding(self) -> bool:
        return bool(self.funding)


Weights = Dict[str, float]


class Strategy(ABC):
    """Abstract base class for trading strategies."""

    def __init__(self, name: str = "unknown", params: Dict[str, Any] | None = None) -> None:
        self.name = name
        self.params = params or {}

    def _assert_idx_valid(self, dataset: MarketDataset, idx: int) -> None:
        if idx < 1 or idx >= len(dataset.timeline):
            raise RuntimeError(
                f"[LOOK-AHEAD BIAS] idx={idx} out of range [1, {len(dataset.timeline)})"
            )

    @abstractmethod
    def should_rebalance(self, dataset: MarketDataset, idx: int) -> bool:
        ...

    @abstractmethod
    def target_weights(self, dataset: MarketDataset, idx: int, current: Weights) -> Weights:
        ...

    def describe(self) -> Dict[str, Any]:
        return {"name": self.name, "params": self.params}