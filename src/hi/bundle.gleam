import gleam
import gleam/io
import gleam/result
import gleam/string
import esgleam.{bundle, entry, raw, target}
import filepath as path
import simplifile.{type FileError} as fs

/// A `Result` alias type for filesystem operations.
///
type Result(a) =
  gleam.Result(a, FileError)

/// Writes a CGI script.
///
pub fn main() -> Result(Nil) {
  let out_dir = "dist"
  let name = "hi"

  let file = path.join(out_dir, name)

  use <- step({
    let _ = fs.delete(out_dir)
    esgleam.new(out_dir)
    |> entry(name <> ".gleam")
    |> target("esnext")
    |> raw("--platform=node")
    |> bundle
  })

  use <- step(fs.rename_file(at: file <> ".js", to: file))
  use <- step(fs.set_permissions_octal(file, to: 0o755))

  use content <- from_step(fs.read(file))
  let content =
    shebang(
      // `env -S` allows passing multiple arguments in shebangs
      with: "/usr/bin/env -S sh -c",
      run: [
        // Deno panics without a home directory, e.g. running as `nobody`
        "HOME=/tmp",
        // `exec` prevents zombies
        "exec deno run",
        // CGI scripts read environment variables for request metadata
        "--allow-env",
        // CGI scripts read requests' bodies from stdin
        "--allow-read=/dev/stdin",
        // CGI scripts write responses to stdout
        "--allow-write=/dev/stdout",
        // Network access is needed to import external modules
        "--allow-net",
        // Run this JavaScript module
        name,
      ],
    )
    <> content
    <> "main();\n"

  use <- step(fs.write(content, to: file))
  Ok(Nil)
}

/// Returns a shebang for use as the first line in a script.
///
fn shebang(with shell: String, run script: List(String)) -> String {
  "#!" <> shell <> " '" <> string.join(script, with: " ") <> "'\n"
}

/// Wraps `from_step`, but drops the return value.
///
fn step(result: Result(a), then f: fn() -> Result(Nil)) -> Result(Nil) {
  use _ <- from_step(result)
  f()
}

/// Tries a filesystem operation and prints any `FileError` that results.
///
fn from_step(result: Result(a), then f: fn(a) -> Result(b)) -> Result(b) {
  case result {
    Error(_) ->
      { "\u{1b}[1;31m" <> string.inspect(result) <> "\u{1b}[0m\u{1b}[K" }
      |> io.println_error
    _or -> Nil
  }

  result.try(result, apply: f)
}
