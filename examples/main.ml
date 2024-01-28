open Riot

let handler channel_name msg =
  Format.printf "#%s: %S\n%!" channel_name (Redito.serialize_message msg)
;;

let () =
  run
  @@ fun () ->
  let _ = Result.get_ok @@ Logger.start () in
  Logger.set_log_level (Some Debug);
  let uri = Uri.of_string "redis://127.0.0.1" in
  let pid = Result.get_ok @@ Redito.start_link uri in
  ignore @@ Redito.subscribe ~pid (handler "jojo") "jojo";
  ignore @@ Redito.subscribe ~pid (handler "mob_psycho") "mob_psycho";
  ignore @@ Redito.set ~opts:[ `EX 5 ] ~pid "name" "Mob Psycho";
  wait_pids [ pid ]
;;
