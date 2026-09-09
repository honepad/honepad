new_backend <- function(backend_id) {
  item <- new.env(parent = emptyenv())
  item$backend_id <- backend_id
  item$health <- TRUE
  item$weight <- 1
  item$inflight <- 0
  item
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$backends <- list()
  self$by_id <- list()
  self$cursor <- 0
  self$sticky_map <- list()
  self$use_least <- FALSE

  self$reset_cycle <- function() {
    self$cursor <- 0
    self$use_least <- FALSE
    for (item in self$backends) {
      item$inflight <- 0
    }
  }

  self$tickets <- function(items) {
    tickets <- list()
    for (item in items) {
      if (item$weight > 0) {
        for (i in seq_len(item$weight)) {
          tickets[[length(tickets) + 1]] <- item
        }
      }
    }
    tickets
  }

  self$pick <- function() {
    healthy <- list()
    for (item in self$backends) {
      if (isTRUE(item$health)) {
        healthy[[length(healthy) + 1]] <- item
      }
    }
    if (length(healthy) == 0) {
      return(NULL)
    }
    pool <- healthy
    if (isTRUE(self$use_least)) {
      least <- healthy[[1]]$inflight
      for (item in healthy) {
        if (item$inflight < least) {
          least <- item$inflight
        }
      }
      pool <- list()
      for (item in healthy) {
        if (item$inflight == least) {
          pool[[length(pool) + 1]] <- item
        }
      }
    }
    tickets <- self$tickets(pool)
    if (length(tickets) == 0) {
      return(NULL)
    }
    idx <- (self$cursor %% length(tickets)) + 1
    self$cursor <- self$cursor + 1
    tickets[[idx]]
  }

  self$take <- function() {
    item <- self$pick()
    if (is.null(item)) {
      return("")
    }
    item$inflight <- item$inflight + 1
    item$backend_id
  }

  self$add_backend <- function(backend_id) {
    if (!is.null(self$by_id[[backend_id]])) {
      return("false")
    }
    item <- new_backend(backend_id)
    self$backends[[length(self$backends) + 1]] <- item
    self$by_id[[backend_id]] <- item
    "true"
  }

  self$set_health <- function(backend_id, flag) {
    item <- self$by_id[[backend_id]]
    if (is.null(item) || !(flag %in% c(0, 1))) {
      return("invalid_request")
    }
    item$health <- flag == 1
    self$reset_cycle()
    "true"
  }

  self$set_weight <- function(backend_id, weight) {
    item <- self$by_id[[backend_id]]
    if (is.null(item) || weight <= 0) {
      return("invalid_request")
    }
    item$weight <- weight
    self$reset_cycle()
    "true"
  }

  self$route <- function() {
    self$take()
  }

  self$sticky <- function(client_id) {
    bound <- self$sticky_map[[client_id]]
    item <- if (is.null(bound)) NULL else self$by_id[[bound]]
    if (!is.null(item) && isTRUE(item$health)) {
      item$inflight <- item$inflight + 1
      return(item$backend_id)
    }
    chosen <- self$take()
    if (nzchar(chosen)) {
      self$sticky_map[[client_id]] <- chosen
    }
    chosen
  }

  self$done <- function(backend_id) {
    item <- self$by_id[[backend_id]]
    if (is.null(item) || item$inflight <= 0) {
      return("invalid_request")
    }
    item$inflight <- item$inflight - 1
    self$use_least <- TRUE
    "true"
  }

  self
}
