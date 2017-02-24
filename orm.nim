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

import macros, strutils
from typetraits import nil

when not declared(DBConn):
  {.error: """orm is not intended to be used directly, use wrappers, eg.:
import orm_sqlite   # for sqlite
import orm_mysql    # for mysql
import orm_postgres # for postgres""".}

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
    loaded: set[int8] ## maintains list of fields loaded from db
    stored: set[int8] ## maintains list of fields to be stored in the db
    row: InstantRow

var db : DBConn = nil

# Generic type handling helpers ################################################

proc objectTyFieldList(objectTy: NimNode): seq[string] {.compileTime.} =
  result = newSeq[string]()
  let recList = objectTy[1]
  for field in children(recList):
    result.add($field)
  if not objectTy[0].sameType bindsym"Model":
    for fieldName in objectTyFieldList(objectTy[0].getType):
      result.add(fieldName)

proc objectTyFieldIndex(objectTy: NimNode, name: NimNode): int32
  {.compileTime.} =
  let recList = objectTy[1]
  var index: int32 = 0
  for field in children(recList):
    if field == name:
      return index
    index += 1
  if not objectTy[0].sameType bindsym"Model":
    return index + objectTyFieldIndex(objectTy[0].getType, name)
  result = index

proc quote(list: seq[string]): seq[string] {.compileTime.} =
  result = newSeq[string]()
  for item in list:
    result.add("`" & item & "`")

macro fieldIndex*(sym: Model, field: expr): expr =
  ## Returns index of the field in the object record
  newLit(objectTyFieldIndex(sym.getType, field))

# not used currently but I don't want to remove this yet from the code
when false:
  macro fieldList*(sym: Model): expr =
    ## Returns index of the field in the object record
    newLit(objectTyFieldList(sym.getType).join(", "))

  macro fieldList*(sym: typedesc[Model]): expr =
    ## Returns index of the field in the object record
    newLit(objectTyFieldList(sym.getType[1].getType).join(", "))

# Database handling and object iteration #######################################

proc open*(T: typedesc[Model], connection, user, password, database: string) =
  ## Opens database for ORM.
  db = open(connection, user, password, database)

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
  exec(db, sql(query), args)

iterator fetch*[T: Model](t: typedesc[T], query: string,
                          args: varargs[string, `$`]): ref T =
  ## Executes query with current db API handle and fetches results as instances
  ## of T < Model.
  for row in instantRows(db, sql(query), args):
    var model : ref T
    new(model)
    {.noRewrite.}: ({.noRewrite.}: model.row) = row
    yield model

macro where*(T: typedesc[Model], st: untyped): untyped =
  ## Generates SQL query out of untyped expression and returns call to fetch
  ## iterator with generated SQL query as argument and all not resolved
  ## subexpressions.
  var args = newSeq[NimNode]()
  let queryFields = T.getType[1].getType.objectTyFieldList.quote.join(", ")
  let query = "SELECT " & queryFields & " FROM " & T.repr &
              " WHERE " & genWhere(T, st, args)
  result = newNimNode(nnkCall)
    .add(bindSym"fetch")
    .add(newIdentNode(T.repr))
    .add(newLit(query))
    .add(args)

# Field load handling ##########################################################

template loadField(T: typedesc[string], user: Model, field: int32): string =
  ## Loads simple string from db
  `[]`(({.noRewrite.}: user.row), field)

template loadField(T: typedesc[int], user: Model, field: int32): int =
  ## Loads int field out of string
  parseInt(loadField(string, user, field))

template loadField(T: typedesc[float], user: Model, field: int32): float =
  ## Loads float field out of string
  parseFloat(loadField(string, user, field))

template loadField(T: typedesc[bool], user: Model, field: int32): bool =
  ## Loads bool field out of string
  parseBool(loadField(string, user, field))

template ormLoad*{user.field}(user: Model, field: untyped{field}): untyped =
  ## Rewrites all model field access to deferred loads
  if fieldIndex(user, field) notin ({.noRewrite.}: user.loaded):
    incl(({.noRewrite.}: user.loaded), fieldIndex(user, field))
    {.noRewrite.}: ({.noRewrite.}: user.field) =
      loadField(type(user.field), user, fieldIndex(user, field))
  {.noRewrite.}: user.field

# Field store handling #########################################################

template ormStore*{user.field = value}(user: Model,
                                       field: untyped{field},
                                       value: untyped): expr =
  ## Rewrites all model field store to mark which fields were stored actually
  if fieldIndex(user, field) notin ({.noRewrite.}: user.stored):
    incl(({.noRewrite.}: user.loaded), fieldIndex(user, field))
    incl(({.noRewrite.}: user.stored), fieldIndex(user, field))
  {.noRewrite.}: ({.noRewrite.}: user.field) = value

proc save*(user: Model) =
  raise newException(FieldError, "not implemented")

proc save*(user: ref Model) =
  raise newException(FieldError, "not implemented")
