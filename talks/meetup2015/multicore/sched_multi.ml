
(* Naive work-stealing parallel scheduler *)

module State = struct

  type 'a queue =
    { mutex: Domain.mutex;
      mutable values: 'a list; }

  type 'a t =
    { domains : int;
      stealing_mutex : Domain.mutex;
      mutable stealing : int;
      queues : 'a queue array; }

  let create domains =
    let stealing_mutex = Domain.mutex () in
    let stealing = 0 in
    let queues =
      Array.init domains
        (fun _ ->
           { mutex = Domain.mutex ();
             values = []; })
    in
      { domains; stealing_mutex; stealing; queues }

  let push state self k =
    Domain.lock state.queues.(self).mutex;
    state.queues.(self).values <- k :: state.queues.(self).values;
    Domain.unlock state.queues.(self).mutex

  let pop state self =
    Domain.lock state.queues.(self).mutex;
    let k =
      match state.queues.(self).values with
      | k :: ks ->
        state.queues.(self).values <- ks;
        Some k
      | [] ->
        Domain.lock state.stealing_mutex;
        state.stealing <- state.stealing + 1;
        Domain.unlock state.stealing_mutex;
        None
    in
    Domain.unlock state.queues.(self).mutex;
    k

  let finished state =
    Domain.lock state.stealing_mutex;
    let res = state.stealing = state.domains in
    Domain.unlock state.stealing_mutex;
    res

  let steal state self =
    let res = ref None in
    begin
      try
        while not (finished state) do
          for i = 0 to state.domains - 1 do
            if i <> self then begin
              Domain.lock state.queues.(i).mutex;
              match List.rev state.queues.(i).values with
              | k :: ks ->
                state.queues.(i).values <- List.rev ks;
                Domain.lock state.stealing_mutex;
                state.stealing <- state.stealing - 1;
                Domain.unlock state.stealing_mutex;
                res := Some k;
                Domain.unlock state.queues.(i).mutex;
                raise Exit;
              | [] ->
                Domain.unlock state.queues.(i).mutex;
            end
          done;
        done;
      with Exit -> ()
    end;
    !res
end


effect Fork : (unit -> unit) -> unit
effect Yield : unit

let enqueue state k =
  let self = Domain.self () in
  State.push state self k

let dequeue state =
  let self = Domain.self () in
  match State.pop state self with
  | Some k -> continue k ()
  | None ->
      match State.steal state self with
      | Some k ->
          continue k ();
      | None -> ()

let rec spawn state f =
  match f () with
  | () -> dequeue state
  | effect Yield k ->
      enqueue state k;
      dequeue state
  | effect (Fork f) k ->
      enqueue state k;
      spawn state f

let domains = 4

let run main =
  let state = State.create domains in
  Gc.minor ();
  for i = 1 to domains - 1 do
    Domain.spawn (fun () -> dequeue state)
  done;
  spawn state main

let fork f = perform (Fork f)

let yield () = perform Yield
