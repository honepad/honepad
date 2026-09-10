import std/[json, os, options]

include solution

when declared(Simulation):
  type Target = Simulation
  proc newTarget(): Target =
    Simulation()
elif declared(InMemoryDatabase):
  type Target = InMemoryDatabase
  proc newTarget(): Target =
    InMemoryDatabase()
else:
  {.error: "solution must define Simulation or InMemoryDatabase".}

proc argInt(args: JsonNode; i: int): int64 =
  args[i].getBiggestInt

proc argStr(args: JsonNode; i: int): string =
  args[i].getStr

proc toNode[T](value: T): JsonNode =
  when T is bool:
    result = %value
  elif T is int or T is int64:
    result = %value
  elif T is string:
    result = %value
  elif T is seq[string]:
    result = %value
  elif T is Option[int64]:
    result = if value.isSome: %value.get else: newJNull()
  elif T is Option[string]:
    result = if value.isSome: %value.get else: newJNull()
  else:
    raise newException(ValueError, "unsupported return type")

proc missing(methodName: string) =
  raise newException(ValueError, "missing method " & methodName)

proc dispatch(obj: var Target; methodName: string; args: JsonNode): JsonNode =
  case methodName
  of "create_account":
    when compiles(obj.createAccount(0'i64, "")):
      result = toNode(obj.createAccount(argInt(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "deposit":
    when compiles(obj.deposit(0'i64, "", 0'i64)):
      result = toNode(obj.deposit(argInt(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "transfer":
    when compiles(obj.transfer(0'i64, "", "", 0'i64)):
      result = toNode(
        obj.transfer(argInt(args, 0), argStr(args, 1), argStr(args, 2), argInt(args, 3))
      )
    else:
      missing(methodName)
  of "top_spenders":
    when compiles(obj.topSpenders(0'i64, 0'i64)):
      result = toNode(obj.topSpenders(argInt(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "pay":
    when compiles(obj.pay(0'i64, "", 0'i64)):
      result = toNode(obj.pay(argInt(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "get_payment_status":
    when compiles(obj.getPaymentStatus(0'i64, "", "")):
      result = toNode(obj.getPaymentStatus(argInt(args, 0), argStr(args, 1), argStr(args, 2)))
    else:
      missing(methodName)
  of "merge_accounts":
    when compiles(obj.mergeAccounts(0'i64, "", "")):
      result = toNode(obj.mergeAccounts(argInt(args, 0), argStr(args, 1), argStr(args, 2)))
    else:
      missing(methodName)
  of "get_balance":
    when compiles(obj.getBalance(0'i64, "", 0'i64)):
      result = toNode(obj.getBalance(argInt(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "add_file":
    when compiles(obj.addFile("", 0'i64)):
      result = toNode(obj.addFile(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "get_file_size":
    when compiles(obj.getFileSize("")):
      result = toNode(obj.getFileSize(argStr(args, 0)))
    else:
      missing(methodName)
  of "delete_file":
    when compiles(obj.deleteFile("")):
      result = toNode(obj.deleteFile(argStr(args, 0)))
    else:
      missing(methodName)
  of "copy_file":
    when compiles(obj.copyFile("", "")):
      result = toNode(obj.copyFile(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "get_n_largest":
    when compiles(obj.getNLargest("", 0'i64)):
      result = toNode(obj.getNLargest(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "add_user":
    when compiles(obj.addUser("", 0'i64)):
      result = toNode(obj.addUser(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "add_file_by":
    when compiles(obj.addFileBy("", "", 0'i64)):
      result = toNode(obj.addFileBy(argStr(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "merge_user":
    when compiles(obj.mergeUser("", "")):
      result = toNode(obj.mergeUser(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "backup_user":
    when compiles(obj.backupUser("")):
      result = toNode(obj.backupUser(argStr(args, 0)))
    else:
      missing(methodName)
  of "restore_user":
    when compiles(obj.restoreUser("")):
      result = toNode(obj.restoreUser(argStr(args, 0)))
    else:
      missing(methodName)
  of "add_worker":
    when compiles(obj.addWorker("", "", 0'i64)):
      result = toNode(obj.addWorker(argStr(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "register":
    when compiles(obj.register("", 0'i64)):
      result = toNode(obj.register(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "get":
    if args.len == 1:
      when compiles(obj.get("")):
        result = toNode(obj.get(argStr(args, 0)))
      else:
        missing(methodName)
    else:
      when compiles(obj.get("", "")):
        result = toNode(obj.get(argStr(args, 0), argStr(args, 1)))
      else:
        missing(methodName)
  of "top_n_workers":
    when compiles(obj.topNWorkers(0'i64, "")):
      result = toNode(obj.topNWorkers(argInt(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "promote":
    when compiles(obj.promote("", "", 0'i64, 0'i64)):
      result = toNode(
        obj.promote(argStr(args, 0), argStr(args, 1), argInt(args, 2), argInt(args, 3))
      )
    else:
      missing(methodName)
  of "set_double_pay":
    when compiles(obj.setDoublePay("", 0'i64, 0'i64)):
      result = toNode(obj.setDoublePay(argStr(args, 0), argInt(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "create_item":
    when compiles(obj.createItem("", "")):
      result = toNode(obj.createItem(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "allow":
    when compiles(obj.allow("", 0'i64)):
      result = toNode(obj.allow(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "configure":
    when compiles(obj.configure("", 0'i64, 0'i64)):
      result = toNode(obj.configure(argStr(args, 0), argInt(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "remaining":
    when compiles(obj.remaining("", 0'i64)):
      result = toNode(obj.remaining(argStr(args, 0), argInt(args, 1)))
    elif compiles(obj.remaining("")):
      result = toNode(obj.remaining(argStr(args, 0)))
    else:
      missing(methodName)
  of "allow_weighted":
    when compiles(obj.allowWeighted("", 0'i64, 0'i64)):
      result = toNode(obj.allowWeighted(argStr(args, 0), argInt(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "stock":
    when compiles(obj.stock("", 0'i64)):
      result = toNode(obj.stock(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "get_qty":
    when compiles(obj.getQty("")):
      result = toNode(obj.getQty(argStr(args, 0)))
    else:
      missing(methodName)
  of "list_low":
    when compiles(obj.listLow(0'i64)):
      result = toNode(obj.listLow(argInt(args, 0)))
    else:
      missing(methodName)
  of "reserve":
    when compiles(obj.reserve("", 0'i64)):
      result = toNode(obj.reserve(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "release":
    when compiles(obj.release("", 0'i64)):
      result = toNode(obj.release(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "ship":
    when compiles(obj.ship("", 0'i64)):
      result = toNode(obj.ship(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "calc_salary":
    when compiles(obj.calcSalary("", 0'i64, 0'i64)):
      result = toNode(obj.calcSalary(argStr(args, 0), argInt(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "set":
    when compiles(obj.set("", "", "")):
      result = toNode(obj.set(argStr(args, 0), argStr(args, 1), argStr(args, 2)))
    else:
      missing(methodName)
  of "delete":
    when compiles(obj.delete("", "")):
      result = toNode(obj.delete(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "scan":
    when compiles(obj.scan("")):
      result = toNode(obj.scan(argStr(args, 0)))
    else:
      missing(methodName)
  of "scan_by_prefix":
    when compiles(obj.scanByPrefix("", "")):
      result = toNode(obj.scanByPrefix(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "set_at":
    when compiles(obj.setAt("", "", "", 0'i64)):
      result = toNode(
        obj.setAt(argStr(args, 0), argStr(args, 1), argStr(args, 2), argInt(args, 3))
      )
    else:
      missing(methodName)
  of "set_at_with_ttl":
    when compiles(obj.setAtWithTtl("", "", "", 0'i64, 0'i64)):
      result = toNode(
        obj.setAtWithTtl(
          argStr(args, 0), argStr(args, 1), argStr(args, 2), argInt(args, 3), argInt(args, 4)
        )
      )
    else:
      missing(methodName)
  of "delete_at":
    when compiles(obj.deleteAt("", "", 0'i64)):
      result = toNode(obj.deleteAt(argStr(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "get_at":
    when compiles(obj.getAt("", "", 0'i64)):
      result = toNode(obj.getAt(argStr(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "scan_at":
    when compiles(obj.scanAt("", 0'i64)):
      result = toNode(obj.scanAt(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "scan_by_prefix_at":
    when compiles(obj.scanByPrefixAt("", "", 0'i64)):
      result = toNode(obj.scanByPrefixAt(argStr(args, 0), argStr(args, 1), argInt(args, 2)))
    else:
      missing(methodName)
  of "backup":
    when compiles(obj.backup(0'i64)):
      result = toNode(obj.backup(argInt(args, 0)))
    else:
      missing(methodName)
  of "restore":
    when compiles(obj.restore(0'i64, 0'i64)):
      result = toNode(obj.restore(argInt(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "add_gpu":
    when compiles(obj.addGpu("", 0'i64)):
      result = toNode(obj.addGpu(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "submit_job":
    when compiles(obj.submitJob("", 0'i64)):
      result = toNode(obj.submitJob(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "status":
    when compiles(obj.status("")):
      result = toNode(obj.status(argStr(args, 0)))
    else:
      missing(methodName)
  of "assign":
    when compiles(obj.assign()):
      result = toNode(obj.assign())
    else:
      missing(methodName)
  of "complete":
    when compiles(obj.complete("")):
      result = toNode(obj.complete(argStr(args, 0)))
    else:
      missing(methodName)
  of "cancel":
    when compiles(obj.cancel("")):
      result = toNode(obj.cancel(argStr(args, 0)))
    else:
      missing(methodName)
  of "set_priority":
    when compiles(obj.setPriority("", 0'i64)):
      result = toNode(obj.setPriority(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "add_backend":
    when compiles(obj.addBackend("")):
      result = toNode(obj.addBackend(argStr(args, 0)))
    else:
      missing(methodName)
  of "route":
    when compiles(obj.route()):
      result = toNode(obj.route())
    else:
      missing(methodName)
  of "set_health":
    when compiles(obj.setHealth("", 0'i64)):
      result = toNode(obj.setHealth(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "set_weight":
    when compiles(obj.setWeight("", 0'i64)):
      result = toNode(obj.setWeight(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "sticky":
    when compiles(obj.sticky("")):
      result = toNode(obj.sticky(argStr(args, 0)))
    else:
      missing(methodName)
  of "done":
    when compiles(obj.done("")):
      result = toNode(obj.done(argStr(args, 0)))
    else:
      missing(methodName)
  of "subscribe":
    when compiles(obj.subscribe("", "")):
      result = toNode(obj.subscribe(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "unsubscribe":
    when compiles(obj.unsubscribe("", "")):
      result = toNode(obj.unsubscribe(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "publish":
    when compiles(obj.publish("", "")):
      result = toNode(obj.publish(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "inbox":
    when compiles(obj.inbox("")):
      result = toNode(obj.inbox(argStr(args, 0)))
    else:
      missing(methodName)
  of "list_topics":
    when compiles(obj.listTopics()):
      result = toNode(obj.listTopics())
    else:
      missing(methodName)
  of "subscribers":
    when compiles(obj.subscribers("")):
      result = toNode(obj.subscribers(argStr(args, 0)))
    else:
      missing(methodName)
  of "peek":
    when compiles(obj.peek("")):
      result = toNode(obj.peek(argStr(args, 0)))
    else:
      missing(methodName)
  of "ack":
    when compiles(obj.ack("", 0'i64)):
      result = toNode(obj.ack(argStr(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "retain":
    when compiles(obj.retain("", "")):
      result = toNode(obj.retain(argStr(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "insert":
    when compiles(obj.insert(0'i64, "")):
      result = toNode(obj.insert(argInt(args, 0), argStr(args, 1)))
    else:
      missing(methodName)
  of "erase":
    when compiles(obj.erase(0'i64, 0'i64)):
      result = toNode(obj.erase(argInt(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "get_text":
    when compiles(obj.getText()):
      result = toNode(obj.getText())
    else:
      missing(methodName)
  of "length":
    when compiles(obj.length()):
      result = toNode(obj.length())
    else:
      missing(methodName)
  of "move":
    when compiles(obj.move(0'i64)):
      result = toNode(obj.move(argInt(args, 0)))
    else:
      missing(methodName)
  of "type_text":
    when compiles(obj.typeText("")):
      result = toNode(obj.typeText(argStr(args, 0)))
    else:
      missing(methodName)
  of "cursor":
    when compiles(obj.cursor()):
      result = toNode(obj.cursor())
    else:
      missing(methodName)
  of "undo":
    when compiles(obj.undo()):
      result = toNode(obj.undo())
    else:
      missing(methodName)
  of "redo":
    when compiles(obj.redo()):
      result = toNode(obj.redo())
    else:
      missing(methodName)
  of "select":
    when compiles(obj.select(0'i64, 0'i64)):
      result = toNode(obj.select(argInt(args, 0), argInt(args, 1)))
    else:
      missing(methodName)
  of "cut":
    when compiles(obj.cut()):
      result = toNode(obj.cut())
    else:
      missing(methodName)
  of "copy_sel":
    when compiles(obj.copySel()):
      result = toNode(obj.copySel())
    else:
      missing(methodName)
  of "paste":
    when compiles(obj.paste()):
      result = toNode(obj.paste())
    else:
      missing(methodName)
  else:
    raise newException(ValueError, "unknown method " & methodName)

proc failRow(
    caseId: string; index: int; methodName: string; expected, actual: JsonNode
): JsonNode =
  result = newJObject()
  result["case"] = %caseId
  result["index"] = %index
  result["method"] = %methodName
  result["expected"] = expected
  result["actual"] = actual

proc main() =
  if paramCount() < 1:
    stderr.writeLine("usage: adapter cases.json")
    quit(2)
  let cases = parseFile(paramStr(1))
  if cases.kind != JArray:
    stderr.writeLine("cases.json must be a JSON list")
    quit(2)
  var failed = newJArray()
  var passed = 0
  for row in cases:
    var obj = newTarget()
    let caseId = row["id"].getStr
    let calls = row["calls"]
    var ok = true
    for i, call in calls.getElems:
      let methodName = call["m"].getStr
      let expected = call["e"]
      let args = call["a"]
      var actual: JsonNode
      try:
        actual = dispatch(obj, methodName, args)
      except CatchableError as exc:
        failed.add(failRow(caseId, i, methodName, expected, %("exc:" & exc.msg)))
        ok = false
        break
      if actual != expected:
        failed.add(failRow(caseId, i, methodName, expected, actual))
        ok = false
        break
    if ok:
      inc passed
  var report = newJObject()
  report["passed"] = %passed
  report["failed"] = failed
  echo $report
  if failed.len > 0:
    quit(1)

main()
