import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import sqlight
import storage

pub fn main() {
  gleeunit.main()
}

pub fn insert_test() {
  use conn <- sqlight.with_connection(":memory:")

  storage.init(conn)
  |> should.be_ok

  storage.insert(conn, "foo", "bar")
  |> should.be_ok
}

pub fn insert_key_exists_test() {
  use conn <- sqlight.with_connection(":memory:")

  storage.init(conn)
  |> should.be_ok

  let key = "foo"

  storage.insert(conn, key, "bar")
  |> should.be_ok

  storage.insert(conn, key, "baz")
  |> should.be_ok

  storage.get(conn, key)
  |> should.be_ok
  |> should.equal(Some("baz"))
}

pub fn get_test() {
  use conn <- sqlight.with_connection(":memory:")

  storage.init(conn)
  |> should.be_ok

  let #(key, value) = #("foo", "bar")

  storage.insert(conn, key, value)
  |> should.be_ok

  storage.get(conn, key)
  |> should.be_ok
  |> should.equal(Some(value))
}

pub fn get_value_not_found_test() {
  use conn <- sqlight.with_connection(":memory:")

  storage.init(conn)
  |> should.be_ok

  storage.get(conn, "foo")
  |> should.be_ok
  |> should.equal(None)
}
