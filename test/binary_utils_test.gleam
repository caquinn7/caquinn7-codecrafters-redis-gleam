import binary_utils
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn binary_to_int_test() {
  <<"123":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_ok
  |> should.equal(123)
}

pub fn binary_to_int_negative_int_test() {
  <<"-123":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_ok
  |> should.equal(-123)
}

pub fn binary_to_int_not_an_int_test() {
  <<"abc":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}

pub fn binary_to_int_letters_and_numbers_test() {
  <<"123abc":utf8>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}

pub fn binary_to_int_empty_test() {
  <<>>
  |> binary_utils.binary_to_int
  |> should.be_error
  |> should.equal(Nil)
}
