import carpenter/table.{type Set as EtsTable}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gluid

pub type Item {
  Item(value: BitArray, expires_at: Option(Int))
}

pub type Cache =
  EtsTable(BitArray, Item)

pub fn init() {
  let assert Ok(ets) =
    table.build(gluid.guidv4())
    |> table.privacy(table.Public)
    |> table.write_concurrency(table.WriteConcurrency)
    |> table.read_concurrency(True)
    |> table.compression(False)
    |> table.set
  ets
}

pub fn set(cache: Cache, key: BitArray, item: Item) -> Nil {
  table.insert(cache, [#(key, item)])
}

pub fn get(cache: Cache, key: BitArray) -> Result(Item, Nil) {
  cache
  |> table.lookup(key)
  |> list.first
  |> result.map(fn(pair) { pair.1 })
}

pub fn remove(cache: Cache, key: BitArray) {
  table.delete(cache, key)
}
