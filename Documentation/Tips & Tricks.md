# Tips & Tricks

The following sections provide handy Tips and Tricks to help you effectively build up your own interpreter using custom operators and data types.

## Get inspired by checking out the examples

There are quite a few operators and data types available in the [TemplateLanguage Example](Examples/TemplateExample/Sources/TemplateExample/TemplateExample.swift) project, under the StandardLibrary class

Also, there are quite a few expressions available [in some of the unit tests](Tests/EvalTests/InterpreterTests.swift#L110) as well.

## Use helper functions to define operators

It's a lot readable to define operators in a one-liner expression, rather than using long patterns:

```swift
infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
```
```swift
suffixOperator("is odd") { (value: Double) in Int(value) % 2 == 1 }
```
```swift
prefixOperator("!") { (value: Bool) in !value }
```

You can find a few helpers [in the examples](Examples/TemplateExample/Sources/TemplateExample/TemplateExample.swift#L328-L411). Feel free to use them!

## Be mindful about precedence

#### Template expressions

The earlier a pattern is represent in the array of `statements`, the higher precedence it gets. 
Practically, if there is an `if` statement and an `if-else` one, the `if-else` should be defined earlier, because both are going to match the following expression:
`{% if x < 0 %}A{% else %}B{% endif %}`, but if `if` goes first, then the output - and the `body` of the `if` statement - is going to be processed as `A{% else %}B`. 

Typically, parentheses and richer type of expressions should go earlier in the array.

#### Typed expressions

The earlier a pattern is represent in the array of `functions`, the higher precedence it gets. 
Practically, if there is an addition function and a multiplication one, the multiplication should be defined earlier (as it has higher precedence), because both are going to match the following expression:
`1 * 2 + 3`, but if addition goes first, then the evaluation would process `1 * 2` on `lhs` and `3` on `rhs`, which - of course - is incorrect.  

Typically, parentheses and higher precedence operators should go earlier in the array.

## Use Any for generics: `Variable<Any>`

If you are not sure about the allowed input type of your expressions, or you just want to defer that decision until your match is ran and your hit the block in the matcher, feel free to use `Variable<Any>("name")` in your patterns.

It makes life a lot easier, than definig functions for each type.

## Use map on `Variable`s for pre-filtering

Before processing Variable values, there is an option to pre-filter or modify them before it hits the match block. 

Examples include data type conversion and other types of validation.

## Use `OpenKeyword` and `CloseKeyword` for embedding parentheses

Embedding is a common issue with interpreters and compilers. In order to provide some extra semantics to the engine, please use the `OpenKeyword("[")` and `OpenKeyword("]")` options, when defining `Keyword`s that come in pairs.

## Share context between `TemplateInterpreter` and `TypedInterpreter`

If you use template interpreters, they need a typed interpreter to hold. Both interpreters have `context` variables, so if you are not being careful enough, it can cause headaches. 

Since `InterpreterContext` is a class, its reference can be passed around and used in multiple places. 

The reason that the variables are encapsulated in a context is that context is a class, while variables are mutable `var` struct properties on that object. With this construction the context reference can be passed around to multiple interpreter instances, but keeps the copy-on-write (🐮) behaviour of the modification.

Context defined during the initialisation apply to every evaluation performed with the given interpreter, while the ones passed to the `evaluate` method only apply to that specific  expression instance.

## Define constants in `Literal`s

The frameworks allows multiple ways to express static strings and convert them. 
I believe the best place to put constants are in the `Literal`s of `DataType`s.

Use the `Literal("YES", convertsTo: true)` `Literal` initialiser for easy definition.

The `convertsTo` parameter of `Literal`s are `autoclosure` parameters, which means, that they are going to be processed lazily.

```swift
Literal("now", convertsTo: Date())
```

The `now` string is going to be expressed as the current timestamp at the time of the evaluation, not the time of the initialisation.

## Map any function signatures from Swift, dynamically

The framework is really lightweight and not really restrictive in regards of how to parse your expressions. Free your mind, and do stuff dynamically.

```swift
Function(Variable<Any>("lhs") + Keyword(".") + Variable<String>("rhs", interpreted: false)) { (arguments,_,_) -> Double? in
        if let lhs = arguments["lhs"] as? NSObjectProtocol,
            let rhs = arguments["rhs"] as? String,
            let result = lhs.perform(Selector(rhs)) {
            return Double(Int(bitPattern: result.toOpaque()))
        }
        return nil
    }
])
```

Perform any method call of any type and maybe process their output as well. It's not the safest way to go with it, but this is just an example.

This opens up the way of running almost any arbitrary code on Apple platforms, from any backend. But, this does it in a very controlled way, as you must define a set of data types and functions that apply, unless you call them dynamically at runtime.

## Experiment with your expressions!

It's quite easy to add new operators, functions, and data types. I suggest not to think about them too long, just dare to experpiment with them, what's possible and what is not. 

You can always add new types or functions if you need extra functionality. The options are practically endless!

## Debugging tips

#### If an expression haven't been matched
* It's common, that some validation caught the value
* Print your expressions or put breakpoints into the affected match blocks or variable map blocks

#### If you see weird output
* Play with the order of the newly added opeartions.
* Incorrect precedence can turn expressions upside down

The framework is still in an early stage, so debugging helpers will follow in upcoming releases. Please stay tuned!

## Validate your expressions before putting them out in production code

Not every expression work out of the box as you might expect. Operators and functions depend on each other, especially in terms of precedence. If one pattern was recognised before the other one, your code might not run as you expected.

Pro Tip: Write unit tests to validate expressions. Feel free to use `as!` operator to force-cast the result expressions in tests, but only in tests. It's not a problem is tests crash, you can fix it right away, but it's not okay in production.