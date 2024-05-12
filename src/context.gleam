import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type Item {
  Item(value: String, expires_at: Option(Int))
}

pub type Context {
  Context(state: Dict(String, Item))
}
