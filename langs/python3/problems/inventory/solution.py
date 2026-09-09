"""Reference inventory register."""

from __future__ import annotations


class Item:
    def __init__(self, sku: str, name: str) -> None:
        self.sku = sku
        self.name = name
        self.qty = 0
        self.reserved = 0


class Simulation:
    def __init__(self) -> None:
        self.items: dict[str, Item] = {}

    def create_item(self, sku: str, name: str) -> str:
        if sku in self.items:
            return "false"
        self.items[sku] = Item(sku, name)
        return "true"

    def stock(self, sku: str, delta: int) -> str:
        item = self.items.get(sku)
        if item is None:
            return ""
        nxt = item.qty + delta
        if nxt < item.reserved:
            return "invalid_request"
        item.qty = nxt
        return str(item.qty)

    def get_qty(self, sku: str) -> str:
        item = self.items.get(sku)
        if item is None:
            return ""
        return str(item.qty)

    def list_low(self, threshold: int) -> str:
        matched = [item for item in self.items.values() if item.qty <= threshold]
        matched.sort(key=lambda item: (item.qty, item.sku))
        return ", ".join(f"{item.sku}({item.qty})" for item in matched)

    def reserve(self, sku: str, n: int) -> str:
        item = self.items.get(sku)
        if item is None or n <= 0 or item.reserved + n > item.qty:
            return "invalid_request"
        item.reserved += n
        return "true"

    def release(self, sku: str, n: int) -> str:
        item = self.items.get(sku)
        if item is None or n <= 0 or n > item.reserved:
            return "invalid_request"
        item.reserved -= n
        return "true"

    def ship(self, sku: str, n: int) -> str:
        item = self.items.get(sku)
        if item is None or n <= 0 or n > item.reserved:
            return "invalid_request"
        item.reserved -= n
        item.qty -= n
        return "true"
