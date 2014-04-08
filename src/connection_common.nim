import packets, tables, fowltek/maybe_t

type
  UserTable* = object
    users*: seq[TUser]
    name2user*: TTable[string,int]

proc save* (ut:var usertable; user:TUser) =
  ut.users.ensureLen user.id+1
  ut.users[user.id] = user
  ut.name2user[user.name] = user.id

proc find* (ut:var userTable; user: TInteger): TMaybe[ptr TUser] =
  let user = user.int
  if user in 0 .. len(ut.users)-1 and not ut.users[user].name.isNil:
    result = just(ut.users[user].addr)

proc initUsertable* : UserTable =
  result.users.newSeq 0
  result.name2user = initTable[string,int](32)
