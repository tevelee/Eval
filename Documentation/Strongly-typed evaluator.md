# Strongly typed evaluator

This kind of evaluator interprets its input as one function. It searches for the one with the highest precedence and works its way down from that. 
Ocassionally, more functions are present in the same expression. In this case, it goes recursively, all the way down to the most basic elements: variables or literals, which are trivial to evaluate.

## Creation

The way to create typed interpreters is the following:

```swift
let interpreter = TypedInterpreter(dataTypes: [number, string, boolean, array, date],
                                   functions: [concat, add, multiply, substract, divide],
                                   context: InterpreterContext(variables: ["example": 1]))
```

First, you'll need the data types you are going to work with. These are a smaller subsets of the build in Swift data types, you can map them to existing types (Swift types of the ones of your own)

The second parameter are the functions you can apply on the above listed data types. All the functions - regardless of the grouping of the data types - should be listed here.
Typically, in case of numbers, these are numeric operators. In case of string, these can be concatenation, getters, slicing, etc.
Or, these can be complex things, such as parentheses, data factories, or high level functional operations, such as filter, map or reduce.

And lastly, an optional context object, if you have any global variables.

Variables in the context can be expression specific, or global that apply to every evaluation session. 

## Data types

Data types map the outside world to the inside of the expression. They map existing types to inner data types. 

They don't restrict any behaviour, so these types can either be built-in Swift types, such as String, Array, Date; or they can be your custom classes, srtucts, or enums.

Let's see it in action:

```swift
let number = DataType(type: Double.self, literals: [numberLiteral, piConstant]) { String(describing: $0) }
```

If has a type, that is the existing type of the sorrounding program. The literals, which can tell the framework whether a given string can be converted to a given type. 

Typical example is the `String` literal, which encloses something between quotes: `'like this'`. The can also be constants, for example `pi` for numbers of `true` for booleans.

The last parameter is a `print` closure. It tells the framework how to render the given type when needed. Typically used while debugging, or when templates use the `print` statement.

In summary: literals provide the input, print provides the output of a mapped type.

### Literals

Let's check out some literals a bit more deeply. 

The block used for literals have two parameters: the input string, and an interpreter.
Most of the times, only the input is enough to recognise things, like numbers:

```swift
Literal { value, _ in Double(value) }
```
Arrays, on the other hand, should process their content (Comma `,` separated values between brackets `[` `]`). For this, the second parameter, the interpreter can be used.

#### Constants

Literals are the perfect place to recognise constants, such as:

```swift
Literal("pi", convertsTo: Double.pi)
```
or
                                                          
```swift
[Literal("false", convertsTo: false)
```
Of course, there are multiple ways to represent them (for example, as a single keyword function pattern), but this seems like a place where they can be most closely connected to their type.

The `convertsTo` parameter of `Literal`s are `autoclosure` parameters, which means, that they are going to be processed lazily.

```swift
Literal("now", convertsTo: Date())
```

The `now` string is going to be expressed as the current timestamp at the time of the evaluation, not the time of the initialisation.

## Functions

Similarly to templates, typed interpreters use the same building blocks to build up their patterns: `Keyword`s and `Variable`s.

### Keywords

`Keyword`s are the most basic elements of a pattern; they represent simple, static `String`s. You can chain them, for example `Keyword("<") + Keyword("br/") + Keyword(>}")`, or simply merge them `Keyword("<br/>")`. Logically, these two are the same, but the former accepts any number of whitespaces between the tags, while the latter allows none, as it is a strict match. 

Most of the time though, you are going to need to handle placeholders, varying number of elements. That's where `Variable`s come into place.

### Variables

Let's check out the following, really straightforward pattern:

```swift
Function(Keyword("(") + Variable<Any>("body") + Keyword(")")) { variables, _, _ in
	return variables["body"]
}
```

Something between two enclosing parentheses `(`, `)`. The middle tag is a `Variable`, which means that its value is going to be passed through in the block, using its name. Let's imagine the following input: `(5)`. Here, the `variables` dictionary is going to have `5` under the key `body`.

#### Generics

Since its value is going to be processed, there is a generic sign as well, signalling that this current `Variable` accepts `Any` kind of data, no transfer is needed. Let's imagine if we wrote `Variable<String>` instead. In this case, `5` would not match to the pattern, it would be intact. But, for example, `('Hello')` would do.

Let check out a `+` operator. This could equally mean addition for numeric types

```swift
Function(Variable<Double>("lhs") + Keyword("+") + Variable<Double>("rhs")) { arguments,_,_ in
    guard let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double else { return nil }
    return lhs + rhs
}
```
or concatenation for strings

```swift
Function(Variable<String>("lhs") + Keyword("+") + Variable<String>("rhs")) { arguments,_,_ in
    guard let lhs = arguments["lhs"] as? String, let rhs = arguments["rhs"] as? String else { return nil }
    return lhs + rhs
}
```
Since the interpreter is strongly typed, always the appropriate one is going to be selected by the framework.

#### Evaluation

Variables also have optional properties, such as `interpreted`, `shortest`, or `acceptsNilValue`. They might also have a `map` block, which by default is `nil`.

* `interpreted` tells the framework, that its value should be evaluated. This is true, by default. But, the option exists to modify this to false. In that case, `(2 + 3)` would not generate the number `5` under the `body` key, but `2 + 3` as a `String`.
* `shortest` signals the "strength" of the matching operation. By default it's false, we need the most possible characters. The only scenario where this could get tricky is if the last element of a pattern is a `Variable`. In that case, the preferred setting is `false`, so we need the largest possible match!
Let's find out why! A general addition operator (which looks like this `Variable<Double>("lhs") + Keyword("+") + Variable<Double>("rhs")`) would recognise the pattern `12 + 34`, but it also matches to `12 + 3`. What's what shortest means, the shortest match, in this case, is `12 + 3`, which - semantically - is an incorrect match. 
But don't worry, the framework already knows about this, so it sets the right value for your variables, even in the last place!
* `acceptsNilValue` informs the framework if `nil` should be accepted by the pattern. For example, `1 + '5'` with the previous example (`Double + Double`) would not match. But, if the `acceptsNilValue` is defined, then the block would trigger, with `{'lhs': 1, 'rhs': nil}`, so you can decide by your own logic what to do in this case.
* Finally, the `map` block can be used to further transform the value of your `Variable` before calling the block on the `Matcher`. Since map is a trailing closure, it's quite easy to add. For example, `Variable<Int>("example") { Double($0) }` would recognise only `Int` values, but would transform them to `Double` instances when providing them in the `variables` dictionary. This map can also return `nil` values but depends on your logic if you want to accept them or not. Side note: the previous map generates a `Variable<Double>` kind of variable instance.

### Specialised elements

#### Open & Close Keyword

Parentheses are quite common in expressions. They are often embedded in each other. Embedding is a nasty problem of interpreters, as `(a * (b + c))` would logically be evaluated with `(b + c)` first, and the rest afterwards. 

But, an algorithm, by default, would interpret things linearly, disregarding the semantics: `(a * (b + c))` would be the match for the first if statement, with a totally invalid `a * (b + c` data, until the first match.

This, of course, needs to be solved, but it's not that easy as it first looks! Some edge cases would not work unless we somehow try to connect them together. For this reason, I added two special elements: `OpenKeyword` and `CloseKeyword`. These work exactly the same way as normal `Keyword`s do, but add a bit more semantics to the framework: these two should be connected together, and therefore embedding them should not be a problem as they come in pairs. 

The previous parentheses statement should - correctly - look like this:

```swift
Function(OpenVariable<String>("lhs") + Keyword("+") + CloseVariable<String>("rhs")) { arguments,_,_ in
    guard let lhs = arguments["lhs"] as? String, let rhs = arguments["rhs"] as? String else { return nil }
    return lhs + rhs
}
```

By using the `OpenKeyword` and `CloseKeyword` types, these become connected, so embedding parentheses in an expression shouldn't be a problem. 
After this match is defined, they can be embedded in each other as deeply as needed.

#### Multiple Matchers in one Function

This is a rarely used pattern, but `Function`s consists of an array of `Matcher` elements. 
Usually, one `Function` does only one operation. Unless this is true, grouping multiple `Matcher`s into one `Function` allows semantical grouping of opeartors. 

For example a Boolean negation can be expressed in multiple ways: `not(true)` or `!true`. In this case, semantically both expressions do the same thing, therefore it might be a good practice to use one `Function` with two `Matcher`s for this. 

## Context

You can also pass contextual values, which - for now - equal to variables.

```swift
expression.evaluate("1 + var", context: InterpreterContext(variables: ["var": 2]))
```

The reason that the variables are encapsulated in a context is that context is a class, while variables are mutable `var` struct properties on that object. With this construction the context reference can be passed around to multiple interpreter instances, but keeps the copy-on-write (🐮) behaviour of the modification.

Context defined during the initialisation apply to every evaluation performed with the given interpreter, while the ones passed to the `evaluate` method only apply to that specific  expression instance.

If some patterns modify the context, they have the option to modify the general context (for long term settings, such as `value++`), or the local one (for example, the interation variable of a `for` loop).

### Order of statements define precedence

The earlier a pattern is represent in the array of `functions`, the higher precedence it gets. 
Practically, if there is an addition function and a multiplication one, the multiplication should be defined earlier (as it has higher precedence), because both are going to match the following expression:
`1 * 2 + 3`, but if addition goes first, then the evaluation would process `1 * 2` on `lhs` and `3` on `rhs`, which - of course - is incorrect.  

Typically, parentheses and higher precedence operators should go earlier in the array.