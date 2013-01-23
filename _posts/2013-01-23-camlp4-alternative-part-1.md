--- 
layout: post 
title: An alternative to camlp4 - 1
--- 
Since its creation camlp4 has proven to be a very useful tool. People have used
it to experiment with new features for OCaml and to provide interesting
meta-programming facilities. However, there is general agreement that camlp4 is
too powerful and complex for the applications that it is most commonly used for,
and there is a growing movement to provide a simpler alternative.

The [wg-camlp4@lists.ocaml.org](http://lists.ocaml.org/listinfo/wg-camlp4)
mailing list has been created to discuss implementing this simpler
alternative. This blog post is a way of kick-starting the discussion on this
list, by explaining my thoughts on what needs to be done.

Personally, I think that providing a real alternative to camlp4 involves two
phases. The first phase is to provide support for implementing the most popular
camlp4 extensions without camlp4. Since the people who have implemented these
extensions already require good knowledge of the OCaml grammar it is not
unreasonable to expect a similar level of expertise to use the alternative. This
phase can easily be implemented before the next OCaml release, and I will
discuss what I think that will involve in the remainder of this post.

The second phase involves extending this support to allow general OCaml
programmers to write extensions, and to include such extensions within the
language itself rather than as part of a pre-processor. I will discuss my
thoughts on this phase in a later blog post.

#### Camlp4 in the wild ####

Camlp4 works by producing pre-processors that parse an OCaml file and then output
a syntax tree directly into the compiler. Extensions are written by extending
the default OCaml parser and converting any new syntax tree nodes into existing
OCaml nodes. Most of the complexity in camlp4 comes from its extensible
grammars, which gives camlp4 the ability to extend the OCaml syntax
arbitrarily. However, most applications do not need this ability. 

From an ad-hoc survey of camlp4 extensions in the OPAM repository, most of the
popular camlp4 extensions seem to fall into one of three categories: 
<ul>
<li>
Type-conv style extensions such as 
<a href="https://bitbucket.org/yminsky/ocaml-core/wiki/Home">sexplib</a>, 
<a href="https://github.com/mirage/orm">ORM</a> and 
<a href="https://github.com/mirage/dyntype">dyntype</a>. 
These extend the syntax to allow code such as:
{% highlight ocaml %}
type t =
{ x : int with default(42);
  y : int with default(3), sexp_drop_default;
  z : int with default(3), sexp_drop_if(z_test); 
} with sexp
{% endhighlight %}
</li>
<li>
Extensions using camlp4's quotations syntax such as 
<a href="https://github.com/mirage/ocaml-cow">COW</a>. These look like:
{% highlight ocaml %}
<:html< <body> Hello world </body>  >>
{% endhighlight %}
</li>
<li>
Other syntax extensions that could be expressed using existing syntax or the
camlp4 quotation syntax. For example, 
<a href="http://ocsigen.org/js_of_ocaml/">js_of_ocaml</a> provides a
`##` operator for accessing javascript objects. This could easily be replaced by
a valid operator such as `%%`.
</li>
</ul>

By providing support for these specific kinds of extension, we can provide an
alternative to camlp4 for the majority of its applications.

#### AST transformers, attributes and quotations ####

A much simpler alternative to allowing arbitrary syntax extensions is to use
*AST transformers*, *attributes* and *quotations*.

AST transformers are simply functions that perform transformations on the OCaml
syntax tree. These can already be implemented using the new
"[-ppx](http://www.lexifi.com/blog/syntax-extensions-without-camlp4-lets-do-it)"
command line option that has been included on the OCaml development trunk by
Alain Frisch. This option accepts a program as an argument, and pipes the syntax
tree through that program after parsing and before type checking.

Attributes are places in the grammar where generic data can be attached to the
syntax tree. This data is simply ignored by the main OCaml compiler, but it can
used be AST transformers to control transformations. 

Quotations are any construct that is not lexed or parsed by the compiler. These
can be attributes, expressions, patterns etc. The contents of a quotation can be
lexed and parsed by an AST transformer and converted into a regular AST node.

Before support for attributes and quotations can be added to the compiler
decisions need to be made about what kinds of attributes and quotations to
support. Personally I prefer quotation attributes to attributes that are parsed
by the compiler because they are more flexible. However there is no reason that
both kinds cannot be supported by the compiler using different syntax.

I think that it is important to support at least the following kinds of attribute:
<ul>
<li>
Simple named quotations for expressions, patterns and type expressions:
{% highlight ocaml %}
let x = <:Foo.foo < some random text >>
{% endhighlight %}
</li>
<li>
Type constructor quotation attributes:
{% highlight ocaml %}
let x: int %foo, float %bar( some random text) = (3, 4.5)
{% endhighlight %}
</li>
<li>
Type-conv style definition attributes:
{% highlight ocaml %}
type t = 
{ x: int;
  y: int; }
with foo, bar( (* some valid expression *) )
{% endhighlight %}
</li>
<li>
Annotating types with syntactically valid expressions:
{% highlight ocaml %}
let x: string @@ (* some valid expression *) = ()
{% endhighlight %}
</li>
</ul>

Once support for these attributes and quotations is added to OCaml I think that
the majority of camlp4 applications could be easily converted into AST
transformers.

In order to make this transition easy, work must also be done to provide tools
for manipulating OCaml's AST and parsing quotations. It would also be worthwhile
trying to normalise some of the stranger corners of the OCaml syntax tree. This
will make writing AST transformers simpler and more robust

Finally, the "-ppx" option must be integrated into the many OCaml build
systems.

#### Join the discussion ####

The above suggestions are just the attributes and quotations that I think will
be necessary to provide a viable alternative to camlp4. However, I suspect that
they are not sufficient. It would be very useful to hear from anyone who has
written camlp4 extensions about what kind of extensions they have written, and
what they think would be necessary to support their extensions without
camlp4. So please join the
[wg-camlp4@lists.ocaml.org](http://lists.ocaml.org/listinfo/wg-camlp4) list and post
your thoughts.
