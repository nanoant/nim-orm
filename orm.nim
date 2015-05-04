import strutils
from typetraits import nil

type
  Model = object

  ORMStmt = object
    query: string
    # args: seq[string] # <- enabling that causes string concat
                        #    compile time folding no longer work

  User = Model

template `.`(T: typedesc[Model], f: string): ORMStmt =
  ORMStmt(query: typetraits.name(T) & "." & f,
          # args: @[]
          )

template `and`(a: ORMStmt, b: ORMStmt): ORMStmt =
  ORMStmt(query: "(" & a.query & " AND " & b.query & ")",
          # args: a.args & b.args
          )

template `or`(a: ORMStmt, b: ORMStmt): ORMStmt =
  ORMStmt(query: "(" & a.query & " OR " & b.query & ")",
          # args: a.args & b.args
          )

template `==`(st: ORMStmt, str: string): ORMStmt =
  ORMStmt(query: st.query & " == \"$#\"",
          # args: st.args & @[str]
          )

template `==`(st: ORMStmt, i): ORMStmt =
  ORMStmt(query: st.query & " == $#",
          # args: st.args & @[$i]
          )

proc `$`(st: ORMStmt): string =
  # st.query % st.args
  st.query

# echo User.id
echo User.id == 1 and User.name == "adam" or User.pw == "1234"
