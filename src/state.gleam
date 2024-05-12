import carpenter/table.{type Set as EtsTable}
import gleam/option.{type Option}
import gluid

pub type State =
  EtsTable(String, Item)

pub type Item {
  Item(value: String, expires_at: Option(Int))
}

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
