# Released under MIT license
#
# Copyright (C) 2015 Adam Strzelecki
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

import macros

## This module implements ORM (Object-relational mapping) for Nim's db
## interfaces.

type
  Model = object

proc genQuery(T: typedesc[Model], n: NimNode, args: var seq[NimNode]): string
  {.compileTime.} =
  ## Generates SQL query out of expr AST
  const sqlInfixOps = [
    ("==",  "="),
    ("!=",  "<>"),
    ("&",   "||"),
    ("and", "AND"),
    ("or",  "OR"),
  ]
  case n.kind:
  # parenthesis
  of nnkPar:
    return "(" & genQuery(T, n[0], args) & ")"
  # process all infix operators
  of nnkInfix:
    let ident = $n[0].ident
    case ident:
    # common Nim and SQL operators
    of "+", "-", "*", "/", "%", "<", "<=", ">", ">=":
      return genQuery(T, n[1], args) & " " & ident & " " &
             genQuery(T, n[2], args)
    else:
      # check for Nim to SQL operator conversion
      for i in 0..sqlInfixOps.len-1:
        if $n[0].ident == sqlInfixOps[i][0]:
          return genQuery(T, n[1], args) & " " & sqlInfixOps[i][1] & " " &
                 genQuery(T, n[2], args)
  # integer literal
  of nnkIntLit:
      return $n.intVal
  # string literal
  of nnkStrLit:
      return "'" & $n.strVal & "'"
  # prefix, we only accept @ prefix for field names
  of nnkPrefix:
    if $n[0].ident == "@":
      return "`" & T.repr & "`.`" & $n[1].ident & "`"
  else: discard
  args.add(n)
  result = "?"

proc execQuery*(T: typedesc[Model], query: string, args: varargs[string, `$`]) =
  ## Generates SQL query with given arguments
  echo "query=", query # NYI
  echo "args=", args.repr

macro where*(T: typedesc[Model], st: untyped): stmt =
  ## Generates SQL query out of statement and executes it
  var args = newSeq[NimNode]()
  result = newCall(newDotExpr(newIdentNode(T.repr), bindSym"execQuery"),
                   newLit(genQuery(T, st, args)))
  result.add(args)

# ---

when isMainModule:

  type User = Model

  var password = "ABC"
  var name = "joe"

  User.where((@password == "abc" or @password == password) and
             (@name == "joe" or @name == name))
