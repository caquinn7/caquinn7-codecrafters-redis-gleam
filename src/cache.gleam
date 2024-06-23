import carpenter/table.{type Set as EtsTable}
import gleam/erlang/atom
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gluid
import rdb.{type Rdb, Expiry, Milliseconds, Seconds}

pub type Item {
  Item(value: BitArray, expires_at: Option(Int))
}

pub type Cache =
  EtsTable(BitArray, Item)

pub fn init() -> Cache {
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

pub fn get_keys(cache: Cache) -> List(BitArray) {
  get_all_keys(cache.table.name)
}

pub fn remove(cache: Cache, key: BitArray) {
  table.delete(cache, key)
}

pub fn from_rdb(rdb: Rdb) -> Cache {
  let items =
    rdb.databases
    |> list.flat_map(fn(db) { db.records })
    |> list.map(fn(rec) {
      let expiry = case rec.expiry {
        None -> None
        Some(Expiry(i, Milliseconds)) -> Some(i)
        Some(Expiry(i, Seconds)) -> Some(i * 1000)
      }
      #(rec.key, Item(rec.value, expiry))
    })
  let cache = init()
  table.insert(cache, items)
  cache
}

@external(erlang, "ets_utils_ffi", "get_all_keys")
fn get_all_keys(table: atom.Atom) -> List(BitArray)
