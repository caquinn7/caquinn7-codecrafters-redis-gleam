/// milliseconds since the epoch
pub fn now() {
  system_time(1000)
}

@external(erlang, "os", "system_time/1")
fn system_time(unit: Int) -> Int
