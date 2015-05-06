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
from typetraits import nil

when defined(sqlite):
  from db_sqlite as DB import nil
elif defined(postgres):
  from db_postgres as DB import nil
elif defined(mysql):
  from db_mysql as DB import nil

## This module implements ORM (Object-relational mapping) for Nim's db
## interfaces.

type
  Model* {.inheritable.} = object of RootObj
    ## represents abstract ORM model class
    ##
    ## All concrete model classes should inherit from this one.
    ## Example:
    ##
    ## .. code-block:: nim
    ##
    ##   type User = object of Model
    ##     name: string
    ##     password: string

var db : DB.TDBConn = nil

proc open*(T: typedesc[Model], connection, user, password, database: string) =
  ## Opens database for ORM.
  db = DB.open(connection, user, password, database)

proc genWhere*(T: typedesc[Model], n: NimNode, args: var seq[NimNode]): string
  {.compileTime.} =
  ## Generates SQL where out of expr AST.
  ## This is internal procedure.
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
    return "(" & genWhere(T, n[0], args) & ")"
  # process all infix operators
  of nnkInfix:
    let ident = $n[0].ident
    case ident:
    # common Nim and SQL operators
    of "+", "-", "*", "/", "%", "<", "<=", ">", ">=":
      return genWhere(T, n[1], args) & " " & ident & " " &
             genWhere(T, n[2], args)
    else:
      # check for Nim to SQL operator conversion
      for i in 0..sqlInfixOps.len-1:
        if $n[0].ident == sqlInfixOps[i][0]:
          return genWhere(T, n[1], args) & " " & sqlInfixOps[i][1] & " " &
                 genWhere(T, n[2], args)
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

proc exec*(T: typedesc[Model], query: string, args: varargs[string, `$`]) =
  ## Executes query with current db API handle, returns nothing.
  DB.exec(db, DB.sql(query), args)

iterator fetch*(T: typedesc[Model], query: string, args: varargs[string, `$`]):
  DB.TRow =
  ## Executes query with current db API handle and fetches results as instances
  ## of T < Model.
  for r in DB.rows(db, DB.sql(query), args): yield r

macro where*(T: typedesc[Model], st: untyped): expr =
  ## Generates SQL query out of untyped expression and returns call to fetch
  ## iterator with generated SQL query as argument and all not resolved
  ## subexpressions.
  var args = newSeq[NimNode]()
  let query = "SELECT * FROM " & T.repr & " WHERE " & genWhere(T, st, args)
  result = newNimNode(nnkCall)
    .add(bindSym"fetch")
    .add(newIdentNode("Model"))
    # FIXME: should be:
    # .add(newIdentNode(T.repr))
    # but crashes because of:
    # https://github.com/Araq/Nim/issues/2662
    .add(newLit(query))
    .add(args)
