











module type Show = sig
  type t
  val show : t -> string
end



let show (implicit S : Show) x =
  S.show x

























implicit module ShowInt = struct
  type t = int
  let show = string_of_int
end



implicit module ShowFloat = struct
  type t = float
  let show = string_of_float
end

















show 4;;



show 4.6;;



show "foo";;

















(* Implicit parameters *)

let print (implicit S : Show) (x : S.t) =
    print_endline (show x)



print 4.5



















let print x =
    print_string (show x);;





















(* Implicit scope *)

type foo = Foo

module M = struct
  implicit module ShowFoo = struct
    type t = foo
    let show Foo = "Foo"
  end
end

let () = print Foo (* Error *)



























(* Implicit functors *)

implicit functor ShowList (S:Show) = struct
  type t = S.t list
  let show l =
    let sl = List.map S.show l in
    "[" ^ String.concat "; " sl ^ "]"
end

show [1; 2; 3];;

show [[5.5]; [1.2; 3.4]];;















(* Ambuguity *)

implicit module ShowInt1 = struct
  type t = int
  let show = string_of_int
end

implicit module ShowInt2 = struct
  type t = int
  let show _ = "An int"
end

show 9;;

















(* Explicit implicit arguments *)

show (implicit ShowInt1) 9;;
























(* Constructor classes (higher-kinded types) *)

module type Monad = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
end

let return (implicit M : Monad) x =
  M.return x

let (>>=) (implicit M : Monad) m k =
  M.bind m k






















implicit module MonadList = struct
  type 'a t = 'a list
  let return x = [x]
  let bind m k =
    List.fold_right
      (fun x acc -> k x @ acc)
      m []
end

implicit module MonadOption = struct
  type 'a t = 'a option
  let return x = Some x
  let bind m k =
    match m with
    | None -> None
    | Some x -> k x
end



















[5; 6; 7] >>= fun x -> return (x + 1);;



Some 5.5 >>= fun x -> return (x +. 1.0);;






















let when_ (implicit M : Monad) p s : unit M.t =
  if p then s else return ()



when_ false [(); (); ()];;



when_ true None;;


















(* Associated types (existentials) *)

module type Graph = sig
  type t
  type vertex
  type edge
  val empty : t
  val add_edge : t -> vertex -> vertex -> t
end

let empty (implicit G : Graph) () =
  G.empty

let add_edge (implicit G : Graph) g f t =
  G.add_edge g f t




















implicit module IntGraph = struct
  type t = (int * int) list
  type vertex = int
  type edge = int * int
  let empty = []
  let add_edge t v1 v2 =
    (v1, v2) :: (v2, v1) :: t
end





























module StringMap =
  Map.Make(struct
             type t = string
             let compare = compare
           end)


implicit module StringGraph = struct
    type t = string list StringMap.t
    type vertex = string
    type edge = string * string
    let empty = StringMap.empty
    let add_edge t v1 v2 =
     StringMap.add v1
      (v2 :: (try StringMap.find v1 t
              with Not_found -> []))
      (StringMap.add v2
        (v1 :: (try StringMap.find v2 t
                with Not_found -> []))
        t)
end




















(add_edge
   (add_edge (empty ()) 1 3)
   3 9)



(add_edge
   (add_edge (empty ()) "LDN" "NYC")
   "NYC" "HKG")














let my_graph (implicit G : Graph) (x : G.vertex)
             (y : G.vertex) (z : G.vertex) =
  add_edge
    (add_edge (empty ()) x y)
    y z;;


my_graph 1 3 9;;

my_graph "LDN" "NYC" "HKG"











