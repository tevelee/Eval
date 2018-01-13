# Template evaluator

The logic of the interpreter is fairly easy: it goes over the input character by character and replaces any patterns it can find. 

## Creation

The way to create template interpreters is the following:

```swift
let template = StringTemplateInterpreter(statements: [ifStatement, printStatement], 
								   interpreter: interpreter, 
								   context: InterpreterContext(variables: ["example": 1]))
```

First, you'll need the statements that you aim to recognise.
Then, you'll need a typed interpreter, so that you can evaluate strongly typed expressions. 
And lastly, an optional context object, if you have any global variables.

Variables in the context can be expression specific, or global that apply to every evaluation session. 

The template interpreter and the given typed interpreter don't share the same context. Apart from the containment dependency, they don't have any logical connection. The reason for this is that templates need a special context feeding the template content, but typed interpreters might work with totally different data types. It is totally up to the developer how they want their context to be managed. Since the context is a class, its reference can be passed around, so it's quite straightforward to have them share the same context object - if needed.

## Statement examples

### Keywords

`Keyword`s are the most basic elements of a pattern; they represent simple, static `String`s. You can chain them, for example `Keyword("{%") + Keyword("if") + Keyword("%}")`, or simply merge them `Keyword("{% if %}")`. Logically, these two are the same, but the former accepts any number of whitespaces between the tags, while the latter allows only one, as it is a strict match. 

Most of the time though, you are going to need to handle placeholders, varying number of elements. That's where `Variable`s come into place.

### Variables

Let's check out the following, really straightforward pattern:

```swift
Matcher(Keyword("{{") + Variable<Any>("body") + Keyword("}}")) { variables, interpreter, _ in
    guard let body = variables["body"] else { return nil }
    return interpreter.typedInterpreter.print(body)
}
```

Something between two enclosing parentheses `{{`, `}}`. The middle tag is a `Variable`, which means that its value is going to be passed through in the block, using its name. Let's imagine the following input: `The winner is: {{ 5 }}`. Here, the `variables` dictionary is going to have `5` under the key `body`.

#### Generics

Since its value is going to be processed, there is a generic sign as well, signalling that this current `Variable` accepts `Any` kind of data, no transfer is needed. Let's imagine if we wrote `Variable<String>` instead. In this case, `5` would not match to the template, it would be intact. But, for example, `{{ 'Hello' }}` would do.

#### Evaluation

Variables also have optional properties, such as `interpreted`, `shortest`, or `acceptsNilValue`. They might also have a `map` block, which by default is `nil`.

* `interpreted` tells the framework, that its value should be evaluated. This is true, by default. But, the option exists to modify this to false. In that case, `{{ 2 + 3 }}` would not generate the number `5` under the `body` key, but `2 + 3` as a `String`.
* `shortest` signals the "strength" of the matching operation. By default it's false, we need the most possible characters. The only scenario where this could get tricky is if the last element of a pattern is a `Variable`. In that case, the preferred setting is `false`, so we need the largest possible match!
Let's find out why! A general addition operator (which looks like this `Variable<Double>("lhs") + Keyword("+") + Variable<Double>("rhs")`) would recognise the pattern `12 + 34`, but it also matches to `12 + 3`. What's what shortest means, the shortest match, in this case, is `12 + 3`, which - semantically - is an incorrect match. 
But don't worry, the framework already knows about this, so it sets the right value for your variables, even in the last place!
* `acceptsNilValue` informs the framework if `nil` should be accepted by the pattern. For example, `1 + '5'` with the previous example (`Double + Double`) would not match. But, if the `acceptsNilValue` is defined, then the block would trigger, with `{'lhs': 1, 'rhs': nil}`, so you can decide by your own logic what to do in this case.
* Finally, the `map` block can be used to further transform the value of your `Variable` before calling the block on the `Matcher`. Since map is a trailing closure, it's quite easy to add. For example, `Variable<Int>("example") { Double($0) }` would recognise only `Int` values, but would transform them to `Double` instances when providing them in the `variables` dictionary. This map can also return `nil` values but depends on your logic if you want to accept them or not. Side note: the previous map generates a `Variable<Double>` kind of variable instance.

### Specialised elements

#### Template Variable

By default, `Variable` instances use typed interpreters to evaluate their value. Sometimes though, they should be processed with the template interpreter. A good example is the `if` statement:


```swift
Matcher(Keyword("{%") + Keyword("if") + Variable<Bool>("condition") + Keyword("%}") + TemplateVariable("body") + Keyword("{% endif %}")) { variables, interpreter, _ in
    guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
    if condition {
        return body
    }
    return nil
}
```

This statement has two semantically different kinds of variable, but they both are just placeholders. The first (`condition`) is an interpreted variable, which at the end returns a `Boolean` value. 

The second one is a bit different; it should not be evaluated the same way as `condition`. We need to further evaluate the enclosed template, that's why this variable

1. Should not be interpreted
2. Should be evaluated using the template interpreter, not the typed interpreter

That's why there's a subclass called `TemplateVariable`, which forces these two options when initialised. It DOES evaluate its content but uses the template interpreter to do so.

A quick example: `Header ... {% if x > 0 %}Number of results: {{ x }} {% endif %} ... Footer`

Here, `x > 0` is a `Boolean` expression, but the body between the `if`, and `endif` tags is a template, such as the whole expression.

#### Open & Close Keyword

`if` statements are quite common in templates. They are often chained and embedded in each other. Embedding is a nasty problem of interpreters, as `{% if %}a{% if %}b{% endif %}c{% endif %}` would logically be evaluated with `{% if %}b{% endif %}` first, and the rest afterwards. 

But, an algorithm, by default, would interpret things linearly, disregarding the semantics: `{% if %}a{% if %}b{% endif %}` would be the match for the first if statement, with a totally invalid `a{% if %}b` data. 

This, of course, needs to be solved, but it's not that easy as it first looks! Some edge cases would not work unless we somehow try to connect them together. For this reason, I added two special elements: `OpenKeyword` and `CloseKeyword`. These work exactly the same way as normal `Keyword`s do, but add a bit more semantics to the framework: these two should be connected together, and therefore embedding them should not be a problem as they come in pairs. 

The previous `if` statement, now with an `else` block should - correctly - look like this:

```swift
Matcher(OpenKeyword("{% "if") + Variable<Bool>("condition") + Keyword("%}") + TemplateVariable("body") + Keyword("{% else %}") + TemplateVariable("else") + CloseKeyword("{% endif %}")) { variables, interpreter, _ in
    guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
    if condition {
        return body
    } else {
        return variables["else"] as? String
    }
}
```

By using the `OpenKeyword` and `CloseKeyword` types, these become connected, so embedding `if` statements in a template shouldn't be a problem. 

Similarly, this works for the `print` statement from an earlier example:

```swift
Matcher(OpenKeyword("{{") + Variable<Any>("body") + CloseKeyword("}}")) { variables, interpreter, _ in
    guard let body = variables["body"] else { return nil }
    return interpreter.typedInterpreter.print(body)
}
```

## Evaluation

The evaluation of the templates happens with the `evaluate` function on the interpreter:

```swift
template.evaluate("{{ 1 + 2 }}")
```

The result of the evaluation - in case of templates - is always a `String`. In the result you shouldn't see any template elements, because they were recognised, processed, and replaced during the evaluation by the interpreter.

### Context

You can also pass contextual values, which - for now - equal to variables.

```swift
template.evaluate("{{ 1 + var }}", context: InterpreterContext(variables: ["var": 2]))
```

The reason that the variables are encapsulated in a context is that context is a class, while variables are mutable `var` struct properties on that object. With this construction the context reference can be passed around to multiple interpreter instances, but keeps the copy-on-write (🐮) behaviour of the modification.

Context defined during the initialisation apply to every evaluation performed with the given interpreter, while the ones passed to the `evaluate` method only apply to that specific  expression instance.

If some patterns modify the context, they have the option to modify the general context (for long term settings), or the local one (for example, the interation variable of a `for` loop).

### Order of statements define precedence

The earlier a pattern is represent in the array of `statements`, the higher precedence it gets. 
Practically, if there is an `if` statement and an `if-else` one, the `if-else` should be defined earlier, because both are going to match the following expression:
`{% if x < 0 %}A{% else %}B{% endif %}`, but if `if` goes first, then the output - and the `body` of the `if` statement - is going to be processed as `A{% else %}B`. 

Typically, parentheses and richer type of expressions should go earlier in the array.
