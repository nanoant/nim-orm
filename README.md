Object-relational mapping for Nim
---------------------------------

[nim]: http://nim-lang.org

This is ORM module for [Nim][nim] language and its `db_sqlite`, `db_mysql` and
`db_postgres` standard database modules.

Importing `orm` requires one of `sqlite`, `mysql` or `postgres` defines, since
ORM module imports on of the databases.

### Features

1. Turning Nim expressions into SQL syntax at compile time
2. **WIP** Iterating through model objects based on given `where(...)`
3. **NYI** Storing model object changes via `save()`

### Usage

1. Iterating through model objects based on given expression

```nim
var password = "abc"
var name = "ann"

# expected: joe, ann
for user in User.where((@password == "123" or @password == password) and
                       (@name == "joe" or @name == name)):
  echo user.name
```

### Discussion

Nim has powerful AST rewriting capabilities via compile-time macros, this leads
us to amazing optimizations while keeping application code nice, clean & at
higher level.

Currently the module translates expressions into SQL calls at compile time, eg.:

```nim
var password = "abc"
var name = "ann"

for user in User.where((@password == "123" or @password == password) and
                       (@name == "joe" or @name == name)):
```

is translated to:

```nim
for user in User.fetch("SELECT * FROM `User` where
                        (`User`.`password` = '123' OR `User`.`password` = ?) AND
                        (`User`.`name` = 'joe' OR `User`.`name` = ?)",
                       password, name):
```

[ruby]: https://www.ruby-lang.org/
[activemodel]: https://github.com/rails/rails/tree/master/activemodel

Comparing to other solutions such as [ActiveModel][activemodel] from
[Ruby][ruby] where such translation is done at runtime level, we got great
performance boost and syntax error diagnostics already there at compile-time.

### License

This module is released under MIT license:

> Copyright (C) 2015 Adam Strzelecki
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.
