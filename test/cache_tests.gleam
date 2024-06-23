import cache.{Item}
import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn cache_get_keys_test() {
  let cache = cache.init()
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
  cache.init()
  |> cache.get_keys
  |> should.equal([])
}
