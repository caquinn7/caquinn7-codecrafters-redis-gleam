import carpenter/table.{type Set as EtsTable}
import gleam/option.{type Option}
import gluid

pub type Item {
  Item(value: BitArray, expires_at: Option(Int))
}

pub type State =
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
