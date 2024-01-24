open Riot
module GenServer = Gen_server

type connection = Plumbing.connection
type message = Plumbing.message

let connect = Plumbing.connect

module Plumbing = struct
  include Plumbing

  let send_command ~(conn : Plumbing.connection) cmd =
    let writer = conn.writer in
    let reader = conn.reader in
    let serialized_msg = Plumbing.serialize_message cmd in
    match IO.write_all ~buf:(Bytes.of_string serialized_msg) writer with
    | Ok () -> Plumbing.parse_redis_reply reader ()
    | Error _ as err -> err
  ;;

  let[@warning "-32"] lpush ~conn key element =
    send_command ~conn (`Array [ `BulkString "LPUSH"; `BulkString key; element ])
  ;;

  let[@warning "-32"] lrange ~conn key min max =
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

  let[@warning "-32"] lpop ~conn ?(count = 1) key =
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
end

module Server = struct
  type _ GenServer.req +=
    | Set : string * string * [ `EX of int ] list -> bool GenServer.req
    | Subscribe : string * (message -> unit) -> Pid.t GenServer.req
    | TTL : string -> int option GenServer.req

  type args = Uri.t

  module S : GenServer.Impl with type args = args = struct
    type args = Uri.t

    (* TODO: Remover conexão daqui quando tiver pool *)
    type state =
      { conn : connection
      ; uri : Uri.t
      }

    let init uri : state GenServer.init_result = Ok { conn = connect uri (); uri }

    let handle_call : type res. res GenServer.req -> Pid.t -> state -> res * state =
      fun req _from { conn; uri } ->
      match req with
      | Set (key, value, opts) ->
        let has_set = Plumbing.set ~opts ~conn key value in
        has_set, { conn; uri }
      | Subscribe (channel, f) ->
        let pid =
          spawn_link
          @@ fun () ->
          (* TODO: Adicionar uma pool de conexões *)
          (* NOTE: Isso aqui parece uma péssima ideia,
             já que podemos iniciar _n_ processos, o que acarretaria em _n_ conexões
             com o Redis, podendo sobrecarregar o nosso servidor.
             Mas vamos fazer assim por enquanto.

             É possível também enviar as mensagens através da conexão ocupada,
             supondo que ela está ocupada porque entramos no subscribe mode.
          *)
          let new_conn = connect uri () in
          Plumbing.subscribe ~conn:new_conn ~f channel
        in
        pid, { conn; uri }
      | TTL key ->
        let timeout = Plumbing.ttl ~conn key in
        timeout, { conn; uri }
    [@@warning "-8"]
    ;;

    let handle_info _ _ = ()
  end
end

let start_link uri = GenServer.start_link (module Server.S) uri
let set ?(opts = []) ~pid key value = GenServer.call pid Server.(Set (key, value, opts))

let subscribe ~pid handler channel =
  GenServer.call pid Server.(Subscribe (channel, handler))
;;

let ttl ~pid key = GenServer.call pid Server.(TTL key)
