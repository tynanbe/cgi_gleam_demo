import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import gleam/http/request
import gleam/http/response.{Response}
import cgi
import envoy
import glance
import glance_printer

/// Echoes a `Request`.
///
pub fn main() -> Nil {
  use request <- cgi.handle_request

  // Use a variable from the environment
  let hi = case envoy.get("SERVER_SOFTWARE") {
    Ok(server) -> "Hi from Gleam on " <> server
    _or -> "Hi from Gleam"
  }

  // Use a variable from the query string
  let is_plain = case request.query {
    Some(query) ->
      query
      |> uri.parse_query
      |> result.map(with: list.any(_, satisfying: fn(x) {
        pair.map_first(of: x, with: string.lowercase) == #("plain", "")
      }))
      |> result.unwrap(or: False)
    None -> False
  }

  // Convert the request body to a string
  // Format the request record for pretty printing
  let request =
    request
    |> request.set_body(
      request.body
      |> bit_array.to_string
      |> result.unwrap(or: ""),
    )
    |> string.inspect
    |> gleam_format

  // Prepare the response
  Response(
    // OK
    status: 200,
    headers: [#("content-type", "text/plain")],
    body: case is_plain {
      True -> request
      False -> hi <> "! You sent me this:\n\n" <> request <> "\n" <> bye()
    },
  )
}

/// Formats Gleam data for pretty printing.
///
fn gleam_format(data: String) -> String {
  let begin = "fn main() {"
  let end = "}"

  let is_data = fn(line) { line != begin && line != end }
  let deindent = string.drop_left(from: _, up_to: 2)

  let result = {
    use module <- result.map(glance.module(begin <> data <> end))
    module
    |> glance_printer.print
    |> string.split(on: "\n")
    |> list.filter(keeping: is_data)
    |> list.map(with: deindent)
    |> string.join(with: "\n")
  }

  case result {
    Ok(data) -> data
    _or -> data
  }
}

/// Returns a random parting message.
///
fn bye() -> String {
  let adjectives = [
    "awesome", "blessed", "excellent", "fantastic", "fine", "great", "inspired",
    "lovely", "outstanding", "phenomenal", "pleasant", "stellar", "wonderful",
  ]
  let max = list.length(of: adjectives)

  let assert Ok(adjective) =
    max
    |> int.random
    |> list.at(in: adjectives)

  let some_kind_of = case adjective {
    "a" <> _ | "e" <> _ | "i" <> _ | "o" <> _ | "u" <> _ -> "an " <> adjective
    _or -> "a " <> adjective
  }

  "Have " <> some_kind_of <> " day~\n"
}
