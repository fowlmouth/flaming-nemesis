import packets, tables, fowltek/maybe_t

type
  UserInterface* = generic u
    u.id is int
    u.name is string

  UserTable* [T] = object
    users*: seq[T]
    name2user*: TTable[string,int]

proc save* [T] (ut:var usertable[T]; user: T) =
  ut.users.ensureLen user.id+1
  ut.users[user.id] = user
  ut.name2user[user.name] = user.id

proc find* [T] (ut:var userTable[T]; user: TInteger): TMaybe[ptr T] =
  # get a temporary pointer to the TUser record
  let user = user.int
  if user in 0 .. len(ut.users)-1:
    let u = ut.users[user].addr
    if not u.isNil and not u.name.isNil:
      return just(u)

proc init* [T] (ut:var userTable[T]) =
  assert T is UserInterface
  ut.users.newSeq 0
  ut.name2user = initTable[string,int](32)


