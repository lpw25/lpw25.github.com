--- 
layout: post 
title: An alternative to camlp4 - Part 2
tags: ["wg:camlp4"]
--- 

In my [previous blog post](/2013/01/23/camlp4-alternative-part-1.html) I
discussed how we might use AST transformers, attributes and quotations as a
simpler alternative to camlp4. While AST transformers are much simpler to use
than camlp4 they still require knowledge of the OCaml syntax tree, and they are
still implemented outside of the language as preprocessors.

In this post I'll explore how to implement extensions:

* within the language itself without external preprocessors
* without the need for detailed knowledge of the OCaml syntax tree

By including these extensions in the language itself the increasing number of
tools being built to support OCaml (e.g. typerex) can handle them directly. For
instance, IDEs could show the expansions of quotations by using the information
in ".cmt" files.

I will start with quotations, which can be implemented without any knowledge of
the OCaml syntax tree, and then expand my proposal to include other kinds of
extension.

Since my previous post, there has been a lot of discussion on
[wg-camlp4@lists.ocaml.org](http://lists.ocaml.org/listinfo/wg-camlp4) about
possible syntaxes for quotations and attributes and other kinds of extension. In
keeping with those ongoing discussions, I will use `{:id { string }}` as the
syntax for quotations (which transform a string into an AST node) and `(:id
expr)` as the syntax for extensions that transform an OCaml expression into an
AST node.

Note that the proposals in this post are more long-term than the "ppx" solution
discussed in the previous post. Moving an extension from ppx to the mechanism
described in this post would require only minimal work. So in the short/medium
term extension authors should implement their extensions using ppx.

#### Quotations ####

A quotation is simply a function which takes a string and returns an AST
node. To provide built-in support we need to, for every quotation `{:foo { bar
}}`:

1. find a function that corresponds to `foo`
2. apply it to the string " bar " 
3. copy the resulting AST node in place of the original quotation

##### Quotations in modules #####

We might want to find the function corresponding to quotation `foo` by simply
looking in the current module, or one of the other modules in our environment,
for a function called `foo`. However there are a few problems with this simple
scheme:

1. The function we call must exist and be compiled before we can use it.
3. There is no clear separation between what is being executed at compile-time
   and what is being executed and run-time.

The first problem basically means that we can only use functions defined in
other files. The other problem is more subtle.

OCaml modules do not really exist at compile time. They are created at run-time,
and their creation encompasses the entire execution of the program. For example,
consider this simple module:

{% highlight ocaml %}
(* main.ml *)
let x = Printf.printf "Hello, world!\n"
{% endhighlight %}

To create the `Main` module, we must create its member `x`. Once the creation of
`Main` is finished the `printf` has been executed and the whole program has
completed. Now if we add a quotation function `foo` to this module:

{% highlight ocaml %}
(* main.ml *)
let x = Printf.printf "Hello, world!\n"

let keywords = Hashtbl.create 13
let foo str = (* Some expression using keywords *)
{% endhighlight %}

How do we distinguish between data such as `keywords` which are needed at
compile-time when the quotation is run, and data like `x` whose creation is
meant to drive the program at run-time? There is nothing explicit in the
definitions of `foo` or `keywords` that indicates that they are intended for
compile-time execution.

These problems are related to the fact that OCaml is an impure language. Any
expression (including module definitions) can have side-effects, and the
run-time behaviour of the program is simply the combination of all these
side-effects. This makes it difficult to separate the side-effects that are
related to a quotation from the side-effects that are part of the program's
execution.

Despite appearing alongside other functions in the program, `foo` must be
executed in a completely separate environment. Any side-effects (e.g. mutable
state, I/O) that are produced while creating and executing `foo` will be
completely separate from the side-effects of the other functions in its module.

##### Where can we put them? #####

If we don't want to put quotation functions in our modules, where should we put
them? The module system provides the only mechanism for referring to functions in
other files, how can we refer to functions which are not included in a module?

The answer to these questions comes from the idea of *namespaces*. Namespaces
are a way to give longer names to top-level modules without changing the
module's filename. They also allow these top-level modules to be grouped
together.

The details of proposals for namespaces vary on their details, but they
basically allow you to take the module defined by a file "baz.ml" and refer to
it as "Bar.Baz". Here "Bar" is not a module (it cannot be used as the argument
to a functor) but a namespace.

Namespaces seem likely to be included in OCaml in the near future,
and they provide a convenient way to refer to quotations without putting
quotations within modules.

The idea is to write quotations in a "bar.mlq" file (compiled to
"bar.cmq"). These quotations would then be placed in the namespace "Bar".

Quotations would be defined with a syntax like:

{% highlight ocaml %}
(* bar.mlq *)
quotation foo str = ...
{% endhighlight %}

This could then be used with the syntax:

{% highlight ocaml %}
{:Bar.foo{ some text }}
{% endhighlight %}

This will make it easy for quotations to be provided by libraries. So that the
following code would perfectly possible:

{% highlight ocaml %}
{:Core.Web.html{<body> Hello, world! </body>}}
{% endhighlight %}

##### Quotations in different contexts #####

So far, we have ignored the question of what type is used to represent an AST
node. The standard library would need to provide such a type so that quotations
could be written without linking to compiler-libs. There would also need to be
different types for different kinds of AST nodes. We do not want a quotation
used as an expression returning an AST node that represents a pattern

However, we also might want to create quotations that can be used as both
expressions and patterns. This means that the quotation must return a different
type depending on where it is used.

The solution to this issue is to give quotations the type `'a ctx -> string ->
'a`.  The `ctx` type would be a GADT that described what context a quotation was
being used from. It could also contain other information about the context, such
as its location in the source file.

##### Building Quotations #####

Creating the quotation functions requires some facility for creating AST
nodes. For this purpose, the standard library would include special quotations,
for example: `{:Ast.expr{ x + 3 }}`. These quotations would be implemented
directly using the compiler's lexer and parser.

It would also be useful (especially for handling anti-quotations) to allow
quotations to be built from other quotations. For this we could provide another
syntax: `{:foo}` that would refer directly to the quotation function
`foo`. Obviously, this syntax would only be allowed within ".mlq" files.

#### Other extensions ####

This system could easily be extended to other kinds of extension. Rather than
declaring "quotations" with type `'a ctx -> string -> 'a`, we could declare
*templates* with type `'a ctx -> 'a`. The context would contain the arguments to
the template (a string for quotations, an AST node for other templates).

So a template declared as:

{% highlight ocaml %}
(* bar.mlq *)
template foo str = ...
{% endhighlight %}

could be used with the syntax:

{% highlight ocaml %}
(:Bar.foo expr)
{% endhighlight %}

Unlike quotations, more general templates must be able to interpret AST nodes
themselves. This means we must provide mechanisms for handling AST nodes. For
this purpose, the standard library would include a simpler version of the
`AstMapper` module that is in compiler-libs.

We could also allow the AST quotations (e.g. `Ast.expr) to be used as
patterns. This approach can be a bit fragile because syntactic sugar can cause a
pattern to match ASTs that it was not expected to match. However, for matching
simple AST nodes it is probably fairly robust.

#### Summary ####

1. Allow extensions to be written as OCaml functions within ".mlq" files.
2. Refer to these functions by attaching them directly to namespaces.
3. Require these functions to have type `'a ctx -> 'a`, where `ctx` includes a
   GADT describing the context that the extension has been used in.
4. Provide AST quotations in the standard library (e.g. `{:Ast.expr{ x + 3 }}`)
   which use the compiler's own lexer and parser.