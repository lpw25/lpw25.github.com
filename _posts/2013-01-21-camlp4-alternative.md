--- 
layout: post 
title: An alternative to camlp4 
--- 
<div class="alert alert-error">
<button type="button" class="close" data-dismiss="alert">&times;</button>
This blog post is still under construction. Go Away!     
</div>

Since its creation camlp4 has proven to be a very useful tool. People have used
it to experiment with new features for OCaml, and to provide interesting
metaprogramming facilities. However, there is general agreement that camlp4 is
too powerful and complex for the applications that it is most commonly used for,
and there is a growing movement to provide a simpler alternative. In this post I
will discuss my thoughts on what needs to be done to provide such an
alternative.

I think that providing a real alternative to camlp4 involves two phases. The
first phase involves providing support to allow people with reasonable knowledge
of the OCaml grammar to write extensions to OCaml. These second phase involves
extending this support to allow general OCaml programmers to write extensions,
and to include such extensions within the language itself rather than as part of
a pre-processor.

### Phase one ###

Camlp4 works by producing preprocessors that parse an OCaml file and then output
a syntax tree directly into the compiler. Extensions are written by extending
the default OCaml parser and converting any new syntax tree nodes into existing
OCaml nodes. Most of the complexity in camlp4 comes from its extensible
grammars, which gives camlp4 the ability to extend the ocaml syntax
arbitrarily. However, most applications do not need this ability. A much simpler
alternative is to use *AST transformers* and *attributes*.

AST transformers are simply functions that perform transformations on the OCaml
syntax tree. These can already be implemented using the new "-ppx" command line
option that has been included on the OCaml development trunk by Alain
Frisch. This option accepts a program as an argument, and pipes the syntax tree
through that program after parsing and before type checking.

Attributes are places in the grammar where generic data can be attached to the
syntax tree. This data is simply ignored by the main OCaml compiler, but it can
used be AST transformers to control transformations. 

Before support for attributes can be added to the compiler decisions need to be
made about what kinds of attributes to support. There are two general kinds of
attribute: those whose data is valid OCaml syntax that is parsed by the OCaml
parser; and those whose data is arbitrary text that is parsed by the extension
implementation. The second kind of attribute is often called a quotation.

Personally I prefer quotations to the other kind of attribute, however there is
no reason that both cannot be supported by the compiler using different syntax.

From a fairly unscientific look at various uses of camlp4, I think that it is
important to support at least the following kinds of attribute:

* Simple named quotations for expressions, patterns and type expressions:
{% highlight ocaml %}
let x = <:Foo.foo < some random text >>
{% endhighlight %}
* Type constructor quotations:
{% highlight ocaml %}
let x: int %foo, int %bar( some random text)
{% endhighlight %}
* Type-conv style defintion attributes:
{% highlight ocaml %}
type t = 
{ x: int;
  y: int; }
with foo, bar( (* some valid expression *) )
{% endhighlight %}
* Annotating types with syntactically valid expressions:
{% highlight ocaml %}
let x: string @@ (* some valid expression *) = ()
{% endhighlight %}

Once support for these annotations is added to OCaml I think that the majority
of camlp4 applications could be easily converted into AST transformers. In order
to make this transition easy, work must also be done to provide tools for
manipulating OCaml's AST and to integrate the "-ppx" option into the many OCaml
build systems.

It would probably also be worthwhile trying to normalize some of the stranger
corners of the OCaml syntax tree. In particular representing all syntactic sugar
directly in the syntax tree. This will make writting AST transformers simpler
and more robust

### Phase two ###

While AST transformers are much simpler to use than camlp4 they still require
knowledge of the OCaml syntax tree, and they are still implemented outside of
the language as pre-processors. Where possible, it would be better if extensions
could be implemented within the language itself, and without the need for
knowledge of the OCaml syntax tree.

#### Run-time types ####

Some applications of camlp4 could be replaced by simple run-time types
support. Such support has been proposed
[before](http://www.lexifi.com/blog/runtime-types), and seems likely to be
included at some point. 

The most basic form of the idea is to have an abstract datatype `'a ty`, where
`t ty` represents the structure of type `t`. Values of type `ty` can be created
using expressions of the like:

{% highlight ocaml %} 
(type val int list) 
{% endhighlight %}

It would also be possible to allow the "type constructor quotations" suggested
in the previous section to be included within the `ty` type. For example:

{% highlight ocaml %} 
(type val int %print(ignore) option) 
{% endhighlight %}

Would include the strings "print" and "ignore" within the run-time type
representation.

#### Quotations ####

While quotation-based extensions can be implemented using AST transformers, they
could also be implemented within the language itself.

The idea is to allow quotations to be created like:

{% highlight ocaml %}
quotation foo ctx str = ...
{% endhighlight %}

These quotation functions would have type `'a ctx -> string -> 'a`. The `ctx`
type represents the context in which the quotation is being used
(e.g. expression, pattern, type expression). The 'a type variable would be the
type of AST node that is expected in that context. The context would also
include information such as the location of the quotation.

The quotation `foo` would be used using the syntax:

{% highlight ocaml %}
<:foo< some text >>
{% endhighlight %}

This would lookup the quotation with name foo, apply it to the string " some text ",
and then be replaced with the returned AST fragment.

In the top-level, this system works fine. However, there are two problems with
using these quotations with the compiler:
* The quotation must be compiled before it can be used.
* It is not clear to the user what happens to any "side-effects" produced during the running of
the quotation.

These problems make it very difficult to allow quotations within modules,
because modules may not be created until run time, and their creation can both
produce and depend on run-time side-effects.

The solution to this is to make it clear that the quotation must be compiled
before it is used, and that it will be executed separately from the rest of the
program at compile time. Within the language, this can be accomplished by saying
that quotations cannot be part of a module. So they cannot be put in a .ml file
and compiled. Instead, they could only be included in separate .mlq files. These
would be compiled into .cmq files, which would be used to apply the quotation at
compile-time.

Since the quotations will not be part of modules, we need some other mechanism
to scope them. Fortunately just such a mechanism is likely to be included in
OCaml in the near future: namespaces. Namespaces allow modules to be given
longer names (e.g. List might also be known as OCaml.Std.List). By allowing
namespaces to contain quotations as well as modules, we can control the scope of
quotations.

This will also allow quotations to be provided by libraries. So that the
following code would perfectly possible:

{% highlight ocaml %}
<:Core.Monad.do < x <- return foo;;
                  y <- bar x;;
                  return (y * 3) >>
{% endhighlight %}

#### Building Quotations ####

Creating the quotation functions requires some facility for creating AST
nodes. For this purpose, the standard library would include special quotations,
for example: `<:Ast.expr< x + 3 >>`. These quotations would be implemented
directly using the compiler's lexer and parser.

It would also be useful (especially for handling anti-quotations) to allow
quotations to be built from other quotations. For this we could provide another
syntax: `<: foo >` that would refer directly to the quotation function
`foo`. Obviously, this syntax would only be allowed within .mlq files.

#### Supporting type-conv annotations ####

This quotations proposal could also be extended to support type-conv style
annotations. This would require quotations to have the type `('a, 'b) ctx -> 'a
-> 'b`. Then a "type-conv" context could be added, which required a quotation to
accept some representation of a type definition and produce a structure item AST
node.

The type used to represent definitions could be based on the `'a ty` type used
to represent run-time types.

### Summary ###

In summary, I think that it would be quite easy to provide some much simpler
alternatives to camlp4 for creating language extensions. 

Phase 1 of providing these alternatives is to finish Alain Frisch's
implementation of AST transformers by adding some kinds of attributes to the
language.

Phase 2 is to merge the most common kinds of extension into the OCaml language
proper. Using namespaces, these extensions can be properly scoped and included
in libraries. They would also not require any pre-processors or command-line
arguments. Implementing them would not require knowledge of OCaml syntax tree.

By including these extensions in the language proper, the increasing number of
tools being built to support OCaml (e.g. typerex) can handle them directly. For
instance, IDEs could show the expansions of quotations by using the information
in .cmt files.
