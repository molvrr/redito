module GenServer = Riot.Gen_server

type connection
type message

val connect : Uri.t -> unit -> Plumbing.connection
val serialize_message : message -> string

module Server : sig
  type _ GenServer.req +=
    | Set : string * string * [ `EX of int ] list -> bool GenServer.req
    | Subscribe : string * (message -> unit) -> Riot.Pid.t GenServer.req
    | TTL : string -> int option GenServer.req

  type args = Uri.t

  module S : sig
    type args = Uri.t
    type state

    val init : args -> state GenServer.init_result
    val handle_call : 'res GenServer.req -> Riot.Pid.t -> state -> 'res * state
    val handle_info : Riot.Message.t -> state -> unit
  end
end

val start_link : Server.S.args -> (Riot.Pid.t, [> `Exn of exn ]) result
val set : ?opts:[ `EX of int ] list -> pid:Riot.Pid.t -> string -> string -> bool
val subscribe : pid:Riot.Pid.t -> (message -> unit) -> string -> Riot.Pid.t
val ttl : pid:Riot.Pid.t -> string -> int option
