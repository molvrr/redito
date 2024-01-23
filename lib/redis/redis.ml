open Riot
module Plumbing = Plumbing

type connection = Plumbing.connection
type message = Plumbing.message

let connect = Plumbing.connect

(* TODO: Colocar isso dentro do Plumbing *)
let send_command ~(conn : Plumbing.connection) cmd =
  let writer = conn.writer in
  let reader = conn.reader in
  let serialized_msg = Plumbing.serialize_message cmd in
  match IO.write_all ~buf:(Bytes.of_string serialized_msg) writer with
  | Ok () -> Plumbing.parse_redis_reply reader ()
  | Error _ as err -> err
;;

let lpush ~conn key element =
  send_command ~conn (`Array [ `BulkString "LPUSH"; `BulkString key; element ])
;;

let lrange ~conn key min max =
  let cmd =
    `Array
      [ `BulkString "LRANGE"
      ; `BulkString key
      ; `BulkString (string_of_int min)
      ; `BulkString (string_of_int max)
      ]
  in
  let res = send_command ~conn cmd in
  match res with
  | Ok (`Array l) -> Ok l
  | Ok _ -> Error `No_info
  | Error _ as err -> err
;;

let lpop ~conn ?(count = 1) key =
  let cmd =
    `Array [ `BulkString "LPOP"; `BulkString key; `BulkString (string_of_int count) ]
  in
  let res = send_command ~conn cmd in
  match res with
  | Ok v -> Some v
  | Error _ -> None
;;

let ttl ~conn key =
  let cmd = `Array [ `BulkString "TTL"; `BulkString key ] in
  let res = send_command ~conn cmd in
  match res with
  | Ok (`Integer -1) -> None
  | Ok (`Integer -2) -> None
  | Ok (`Integer n) -> Some n
  | _ -> None
;;

let set_opt_to_redis = function
  | `EX n -> [ `BulkString "EX"; `BulkString (string_of_int n) ]
;;

let set ~conn ?(opts = []) key value =
  let cmd = [ `BulkString "SET"; `BulkString key; `BulkString value ] in
  let cmd_opts = List.concat @@ List.map set_opt_to_redis opts in
  let cmd = `Array (cmd @ cmd_opts) in
  let res = send_command ~conn cmd in
  match res with
  | Ok (`SimpleError _) -> false
  | Ok _ -> true
  | Error _ -> false
;;

(* TODO: Aceitar mais de um canal *)
let subscribe ~conn ~f chan =
  let rec helper f () =
    let data = Plumbing.parse_redis_reply conn.Plumbing.reader () in
    match data with
    | Ok (`Array [ str; `BulkString c; `BulkString "message" ]) when String.equal c chan
      ->
      Logger.debug (fun m -> m "#%s: %S" chan (Plumbing.serialize_message str));
      f str;
      helper f ()
    | Ok msg ->
      Logger.debug (fun m -> m "#%s: %S" chan (Plumbing.serialize_message msg));
      helper f ()
    | Error _ -> ()
  in
  let cmd = `Array [ `BulkString "SUBSCRIBE"; `BulkString chan ] in
  let msg = send_command ~conn cmd in
  match msg with
  | Ok (`Array [ `Integer 1; `BulkString c; `BulkString "subscribe" ])
    when String.equal c chan ->
    Logger.debug (fun m -> m "Subscribed successfully to channel %s" chan);
    helper f ()
  | Ok msg -> Logger.debug (fun m -> m "%s" @@ Plumbing.serialize_message msg)
  | Error _ -> Logger.error (fun m -> m "Error subscribing to channel %s" chan)
;;
