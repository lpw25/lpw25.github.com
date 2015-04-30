
(* Basic effects example - code itself is nonsense *)

effect Foo : int
effect Bar : int

let f (type a) (e : a eff) (k : (a, 'b) continuation) =
  match e with
  | Foo -> (continue k 5) * 7
  | Bar -> (continue k 11) * 13
  | _ -> assert false

let x =
  match (perform Foo) * (perform Bar) with
  | x -> x * 2
  | exception _ -> 3
  | effect Foo k -> (continue k 5) * 7
  | effect Bar k -> (continue k 11) * 13
