open Riot

module Logger = Logger.Make (struct
    let namespace = [ "redito.plumbing" ]
  end)

let debug = Logger.debug

type message =
  [ `Array of message list
  | `BulkString of string
  | `Integer of int
  | `NullString
  | `SimpleError of string
  | `SimpleString of string
  | `BigNumber of int
  | `Bool of bool
  | `Null
  ]

type connection =
  { reader : Net.Socket.stream_socket IO.Reader.t
  ; writer : Net.Socket.stream_socket IO.Writer.t
  }

module Parser = struct
  open Angstrom

  let is_eol = function
    | '\r' | '\n' -> true
    | _ -> false
  ;;

  let is_digit = function
    | '0' .. '9' -> true
    | _ -> false
  ;;

  let digits = take_while1 is_digit >>| int_of_string
  let eol = string "\r\n"

  let sign =
    let plus = char '+' *> return `Pos in
    let minus = char '-' *> return `Neg in
    let sign_to_int = function
      | `Pos -> 1
      | `Neg -> -1
    in
    plus <|> minus >>| sign_to_int
  ;;

  let integer =
    let sign_and_n = return (fun card n -> card * n) in
    sign_and_n
    <*> char ':' *> option 1 sign
    <*> (digits <* eol)
    >>= fun n -> return @@ `Integer n
  ;;

  let simple_error = char '-' *> take_till is_eol >>= fun e -> return @@ `SimpleError e
  let simple_string = char '+' *> take_till is_eol >>= fun s -> return @@ `SimpleString s

  let bulk_string =
    let len_opt = char '$' *> (digits >>| Option.some <|> string "-1" *> return None) in
    let len = len_opt <* eol in
    len
    >>= function
    | Some n -> take n <* eol >>= fun s -> return @@ `BulkString s
    | None -> return `NullString
  ;;

  let array self =
    let len = char '*' *> digits <* eol in
    len >>= fun c -> count c self >>= fun l -> return (`Array (List.rev l))
  ;;

  let null = string "_\r\n" *> return `Null

  let boolean =
    let true_p = char 't' *> return (`Bool true) in
    let false_p = char 't' *> return (`Bool false) in
    char '#' *> (true_p <|> false_p)
  ;;

  let big_number =
    return (fun c n -> c * n)
    <*> char '(' *> sign
    <*> digits
    <* eol
    >>= fun n -> return @@ `BigNumber n
  ;;

  let p =
    fix
    @@ fun self ->
    simple_string
    <|> simple_error
    <|> bulk_string
    <|> integer
    <|> array self
    <|> null
    <|> boolean
    <|> big_number
  ;;
end
[@@warning "-20..70"]

let rec serialize_message : message -> string = function
  | `NullString -> "$-1\r\n"
  | `BulkString string ->
    let len = String.length string in
    Format.sprintf "$%d\r\n%s\r\n" len string
  | `Integer int ->
    if int < 0 then Format.sprintf ":-%d\r\n" int else Format.sprintf ":+%d\n" int
  | `BigNumber int ->
    if int < 0 then Format.sprintf ":-%d\r\n" int else Format.sprintf ":+%d\n" int
  | `SimpleError string -> Format.sprintf "+%s\r\n" string
  | `Bool true -> "#t\r\n"
  | `Bool false -> "#f\r\n"
  | `Null -> "_\r\n"
  | `SimpleString string -> Format.sprintf "-%s\r\n" string
  | `Array el ->
    let len, elements =
      List.fold_left
        (fun (len, elements) v -> len + 1, elements ^ serialize_message v)
        (0, "")
        el
    in
    Format.sprintf "*%d\r\n%s" len elements
;;

let ( let* ) = Result.bind

let parse_redis_reply r () =
  debug (fun m -> m "Parsing reply");
  let rec helper state =
    match state with
    | Angstrom.Buffered.Done (_, v) -> Ok v
    | Angstrom.Buffered.Partial continue ->
      let* str = Bytestring.with_bytes (fun buf -> IO.read r buf) in
      helper @@ continue @@ `String (Bytestring.to_string str)
    | Angstrom.Buffered.Fail _ -> Error `Response_parsing_error
  in
  let state = Angstrom.Buffered.parse Parser.p in
  helper state
;;

(* TODO: Enviar um HELLO para fazer o handshake. *)
let connect uri () =
  match Uri.scheme uri with
  | Some "redis" ->
    let addr = Result.get_ok @@ Net.Addr.of_uri uri in
    let base = Result.get_ok @@ Net.Tcp_stream.connect addr in
    { reader = Net.Tcp_stream.to_reader base; writer = Net.Tcp_stream.to_writer base }
  | _ -> failwith "TODO: Implement rediss"
;;
