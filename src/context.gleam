import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type Context {
  Context(state: Dict(String, Item))
}

pub type Item {
  Item(value: String, expires_at: Option(Int))
}

pub fn empty() {
  Context(dict.new())
}
