import strutils
from typetraits import nil

type
  Model = object

  ORMStmt = object
    query: string
    when defined(ormargs):
      args: seq[string] # <- enabling that causes string concat
                        #    compile time folding no longer work

  User = Model

template `.`(T: typedesc[Model], f: string): ORMStmt =
  when defined(ormargs):
    ORMStmt(query: typetraits.name(T) & "." & f,
            args: @[])
  else:
    ORMStmt(query: typetraits.name(T) & "." & f)

template `and`(a: ORMStmt, b: ORMStmt): ORMStmt =
  when defined(ormargs):
    ORMStmt(query: "(" & a.query & " AND " & b.query & ")",
            args: a.args & b.args)
  else:
    ORMStmt(query: "(" & a.query & " AND " & b.query & ")")

template `or`(a: ORMStmt, b: ORMStmt): ORMStmt =
  when defined(ormargs):
    ORMStmt(query: "(" & a.query & " OR " & b.query & ")",
            args: a.args & b.args)
  else:
    ORMStmt(query: "(" & a.query & " OR " & b.query & ")")

template `==`(st: ORMStmt, str: string): ORMStmt =
  when defined(ormargs):
    ORMStmt(query: st.query & " == \"$#\"",
            args: st.args & @[str])
  else:
    ORMStmt(query: st.query & " == \"$#\"")

template `==`(st: ORMStmt, i): ORMStmt =
  when defined(ormargs):
    ORMStmt(query: st.query & " == $#",
            args: st.args & @[$i])
  else:
    ORMStmt(query: st.query & " == $#")

proc `$`(st: ORMStmt): string =
  when defined(ormargs):
    st.query % st.args
  else:
    st.query

echo User.id == 1 and User.name == "adam" or User.pw == "1234"
