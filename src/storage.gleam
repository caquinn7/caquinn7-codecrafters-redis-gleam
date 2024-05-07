import gleam/dynamic
import gleam/list
import gleam/option.{type Option}
import gleam/result
import sqlight.{type Error, exec, query, text}

pub fn init(conn) -> Result(Nil, Error) {
  let sql =
    "
    create table cache (
      key text primary key not null,
      value text
    )
    "
  exec(sql, conn)
}

pub fn insert(conn, key, value) -> Result(Nil, Error) {
  let sql = "insert or replace into cache (key, value) values (?, ?)"
  let params = [text(key), text(value)]
  result.map(query(sql, conn, params, dynamic.dynamic), fn(_) { Nil })
}

pub fn get(conn, key) -> Result(Option(String), Error) {
  let sql = "select value from cache where key = ?"
  use results <- result.map(query(
    sql,
    conn,
    [text(key)],
    dynamic.element(0, dynamic.string),
  ))
  option.from_result(list.first(results))
}
