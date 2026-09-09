fmt_int <- function(value) {
  format(value, scientific = FALSE, trim = TRUE)
}

new_key <- function() {
  item <- new.env(parent = emptyenv())
  item$limit <- 3
  item$window <- 10
  item$window_id <- NULL
  item$used <- 0
  item
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$keys <- list()

  self$state <- function(key) {
    item <- self$keys[[key]]
    if (is.null(item)) {
      item <- new_key()
      self$keys[[key]] <- item
    }
    item
  }

  self$used_at <- function(item, timestamp, persist) {
    window_id <- timestamp %/% item$window
    if (is.null(item$window_id) || window_id != item$window_id) {
      if (persist) {
        item$window_id <- window_id
        item$used <- 0
      }
      return(0)
    }
    item$used
  }

  self$allow <- function(key, timestamp) {
    self$allow_weighted(key, 1, timestamp)
  }

  self$configure <- function(key, limit, window) {
    if (limit <= 0 || window <= 0) {
      return("invalid_request")
    }
    item <- self$state(key)
    item$limit <- limit
    item$window <- window
    item$window_id <- NULL
    item$used <- 0
    "true"
  }

  self$remaining <- function(key, timestamp) {
    item <- self$state(key)
    used <- self$used_at(item, timestamp, FALSE)
    fmt_int(item$limit - used)
  }

  self$allow_weighted <- function(key, cost, timestamp) {
    if (cost <= 0) {
      return("invalid_request")
    }
    item <- self$state(key)
    self$used_at(item, timestamp, TRUE)
    if (item$used + cost > item$limit) {
      return("false")
    }
    item$used <- item$used + cost
    "true"
  }

  self
}
