# Workers level 2

`top_n_workers(n, position)` lists workers whose **current** position
matches.

Each item is `id(time)`. `time` is finished time in that position
only. A worker who never finished a session in the position still
appears as `id(0)` if `n` is large enough. Join items with `", "`.
Sort by time, high to low. If two times match, sort those ids A to Z.
No worker in that position returns `""`.

`get` still sums finished time across every position. An open session
(in but not yet out) is not finished, so it is not in `time`.

## Example

```
add_worker("John", "Junior Developer", 120) -> "true"
add_worker("Jason", "Junior Developer", 120) -> "true"
add_worker("Ashley", "Junior Developer", 120) -> "true"
register("John", 100) -> "registered"
register("John", 150) -> "registered"
register("Jason", 200) -> "registered"
register("Jason", 250) -> "registered"
register("Jason", 275) -> "registered"
top_n_workers(5, "Junior Developer") -> "Jason(50), John(50), Ashley(0)"
top_n_workers(1, "Junior Developer") -> "Jason(50)"
```

John finished 50. Jason finished 50, then entered again at 275, so
that open stretch is not counted. Ashley never entered, so the time
is 0. The 0 row is included. Jason sorts before John on the tie.

```
register("Ashley", 400) -> "registered"
register("Ashley", 500) -> "registered"
register("Jason", 575) -> "registered"
top_n_workers(3, "Junior Developer") -> "Jason(350), Ashley(100), John(50)"
top_n_workers(3, "Middle Developer") -> ""
```

Jason's second session adds 300 (275 to 575). Middle Developer has
no workers, so the return is `""`.
