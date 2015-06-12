import ../orm_sqlite
import strutils

type User = object of Model
  name: string
  password: string
  age: int
  ratio: float
  happy: bool

Model.open("", "", "", "")
Model.exec("""CREATE TABLE User(
  name     VARCHAR(32),
  password VARCHAR(32),
  age      INT,
  ratio    FLOAT,
  happy    BOOL)""", [])
Model.exec("INSERT INTO User VALUES('joe', '123', 22, 1.2, 1)", [])
Model.exec("INSERT INTO User VALUES('ann', 'abc', 31, 1.4, 0)", [])

var password = "abc"
var name = "ann"

# expected: joe, ann
for user in User.where((@password == "123" or @password == password) and
                       (@name == "joe" or @name == name)):
  echo "`$1' has password `$2'" % [ user.name, user.password ]
  echo "age of ", user.age
  echo "ratio of ", user.ratio
  echo "happy is ", user.happy

# expected: ann
for user in User.where(@password == "abc"):
  echo "`$1' has password `$2' age" % [ user.name, user.password ]
  user.password = "test"
  user.save #<- NYI
