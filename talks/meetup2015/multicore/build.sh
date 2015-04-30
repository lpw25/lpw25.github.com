#!/bin/bash

OCAMLC=ocamlc

$OCAMLC -c sched.mli
$OCAMLC -c sched.ml

$OCAMLC -c concurrent.ml
$OCAMLC -o concurrent sched.cmo concurrent.cmo

$OCAMLC -c sched_multi.mli
$OCAMLC -c sched_multi.ml

$OCAMLC -c quicksort_single.ml
$OCAMLC -o quicksort_single quicksort_single.cmo

$OCAMLC -c quicksort_multi.ml
$OCAMLC -o quicksort_multi sched_multi.cmo quicksort_multi.cmo
