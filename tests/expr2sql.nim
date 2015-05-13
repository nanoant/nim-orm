import ../orm_sqlite
import macros
import strutils

type User = object of Model
  name : string
  password : string

Model.open("", "", "", "")
Model.exec("CREATE TABLE User(name varchar(32), password varchar(32))", [])
Model.exec("INSERT INTO User VALUES('joe', '123')", [])
Model.exec("INSERT INTO User VALUES('ann', 'abc')", [])

var password = "abc"
var name = "ann"

# expected: joe, ann
for u in User.where((@password == "123" or @password == password) and
                    (@name == "joe" or @name == name)):
  echo "`$1' has password `$2'" % [ u.name, u.password ]

# expected: ann
for u in User.where(@password == "abc"):
  echo "`$1' has password `$2'" % [ u.name, u.password ]
