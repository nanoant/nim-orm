import ../orm_sqlite
import macros

type User = object of Model

Model.open("", "", "", "")
Model.exec("CREATE TABLE User(name varchar(32), password varchar(32))", [])
Model.exec("INSERT INTO User VALUES('joe', '123')", [])
Model.exec("INSERT INTO User VALUES('ann', 'abc')", [])

var password = "abc"
var name = "ann"

# expected: joe, ann
for u in User.where((@password == "123" or @password == password) and
                    (@name == "joe" or @name == name)):
  echo u[0]

# expected: ann
for u in User.where(@password == "abc"):
  echo u[0]
