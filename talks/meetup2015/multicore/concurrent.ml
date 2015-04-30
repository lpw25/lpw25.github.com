
(* Demonstrate the concurrent scheduler *)

let log = Printf.printf

let rec f id depth =
  log "Starting number %i\n%!" id;
  if depth > 0 then begin
    log "Forking number %i\n%!" (id * 2);
    Sched.fork (fun () -> f (id * 2) (depth - 1));
    log "Forking number %i\n%!" (id * 3);
    Sched.fork (fun () -> f (id * 3) (depth - 1))
  end else begin
    log "Yielding in number %i\n%!" id;
    Sched.yield ();
    log "Resumed number %i\n%!" id;
  end;
  log "Finishing number %i\n%!" id

let () = Sched.run (fun () -> f 1 3)
