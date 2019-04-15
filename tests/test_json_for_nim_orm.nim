import ../orm_sqlite
import strutils

import json 

type User = object of Model
  name: string
  password: string
  age: int
  ratio: float
  happy: bool

Model.open(r"d:\Projects\Nim\nim-orm2\tests\mytest.db", "", "", "")

var password = "abc"
var name = "ann"

var users: seq[ref User]
users = newSeq[ref User]()

for x in User:
  users.add(x)
  # (name: "joe", password: "123", age: 22, ratio: 1.2, happy: true, loaded: ..., stored: ..., row: ...)
  # name
  # password
  # age
  # ratio
  # happy
  # loaded
  # stored
  # row
for x in users:
  for k,v in x[].fieldPairs:
    when compiles(v):
      echo k, v
  
var context = %* {"title": "Title from nim", "users": users, "baa": "Baa!"}
echo context
