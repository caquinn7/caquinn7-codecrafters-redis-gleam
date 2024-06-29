import cache.{Item}
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import rdb.{Database, Expiry, Milliseconds, Rdb, Record, Seconds}

pub fn main() {
  gleeunit.main()
}

pub fn cache_get_keys_test() {
  let cache = cache.new()
  cache.set(cache, <<"key1":utf8>>, Item(<<"val1":utf8>>, None))
  cache.set(cache, <<"key2":utf8>>, Item(<<"val2":utf8>>, None))

  let keys = cache.get_keys(cache)

  list.length(keys)
  |> should.equal(2)

  list.contains(keys, <<"key1":utf8>>)
  |> should.equal(True)

  list.contains(keys, <<"key2":utf8>>)
  |> should.equal(True)
}

pub fn cache_get_keys_empty_cache_test() {
  cache.new()
  |> cache.get_keys
  |> should.equal([])
}

pub fn cache_from_rdb_test() {
  let #(key1, val1) = #(<<"key1":utf8>>, <<"val1":utf8>>)
  let #(key2, val2) = #(<<"key2":utf8>>, <<"val2":utf8>>)
  let #(key3, val3) = #(<<"key3":utf8>>, <<"val3":utf8>>)
  let expiry_seconds = 1_719_176_618

  let rdb =
    Rdb(
      1,
      [],
      [
        Database(0, [Record(key1, val1, None)]),
        Database(1, [
          Record(key2, val2, Some(Expiry(expiry_seconds, Seconds))),
          Record(key3, val3, Some(Expiry(expiry_seconds * 1000, Milliseconds))),
        ]),
      ],
      <<>>,
    )

  let cache = cache.from_rdb(rdb)

  cache
  |> cache.get_keys
  |> list.length
  |> should.equal(3)

  cache.get(cache, key1)
  |> should.be_ok
  |> should.equal(Item(val1, None))

  cache.get(cache, key2)
  |> should.be_ok
  |> should.equal(Item(val2, Some(expiry_seconds * 1000)))

  cache.get(cache, key3)
  |> should.be_ok
  |> should.equal(Item(val3, Some(expiry_seconds * 1000)))
}
