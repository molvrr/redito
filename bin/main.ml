open Riot
module GenServer = Gen_server

type _ GenServer.req +=
  | Set : string * string -> bool GenServer.req
  | Subscribe : string * (Redis.message -> unit) -> Pid.t GenServer.req

type args = Uri.t

module Redito = struct
  module Server : GenServer.Impl with type args = args = struct
    type args = Uri.t

    (* TODO: Remover conexão daqui quando tiver pool *)
    type state =
      { conn : Redis.connection
      ; uri : Uri.t
      }

    let init uri : state GenServer.init_result = Ok { conn = Redis.connect uri (); uri }

    let handle_call : type res. res GenServer.req -> Pid.t -> state -> res * state =
      fun req _from { conn; uri } ->
      match req with
      | Set (key, value) ->
        let has_set = Redis.set ~conn key value in
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
             supondo que ela está ocupada por que entramos no subscribe mode.
          *)
          let new_conn = Redis.connect uri () in
          Redis.subscribe ~conn:new_conn ~f channel
        in
        pid, { conn; uri }
    [@@warning "-8"]
    ;;

    let handle_info _ _ = ()
  end

  let start_link uri = GenServer.start_link (module Server) uri
  let set pid key value = GenServer.call pid (Set (key, value))
  let subscribe ~handler pid channel = GenServer.call pid (Subscribe (channel, handler))
end

let handler _ = Format.printf "Got a message\n%!"

let () =
  run
  @@ fun () ->
  let _ = Result.get_ok @@ Logger.start () in
  Logger.set_log_level (Some Debug);
  let uri = Uri.of_string "redis://127.0.0.1" in
  let pid = Result.get_ok @@ Redito.start_link uri in
  ignore @@ Redito.subscribe ~handler pid "jojo";
  ignore @@ Redito.subscribe ~handler pid "mob_psycho";
  ignore @@ Redito.set pid "name" "Mob Psycho";
  wait_pids [ pid ]
;;
