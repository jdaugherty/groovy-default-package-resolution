# A default-package class resolves a compiled default-package class to a default import

Reported as [GROOVY-12555](https://issues.apache.org/jira/browse/GROOVY-12555). The fix is proposed in [apache/groovy#3084](https://github.com/apache/groovy/pull/3084), with a backport to `GROOVY_5_1_X` in commit [d84100ebe6](https://github.com/jdaugherty/groovy/commit/d84100ebe6ac81c73763af11ee9d5ec2dc5c3c15).

A class in the default package that refers to another class of the default package by its simple name finds that
class while both are compiled together. When the other class is already compiled, Groovy resolves the name to a class
of its default imports with the same simple name instead, here `groovy.util.Factory`. The same source compiles to a
different class, which here fails at run time. In Java, a class of the same package, the unnamed one included, takes
precedence over on-demand imports such as `java.lang.*`.

Reproduced with Groovy 4.0.33 and 5.1.3.

## The difference

Three classes in the default package:

```groovy
class Factory {
    static String hello() { 'hello from the Factory of this project' }
}

class Caller {
    static void main(String[] args) {
        println Util.label()
        println Factory.hello()
    }
}
```

`groovyc-repro.sh` compiles all classes together, and again compiles `Caller` against the other classes compiled:

```
== class Caller refers to as Factory, compiled together:
Class #50 // Factory
== class Caller refers to as Factory, compiled against the other classes:
Class #50 // groovy/util/Factory
```

## In an incremental build

`demo.sh` runs the same thing through Gradle 9.8.0 with incremental Groovy compilation:

1. a full build, where all classes are compiled together;
2. a change to a method body in `Util`, which `Caller` uses only inside a method body;
3. an incremental build, where Gradle recompiles `Util` and `Caller` against the other classes, already compiled.

and runs `Caller` after each build. With Groovy 5.1.3:

```
Incremental compilation of 2 classes completed in 0.687 secs.

== 4. class Caller refers to as Factory, full build:
Class #50 // Factory
== class Caller refers to as Factory, incremental build:
Class #50 // groovy/util/Factory

== 5. Running Caller
full build:        hello from the Factory of this project
incremental build: Exception in thread "main" groovy.lang.MissingMethodException: No signature of static method: hello for class: groovy.util.Factory is applicable for argument types: () values: []
```

## Cause

`ResolveVisitor.resolve` tries, in order, the classes of the module, of the compilation unit, of the default imports,
and then the class path. For a module of a named package, the module step also looks up `package.Name` on the class
path, so a compiled class of the same package comes first. For the default package there is no such step, so the
default imports come before a compiled class of the default package.

## Fix

For a class of the default package, look up the simple name on the class path after the compilation unit and before
the default imports, as is done for a named package. Both builds then refer to `Factory`.

## Running it

```
./groovyc-repro.sh    # groovyc alone; needs groovyc on the PATH, or GROOVYC set to a groovyc command
./demo.sh             # Gradle 9.8.0: full build, a method body change in Util, incremental build, then both results
```

Both scripts leave the sources as they found them. The Groovy version is set in `gradle.properties`. To try a fix,
publish a Groovy build with it to the local Maven repository and pass its version, for example
`./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT`.
