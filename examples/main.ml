open Riot

let handler _ = Format.printf "Got a message\n%!"

let () =
  run
  @@ fun () ->
  let _ = Result.get_ok @@ Logger.start () in
  Logger.set_log_level (Some Trace);
  let uri = Uri.of_string "redis://127.0.0.1" in
  let pid = Result.get_ok @@ Redito.start_link uri in
  ignore @@ Redito.subscribe ~pid handler "jojo";
  ignore @@ Redito.subscribe ~pid handler "mob_psycho";
  ignore @@ Redito.set ~opts:[ `EX 5 ] ~pid "name" "Mob Psycho";
  wait_pids [ pid ]
;;