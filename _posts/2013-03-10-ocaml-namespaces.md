--- 
layout: post 
title: Adding namespaces to OCaml
tags: ["ocaml"]
toc_start_depth: 3
toc_end_depth: 5
--- 

{% include toc.md %}

Recently there has been a lot of discussion on
[platform@lists.ocaml.org](http://lists.ocaml.org/listinfo/platform) about
proposals for adding namespaces to OCaml. I've written this post to summarise
the design decisions for such a proposal and to make my own proposal.

Before discussing what namespaces are and the issues surrounding their
implementation, it is important to explain why they are needed in the first
place. 

The most important reason for adding namespaces is to provide some means for
grouping the components of a library together. Up to now this has been
achieved using the OCaml module system. Since the components of an OCaml
library are modules, a module can be created that contains all the components
of the library as sub-modules. The "-pack" option for the compiler was created
to allow this module to be created while still keeping each component of the
library in its own file.


### Problems with pack

There are some critical problems with using "-pack" to create a single module
containing the whole library:

- The packed module is a single unit that has to be linked or not as a
  unit. This means that any program using part of the library must include the
  entire library.

- The packed module is a choke-point in the dependency graph.  If a file
  depends on one thing in the packed module then it needs to be recompiled if
  anything in the packed module changes.

- Opening a large packed module is very slow and can seriously affect build
  performance.

These problems are all caused by the fact that pack creates an OCaml
module. To understand this consider the run-time semantics of the module
system.

At run-time a module is a record. Initialising a module involves initialising
every component of the module and placing them in this record.  Initialising
these components can involve executing arbitrary code; in fact the execution
of an OCaml program is simply the initialisation of all its modules.

The problems with pack are related to these dynamic semantics. In order to
be a module pack must create a record to represent this module. This means
that it must initialise all of its components. It is this (rather than any
detail of pack's implementation) that causes the problems identified above.

Access to the components of a top-level module could proceed without the
existence of this record. However, the record is required in order to "alias"
the module, use the module as a first-class value or use it as the argument to
a functor.

Any attempt to overcome the problems with pack, whilst still maintaining
the illusion that the "pack" is a normal module, would result (at the very
least) in one of the following unhealthy situations:

- The module type of the "packed module" would depend on which of its
  components were accessed by the program.

- Any use of the "packed module" other than as a simple container
  (e.g.
  <span class="highlight"><code><span class="k">module</span>
  <span class="nc">CS</span>
  <span class="o">=</span>
  <span class="nn">Core</span><span class="p">.</span><span class="nc">Std</span></code></span> 
  ) could have a dramatic effect on what was
  linked into the program and potentially on the semantics of the program.

Namespaces are basically modules that can only be used as a simple
container. This means that they do not need a corresponding record at
run-time (or any other run-time representation). This avoids the problems
with pack as well as enabling other useful features.


### Formal semantics

Following the semantics and description language for namespaces described by
[Gabriel Scherer et al](http://gallium.inria.fr/~scherer/namespaces/spec.pdf),
I will consider namespaces to be name-labelled trees whose leaves are
compilation units. I will use 
<span class="highlight"><code><span class="o">#</span></code></span> 
to represent projection on namespaces, so the 
<span class="highlight"><code><span class="nc">Bar</span></code></span>
member of the 
<span class="highlight"><code><span class="nc">Foo</span></code></span>
namespace will be referred to as 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>.

### Design goals

Some design goals that we might want from a proposal for adding namespaces to
OCaml include:

- **Allow library components to be grouped together without creating a module
  containing them.**

- **Allow users to group together modules from different libraries as they see
  fit.** This means letting people change which namespace a library module is
  in.

- **Allow library components to be given multiple names.** For example
  <span class="highlight"><code><span class="nc">Lib</span><span class="o">#</span><span class="nc">Foo</span></code></span>
  and 
  <span class="highlight"><code><span class="nc">Lib</span><span class="o">#</span><span class="nc">Stable</span><span class="o">#</span><span class="nc">Foo</span></code></span>
  , where 
  <span class="highlight"><code><span class="nc">Lib</span><span class="o">#</span><span class="nc">Stable</span></code></span>
  is a namespace containing only those components whose interfaces are stable.

- **Be simple and easy to explain to beginners.**

- **Allow multiple source files to share the same filename.** Each module that
  is linked into an OCaml program must have a unique name. Currently, a
  module's name is completely determined by its filename. This forces library
  developers to either use pack (which gives its components new long names) or
  give their source files long names like "libName_Foo.ml". A namespaces
  proposal may be able to alleviate this problem.

- **Allow libraries to control which modules are open by default.** By default
  OCaml opens the standard library's 
  <span class="highlight"><code><span class="nc">Pervasives</span></code></span>
  module. Libraries that wish to replace the standard library may also wish to
  provide their own
  <span class="highlight"><code><span class="nc">Pervasives</span></code></span>
  module and have it opened by default.

- **Support libraries that wish to remain compatible with versions of OCaml
  without namespaces.**

- **Require minimal changes to existing build systems.** Since a namespace
  proposal changes how a library's components are named, it may require
  changes to some build systems. If these changes are too invasive then users
  of some build systems will probably be unable to use namespaces in the near
  future.

### Design choices

#### Flat or hierarchical?

In order to replace pack, namespaces must be able to contain modules. It is
not clear, however, whether they need to be able to contain other
namespaces. We call namespaces that can contain other namespaces
*hierarchical*, as opposed to *flat*.

In favour of flat namespaces:

- Hierarchical namespaces might lead to arbitrary categorising of components
  (e.g.  
  <span class="highlight"><code><span class="nc">Data</span><span class="o">#</span><span class="nc">Array</span></code></span>
  ). These add syntactic clutter and do not bring any real benefit.  

- Hierarchical namespaces might lead to deep java-style hierarchies
  (e.g.  
  <span class="highlight"><code><span class="nc">Com</span><span class="o">#</span><span class="nc">Janestreet</span><span class="o">#</span><span class="nc">Core</span><span class="o">#</span><span class="nc">Std</span></code></span>
  ). These add syntactic clutter without adding any actual information.

In favour of hierarchical namespaces:

<ul>
<li>
A library may wish to provide multiple versions of some of its components. For
example:

<ul>
<li>    
<span class="highlight"><code><span class="nc">Http</span><span class="o">#</span><span class="nc">Async</span><span class="o">#</span><span class="nc">IO</span></code></span>
 and 
<span class="highlight"><code><span class="nc">Http</span><span class="o">#</span><span class="nc">Lwt</span><span class="o">#</span><span class="nc">IO</span></code></span>
</li>
<li>
<span class="highlight"><code><span class="nc">File</span><span class="o">#</span><span class="nc">Windows</span><span class="o">#</span><span class="nc">Directories</span></code></span>
and 
<span class="highlight"><code><span class="nc">File</span><span class="o">#</span><span class="nc">Unix</span><span class="o">#</span><span class="nc">Directories</span></code></span>
</li>
<li>
<span class="highlight"><code><span class="nc">Core</span><span class="o">#</span><span class="nc">Mutex</span></code></span>
and 
<span class="highlight"><code><span class="nc">Core</span><span class="o">#</span><span class="nc">Testing</span><span class="o">#</span><span class="nc">Mutex</span></code></span>
</li>
</ul>

In such situations it is useful to be able to write both

{% highlight ocaml %}
open Core
[...]
Testing#Mutex.lock x
{% endhighlight %}

and

{% highlight ocaml %}
open Core#Testing
[...]
Mutex.lock x
{% endhighlight %}
</li>
<li>
None of the systems of namespaces that have been proposed have any
additional cost for supporting hierarchical namespaces.
</li>
</ul>

#### Should namespaces be opened explicitly in source code?

There was some debate on the platform mailing list about whether to support
opening namespaces explicitly in source code. This means allowing a syntax
like:

<div class="highlight">
<pre><code class="ocaml"><span class="k">open</span> <span class="k">namespace</span> <span class="nc">Foo</span></code></pre>
</div>

that allows the members of namespace 
<span class="highlight"><code><span class="nc">Foo</span></code></span>
to be referenced directly (i.e.
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
can be referred to as 
<span class="highlight"><code><span class="nc">Bar</span></code></span>).

The alternative would be to only support opening namespaces through a
command-line argument.

In favour of supporting explicit opens:

- If you open two namespaces with commonly named sub-components then the order
  of those opens matters. If the opens are command-line arguments then the
  order of those command-line arguments (often determined by build systems and
  other tools) matters. This is potentially very fragile.

- Explicit opens in a source file give valuable information about which
  libraries are being used by that source file. If a file contains "open
  namespace Core" then you know it uses the Core library.

- Local namespace opens provide users more precise control over their naming
  environment.

Against supporting explicit opens:

- They require a new syntactic construct.

#### How should the compiler find modules in the presence of namespaces?

Currently, when looking for a module 
<span class="highlight"><code><span class="nc">Bar</span></code></span>
that is not in the current environment, the OCaml compiler will search the
directories in its search path for a file called "bar.cmi".

In the presence of namespaces this becomes more complicated: how does the
compiler find the module 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
?

The suggested possible methods for finding modules in the presence of
namespaces fall into four categories.

##### Using filenames

By storing the interface for 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
in a file named "foo-bar.cmi" the compiler can continue to simply look-up
modules in its search path.

Note that "-" is an illegal character in module names so there is no risk of
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
being confused with a module called 
<span class="highlight"><code><span class="nc">Foo-bar</span></code></span>.

This simple scheme does not support placing a module within multiple
namespaces or allowing users to put existing modules in a new namespace.

##### Checking multiple ".cmi" files

The name of the namespace containing a compilation unit could be included in
the ".cmi" file of that unit. Then, when looking for a module 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
, the compiler would try every "bar.cmi" file in its search path until it
found one that was part of the "Foo" namespace. This may require the compiler
to open all the "bar.cmi" files on its search path, which could be expensive
on certain operating systems.

This scheme does not support allowing users to put existing modules in a new
namespace, but can support placing a module in multiple namespaces.

It is difficult to detect typos in namespace open statements using this
scheme. For example, detecting that
<span class="highlight"><code><span class="k">open</span>
<span class="k">namespace</span>
<span class="nc">Core</span><span class="o">#</span><span class="nc">Sdt</span></code></span> 
should have been
<span class="highlight"><code><span class="k">open</span>
<span class="k">namespace</span>
<span class="nc">Core</span><span class="o">#</span><span class="nc">Std</span></code></span>
would require the compiler to check every file in its search path for one that
was part of namespace
<span class="highlight"><code><span class="nc">Core</span><span class="o">#</span><span class="nc">Sdt</span></code></span>.

##### Using namespace description files

The compiler could find a member of a namespace by consulting a file that
describes the members of that namespace.

For example, if namespace 
<span class="highlight"><code><span class="nc">Foo</span></code></span>
was described by a file "foo.ns" that was on the compiler's search path then
the compiler could find
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
by locating "foo.ns" and using it to look-up the location of the ".cmi" file
for
<span class="highlight"><code><span class="nc">Bar</span></code></span>.

These namespace description files could be created automatically by some
tool. However, they must be produced before detecting dependencies with
OCamlDep, which could complicate the build process.

##### Using environment description files

The compiler could find a member of a namespace by consulting a file that
describes a mapping between module names and ".cmi" files.

For example, if a file "foo.mlpath" included the mapping "Foo#Bar:
foo/bar.cmi" then that file could be passed as a command-line argument to the
compiler and used to look up the "bar.cmi" file directly.

Looking up modules using this scheme may speed up compilation by avoiding the
need to scan directories for files.

#### How should namespaces specified?

Perhaps the most important question for any namespaces proposal is how
namespaces are specified. It is closely related to the above question of how
the compiler finds modules in the presence of namespaces.

The suggested possible methods for specifying namespaces fall into five
categories.

##### Explicitly in the source files

Namespaces could be specified by adding a line like:

<div class="highlight">
<pre><code class="ocaml"><span class="k">namespace</span> <span class="nc">Foo</span></code></pre>
</div>

to the beginning of each compilation unit that is part of the 
<span class="highlight"><code><span class="nc">Foo</span></code></span> 
namespace. 

This has the benefit of making namespaces explicitly part of the language
itself, however it does mean that the full name of a module is specified in
two locations: partly in the filename and partly within the file itself.

##### Through command-line arguments

Namespaces could be specified by passing a command-line argument to the
compiler. For example, 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span> 
could be compiled with the command-line:

{% highlight sh %}
ocamlc -c -namespace Foo bar.ml 
{% endhighlight %}

This scheme also means that the full name of a module is specified in two
locations: partly in the build system and partly in the filename.

##### Through filenames

Namespaces could be specified using the filenames of source files. For
example, 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span> 
would be created by compiling a file "foo-bar.ml"

This scheme is simple and very similar to how modules are currently named, but
it would require all source files to have long unique names.

##### Through namespace description files

Namespaces could be specified using namespace description files. The 
<span class="highlight"><code><span class="nc">Foo</span></code></span>
namespace would be specified by a file "foo.ns" that described the members of
<span class="highlight"><code><span class="nc">Foo</span></code></span>:

    module Bar = "foo_bar.cmi"
    namespace Testing = "testing.ns"

##### Through environment description files

Namespaces could be specified using environment description files. A namespace
<span class="highlight"><code><span class="nc">Foo</span></code></span>
would be defined by passing an environment description file to the compiler
that included mappings for each of the members of
<span class="highlight"><code><span class="nc">Foo</span></code></span>. For example:

    Foo#Bar: "foo_bar.cmi"
    Foo#Testing#Bar: "foo_testing_bar.cmi"
    Baz: "baz.cmi"

In addition to specifying namespaces, this system allows users (or a tool like
OCamlFind) to have complete control the naming environment of a program.

#### How rich should a description language be?

For namespace proposals that use namespace or environment description files,
they must decide how rich their description language should be.

For example, [Gabriel Scherer et
al](http://gallium.inria.fr/~scherer/namespaces/spec.pdf) describe a very rich
environment description language including many different operations that can
be performed on namespaces.

A rich description language can produce shorter descriptions. However, the
more operations a language supports the more syntax that users must understand
in order to read description files. The majority of description files are
unlikely to require complex operations.

#### Should namespaces support automatically opened members?

A feature of namespaces that has been proposed on the mailing list is to allow
some modules within a namespace to be automatically opened when the namespace
is also opened. This makes it seem that the namespace has values and types as
members.

This feature is based on the current design of Jane Street's Core
library. Users of the Core library are expected to open the
<span class="highlight"><code><span class="nc">Core<span class="p">.</span>Std</span></code></span>
 module before using the library. Opening this module provides access to all
the other modules of the library (much like opening a namespace), but it also
provides types and values similar to those provided by the standard library's
<span class="highlight"><code><span class="nc">Pervasives</span></code></span> module.

Supporting auto-opened modules would allow 
<span class="highlight"><code><span class="nc">Core<span class="p">.</span>Std</span></code></span>
to be directly replaced by a namespace. However, the semantics of this feature
could be awkward due to potential conflicts between members of the namespace
and sub-modules of the auto-opened modules. It also increases the overlap
between namespaces and modules.

### Proposal

In the last section of this post I will outline a namespaces proposal that I
think satisfies the design goals set out earlier.

I think that satisfying these design goals requires a combination of
extensions to OCaml. My proposal is made up of four such extensions. To keep
things simple for users to understand, I have tried to keep each of these
extensions completely independent of the others and with a clearly defined
goal.

#### Simple namespaces through filenames

Currently, the name of a module is completely defined by its filename, and
modules are looked up using a simple search path. While it has some problems,
this simple paradigm has served OCaml well and I think that it is important to
provide some support for namespaces within this paradigm.

This means allowing simple namespaces to be specified using source file
names. For example, to create a module 
<span class="highlight"><code><span class="nc">Bar</span></code></span>
within the namespace 
<span class="highlight"><code><span class="nc">Foo</span></code></span>
developers can simply create an implementation file "foo-bar.ml" and an
interface file "foo-bar.mli". This interface file would be compiled to a
"foo-bar.cmi" file. Hierarchical namespaces would be created by files with
names like "foo-bar-baz.ml".

These namespaced modules can be referred to using the syntax 
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>. 
This syntax simply causes the compiler to look in its search path for a
"foo-bar.cmi" file.

I also propose supporting a namespace opening syntax like:
<div class="highlight">
<pre><code class="ocaml"><span class="k">open</span> <span class="k">namespace</span> <span class="nc">Foo</span>
[...]
<span class="nc">Bar</span></code></pre>
</div>

#### An alternative to search paths

Forcing the name of a module to be completely defined by its (compiled)
filename makes it easy to look-up modules in a search path. However, it
prevents modules from being given multiple names or being renamed by users. So
I propose supporting an alternative look-up mechanism.

I propose supporting environment description files called *search path
files*. These files would have a syntax like:

    Foo#Bar : "other_bar.cmi"
    Foo#Baz : Foo#Bar

This file can be given to the "-I" command-line argument instead of a
directory and used to look-up the locations of ".cmi" files for given module
names.

These search path files can be used to alias modules and to create new
namespaces. They also allow a module to be available under multiple namespaces.

I envisage two particular modes of use:

- Library authors can write ".mlpath" files and tell OCamlFind to use that
  file as its search path instead of a list of directories.

- A user (or potentially OCamlFind) can create search path files to define
  their entire naming environment as they see fit.

#### The "-name" argument

While the hard link between a module's name and the name of its source file
makes life easier for build systems ("list.cmi" can only be produced by
compiling "list.ml"), it forces library authors to give their source files long
unique names.

I propose adding a "-name" command-line argument to the OCaml compiler. This
would be used as follows:

{% highlight sh %}
ocamlc -c -name Foo#Bar other.ml
{% endhighlight %}

This command would produce a "foo-bar.cmi" file defining a module named
<span class="highlight"><code><span class="nc">Foo</span><span class="o">#</span><span class="nc">Bar</span></code></span>
. This means that ".cmi" files would still be expected to be unique, but
source files could be named however the developer wants.

Obviously, any tools that assume that a module 
<span class="highlight"><code><span class="nc">Bar</span></code></span>
must be compiled from a file called "bar.ml" will not work in this
situation. However, the only OCaml tool that absolutely relies on this
assumption is "OCamlDep" when it is producing makefile formatted output.

Build systems would not be required to support the "-name" argument, however
it would make it easy for them to provide features such as:

- Creating namespaces to reflect a directory structure (e.g. "foo/bar.mli" becomes "foo-bar.cmi").

- Placing all the modules of a library under a common namespace (e.g. "bar.mli" becomes "foo-bar.cmi")

This would mean that the names of source files could be kept conveniently
short.

#### The "-open" argument

My proposals do not include support for automatically opened modules within
namespaces. I feel that this feature conflates two separate issues and it
would be better to solve the problem of automatically opened modules elsewhere. 

Auto-opened modules are meant to allow libraries to provide their own
equivalent of the standard library's 
<span class="highlight"><code><span class="nc">Pervasives</span></code></span>
module. I think that it would be more appropriate to have these "pervasive"
modules opened by default in any program compiled using one of these
libraries.

I propose adding a command-line argument "-open" that could be used to open a
module by default:

{% highlight sh %}
ocamlc -c -open core-pervasives.cmi foo.ml
{% endhighlight %}

By adding support for this feature to OCamlFind, libraries could add this
argument to every program compiled using them. This amounts to having
automatically opened modules as part of the package system rather than part of
the namespace system.