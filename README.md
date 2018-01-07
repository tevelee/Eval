# { Eval }

[![](https://travis-ci.org/tevelee/Eval.svg?branch=master)](https://travis-ci.org/tevelee/Eval)
[![](https://img.shields.io/badge/Version-1.0.0-yellow.svg)]()
[![](https://img.shields.io/badge/Swift-4.0-green.svg)]()
[![Documentation](https://tevelee.github.io/Eval/badge.svg)](https://tevelee.github.io/Eval)
[![](https://img.shields.io/badge/Coverage-No%20Data-red.svg)]()
[![](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE.txt)

- [👨🏻‍💻 About](#-about)
- [📈 Getting Started](#-getting-started)
	- [🤓 Short Example](#-short-example)
	- [⁉️ How does it work?](#%EF%B8%8F-how-does-it-work)
- [🏃🏻 Status](#-status)
- [💡 Motivation](#-motivation)
- [📚 Examples](#-examples)
- [🙋 Contribution](#-contribution)
- [👀 Details](#-details)
- [👤 Author](#-author)
- [⚖️ License](#%EF%B8%8F-license)

## 👨🏻‍💻 About

**Eval** is a lightweight interpreter framework written in <img src="http://www.swiftapplications.com/wp-content/uploads/2016/04/swift-logo.png" width="16"> Swift, for 📱iOS, 🖥 macOS, and 🐧Linux platforms.

It evaluates expressions at runtime, with operators and data types you define.

🍏 Pros | 🍎 Cons
------- | --------
🐥 Lightweight - the whole engine is really just a few hundred lines of code | 🤓 Creating custom operators and data types, on the other hand, can take a few extra lines - depending on your needs
✅ Easy to use API - create new language elements in just a matter of seconds | ♻️ The evaluated result of the expressions must be strongly typed, so you can only accept what type you expect the result is going to be
🎢 Fun - Since it is really easy to play with, it's joyful to add - even complex - language features | -
🚀 Fast execution - I'm trying to optimise as much as possible. Has its limitations though | 🌧 Since it is a really generic concept, some optimisations cannot be made, compared to native interpreters

The framework currently supports two different types of execution modes:

- **Strongly typed expressions**: like a programming language
- **Template languages**: evaluating expressions in arbitrary string environments

*Let's see just a few examples:*

It's extremely easy to formulate expressions (and evaluate them at runtime), like 

- `5 in 1...3` evaluates to `false` Bool type
- `'Eval' starts with 'E'` evaluates to `true` Bool type
- `'b' in ['a','c','d']` evaluates to `false` Bool type
- `x < 2 ? 'a' : 'b'` evaluates to `"a"` or `"b"` String type, based on the `x` Int input variable
- `Date(2018, 12, 13).format('yyyy-MM-dd')` evaluates to `"2018-12-13"` string
- `'hello'.length` evaluates to `5` Integer
- `now` evaluates to `Date()`

And templates, such as

- `{% if name != nil %}Hello{% else %}Bye{% endif %} {{ name|default('user') }}!`, whose output is `Hello Adam!` or `Bye User!`
- `Sequence: {% for i in 1...5 %}{{ 2 * i }} {% endfor %}` which is `2 4 6 8 10 `

And so on... The result of these expressions depends on the content, determined by the evaluation. It can be any type which is returned by the functions (String, [Double], Date, or even custom types of your own.)

You can find various ways of usage in the examples section below.

## 🏃🏻 Status

- [x] Library implementation
- [x] API finalisation
- [x] Swift Package Manager support
- [x] Initial documentation
- [x] Example project (template engine)
- [ ] CocoaPods support
- [ ] CI
- [ ] Code test-coverage
- [ ] Fully detailed documentation
- [ ] Contribution guides
- [ ] Further example projects

## 📈 Getting started

For the expressions to work, you'll need to create an interpreter instance, providing your data types and expressions you aim to support, and maybe some input variables - if you need any.

```swift
let interpreter = TypedInterpreter(dataTypes: [number, string, boolean, array, date],
                                   functions: [multipication, addition, ternary],
                                   context: InterpreterContext(variables: ["x": 2.0]))
```

And call it with a string expression, as follows.

```swift                                   
let result = interpreter.evaluate("2*x + 1") as? Double
```

### 🤓 Short example

Let's check out a fairly complex example, and build it from scratch! Let's implement a language which can parse the following expression:

```swift
x != 0 ? 5 * x : pi + 1
```

There's a ternary operator `?:` in there, which we will need. Also, supporting number literals (`0`, `5`, and `1`) and boolean types (`true/false`). There's also a not equal operator `!=` and a `pi` constant. Let's not forget about the addition `+` and multiplication `*` as well!

First, here are the data types.

```swift
let numberLiteral = Literal { value,_ in Double(value) } //Converts every number literal, if it can be represented with a Double instance
let piConstant = Literal("pi", convertsTo: Double.pi)

let number = DataType(type: Double.self, literals: [numberLiteral, piConstant]) { String(describing: $0) }
```

```swift
let trueLiteral = Literal("true", convertsTo: true)
let falseLiteral = Literal("false", convertsTo: false)

let boolean = DataType(type: Bool.self, literals: [trueLiteral, falseLiteral]) { $0 ? "true" : "false" }
```

(The last parameter, expressed as a block, tells the framework how to formulise this type of data as a String for debug messages or other purposes)

Now, let's build the operators:

```swift
let multiplication = Function<Double>(Variable<Double>("lhs") + Keyword("*") + Variable<Double>("rhs")) { arguments in
    guard let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double else { return nil }
    return lhs * rhs
}
```
```swift
let addition = Function<Double>(Variable<Double>("lhs") + Keyword("+") + Variable<Double>("rhs")) { arguments in
    guard let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double else { return nil }
    return lhs + rhs
}
```
```swift
let notEquals = Function<Bool>(Variable<Double>("lhs") + Keyword("!=") + Variable<Double>("rhs")) { arguments in
    guard let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double else { return nil }
    return lhs != rhs
}
```
```swift
let ternary = Function<Any>(Variable<Bool>("condition") + Keyword("?") + Variable<Any>("true") + Keyword(":") + Variable<Any>("false")) { arguments in
    guard let condition = arguments["condition"] as? Bool else { return nil }
    if condition {
        return  arguments["true"]
    } else {
        return  arguments["false"]
    }
}
```

Looks like, we're all set. Let's evaluate our expression!

```swift
let interpreter = TypedInterpreter(dataTypes: [number, boolean],
                                   functions: [multipication, addition, notEquals, ternary])
                                   
let result : Double = interpreter.evaluate("x != 0 ? 5 * x : pi + 1", context: InterpreterContext(variables: ["x": 3.0]))
XCTAssertEqual(result, 15.0) //Pass!
```

Now, that we have operators and data types, we can also evaluate anything using these data types:

* `interpreter.evaluate("3 != 4") as Bool`
* `interpreter.evaluate("2 + 1.5 * 6") as Double` (since multiplication is defined earlier in the array, it has a higher precedence, as expected)
* `interpreter.evaluate("true ? 1 : 2.5") as Double`

-

As you have seen, it's really easy and intuitive to build custom languages, using simple building blocks. With just a few custom data types and functions, the possibilities are endless. Operators, functions, string, arrays, dates...

The motto of the framework: Build your own (mini) language!

### ⁉️ How does it work?

The interpreter itself does not define anything or any way to deal with the input string on its own. 
All it does is recognising patterns. 

By creating data types, you provide literals to the framework, which it can interpret as an element or a result of the expression. 
These types are transformed to real Swift types.

By defining functions, you provide patterns to the framework to recognise. 
Functions are also typed, they return Swift types as a result of their evaluation.
Functions consist of keywords and variables, nothing more. 

- Keywords are static strings which should not be interpreted as data (such as `if`, or `{`, `}`). 
- Variables, on the other hand, are typed values, recursively evaluated. For example, if a variable recognises something, that proves to be a further pattern, it recursively evaluates their body, until they find context-variables or literals of any given data type.

Functions also have blocks, which provide the recognised variables in a key-value dictionary parameter, and you can do whatever you want with them: print them, convert them, modify or assign them to context-variables. 

The addition function above, for example, consists of two variables on each side, and the `+` keyword in the middle. It also requires a block, where both sides are given in a `[String:Any]`, so the closure can get the values of the placeholders and add them together.

There's one interesting aspect of this solution: Unlike traditional - native - interpreters or compilers, this one recognises patterns from top to bottom. 
Meaning, that it looks at the input string, your expression, and recognises patterns in priority order, and recursively go deeper and deeper until the most basic expressions are met.

A traditional interpreter, however, parses expressions character by character, feeding the results to a lexer, the tokeniser, then builds up an abstract syntax tree (which is highly optimisable), and finally converts it to a binary (compiler) or evaluates it at runtime (interpreter), in one word: bottom-up.

The two solutions can be compared in various ways. The two main differences are in ease of use, and performance. 
This version of an interpreter provides an effortless way to define patterns, types, etc., but has its cost! It cannot parse as optimally as a traditional compiler could, as it doesn't have an internal graph of expressions (AST), but still performs in a much more than acceptable way.
Definition-wise, this framework provides an easily understandable way of language-elements, but the traditional one really lacks behind, because the lexer is usually an ugly, hardly understandable state machine, or regular expression, BAKED INTO the interpreter code itself.

## 💡 Motivation

I have another project, in which I'm generating Objective-C and Swift model objects with loads of utils, based on really short templates. This project was not possible currently in Swift, as there is no template language - capable enough - to create my templates. (I ended up using a third party PHP framework, called [Twig](https://github.com/twigphp/Twig)). So finally, I created one for Swift!

It turned out, that making it a little more generic - here and there - makes the whole thing really capable and flexible of using in different use-cases.

The pattern matching was there, but soon I realised, that I'm going to need expressions as well, for printing, evaluating in if/while statements and so on. First, I was looking at an excellent library, [Expression](https://github.com/nicklockwood/Expression), created by Nick Lockwood, which is capable of evaluating numeric expressions. Unfortunately, I wanted a bit more, defining strings, dates, array, and further types and expressions, so I used my existing pattern matching solution to bring this capability to life.

It ended up quite positively after I discovered the capabilities of a generic solution like this. The whole thing just blew my mind, language features could have been defined in a matter of seconds, and I wanted to share this discovery with the world, so here you are :)

## 📚 Examples
​
​I included a few use-cases, which bring significant improvements on how things are processed before - at least in my previous projects.
​
### [Template language](Examples/TemplateExample)

I was able to create a full-blown template language, completely, using this framework and nothing else. It's almost like a competitor of the one I mentioned ([Twig](https://github.com/twigphp/Twig)). This is the most advanced example of them all!

I created a standard library with all the possible operators you can imagine. With helpers, each operator is a small, one-liner addition. Added the important data types, such as arrays, strings, numbers, booleans, dates, etc., and a few functions, to be more awesome.

Together, it makes an excellent addition to my model-object generation project, and **REALLY useful for server-side Swift development as well**!

### [Attributed string parser](tbd)

I created another small example, parsing attribtuted strings from simple expressions using XML style tags, such as bold, italic, underlined, colored, etc.

With just a few operators, this solution can deliver attributed strings from basic APIs, which otherwise would be hard to manage.

My connected project is an iOS application, using the Spotify [HUB framework](https://github.com/spotify/HubFramework), in which I can now provide rich strings with my view-models and parse them from the JSON string results.

### [Color parser](tbd)

A color parser is also used by the BFF project I mentioned before. It can parse Swift Color objects from many different styles of strings, such as `#ffddee`, or `red`, or `rgba(1,0.5,0.4,1)`. I included this basic example in the repository as well.

## 🙋 Contribution

Anyone is more than welcome to contribute to **Eval**! It can even be an addition to the docs or to the code directly, by [raising an issue](https://github.com/tevelee/Interpreter/issues/new) or in the form of a pull request. Both are equally valuable to me! Happy to assist anyone!

In case you need help or want to report a bug - please file an issue. Make sure to provide as much information as you can; sample code also makes it a lot easier for me to help you. Check out the [contribution guidelines](CONTRIBUTE.md) for further information. 

I collected some use cases, and great opportunities for beginner tasks if anybody is motivated to bring this project to a more impressive state!

## 👀 Details

This is a really early stage of the project, so I'm still deep in the process of all the open-sourcing tasks, such as firing up a CI, creating a beautiful documentation page, managing administrative tasks around stability.

The upcoming Documentation pages will provide a deep-dive into the subtleties of this framework. Please stay tuned! 

## 👤 Author

I am Laszlo Teveli, software engineer, iOS evangelist.

Feel free to reach out to me anytime via tevelee [at] gmail [dot] com, or @tevelee on Twitter.

## ⚖️ License

**Eval** is available under the Apache 2.0 licensing rules. See the [LICENSE](LICENSE.txt) file for more information.