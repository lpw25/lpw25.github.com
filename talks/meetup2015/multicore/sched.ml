
(* Simple round-robin concurrent scheduler *)

effect Fork : (unit -> unit) -> unit
effect Yield: unit

let run main =
  (* Run queue handling *)
  let run_q = Queue.create () in
  let enqueue k =
    Queue.push k run_q
  in
  let rec dequeue () =
    if Queue.is_empty run_q then ()
    else continue (Queue.pop run_q) ()
  in
  let rec spawn f =
    match f () with
    | () -> dequeue ()
    | effect Yield k ->
        enqueue k;
        dequeue ()
    | effect (Fork f) k ->
        enqueue k;
        spawn f
  in
  spawn main

let fork f = perform (Fork f)

let yield () = perform Yield
