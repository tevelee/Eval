# Example projects

I included a few use-cases, which bring significant improvements on how things are processed before - at least in my previous projects.
​
### [Template language](https://github.com/tevelee/Eval/blob/master/Examples/TemplateExample/Tests/TemplateExampleTests/TemplateExampleTests.swift)

I was able to create a full-blown template language, completely, using this framework and nothing else. It's almost like a competitor of the one I mentioned ([Twig](https://github.com/twigphp/Twig)). This is the most advanced example of them all!

I created a standard library with all the possible operators you can imagine. With helpers, each operator is a small, one-liner addition. Added the important data types, such as arrays, strings, numbers, booleans, dates, etc., and a few functions, to be more awesome. [Take a look for inspiration!](https://github.com/tevelee/Eval/blob/master/Examples/TemplateExample/Sources/TemplateExample/TemplateExample.swift)

Together, it makes an excellent addition to my model-object generation project, and **REALLY useful for server-side Swift development as well**!

### [Attributed string parser](https://github.com/tevelee/Eval/blob/master/Examples/AttributedStringExample/Tests/AttributedStringExampleTests/AttributedStringExampleTests.swift)

I created another small example, parsing attribtuted strings from simple expressions using XML style tags, such as bold, italic, underlined, colored, etc.

With just a few operators, this solution can deliver attributed strings from basic APIs, which otherwise would be hard to manage.

My connected project is an iOS application, using the Spotify [HUB framework](https://github.com/spotify/HubFramework), in which I can now provide rich strings with my view-models and parse them from the JSON string results.

### [Color parser](https://github.com/tevelee/Eval/blob/master/Examples/ColorParserExample/Tests/ColorParserExampleTests/ColorParserExampleTests.swift)

A color parser is also used by the BFF (Backend For Frontend, not 👭) project I mentioned before. It can parse Swift Color objects from many different styles of strings, such as `#ffddee`, or `red`, or `rgba(1,0.5,0.4,1)`. I included this basic example in the repository as well.

