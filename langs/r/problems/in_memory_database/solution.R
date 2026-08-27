InMemoryDatabase <- function() {
  self <- new.env(parent = emptyenv())
  self$database <- list()
  self$backup_timestamps <- list()
  self$backup_states <- list()

  self$set_internal <- function(key, field, value, expiry) {
    if (is.null(self$database[[key]])) {
      self$database[[key]] <- list()
    }
    self$database[[key]][[field]] <- list(value, expiry)
    ""
  }

  self$alive <- function(key, field, timestamp) {
    fields <- self$database[[key]]
    if (is.null(fields) || is.null(fields[[field]])) {
      return(FALSE)
    }
    expiry <- fields[[field]][[2]]
    if (is.null(expiry)) {
      return(TRUE)
    }
    timestamp < expiry
  }

  self$set <- function(key, field, value) {
    self$set_internal(key, field, value, NULL)
  }

  self$get <- function(key, field) {
    fields <- self$database[[key]]
    if (is.null(fields) || is.null(fields[[field]])) {
      return("")
    }
    fields[[field]][[1]]
  }

  self$delete <- function(key, field) {
    fields <- self$database[[key]]
    if (is.null(fields) || is.null(fields[[field]])) {
      return("false")
    }
    self$database[[key]][[field]] <- NULL
    "true"
  }

  sorted_fields <- function(key) {
    fields <- self$database[[key]]
    if (is.null(fields)) {
      return(character(0))
    }
    nms <- names(fields)
    if (is.null(nms)) {
      return(character(0))
    }
    sort(nms)
  }

  self$scan <- function(key) {
    if (is.null(self$database[[key]])) {
      return("")
    }
    parts <- character(0)
    for (field in sorted_fields(key)) {
      value <- self$database[[key]][[field]][[1]]
      parts <- c(parts, paste0(field, "(", value, ")"))
    }
    paste(parts, collapse = ", ")
  }

  self$scan_by_prefix <- function(key, prefix) {
    if (is.null(self$database[[key]])) {
      return("")
    }
    parts <- character(0)
    for (field in sorted_fields(key)) {
      if (startsWith(field, prefix)) {
        value <- self$database[[key]][[field]][[1]]
        parts <- c(parts, paste0(field, "(", value, ")"))
      }
    }
    paste(parts, collapse = ", ")
  }

  self$set_at <- function(key, field, value, timestamp) {
    self$set_internal(key, field, value, NULL)
  }

  self$set_at_with_ttl <- function(key, field, value, timestamp, ttl) {
    self$set_internal(key, field, value, timestamp + ttl)
  }

  self$delete_at <- function(key, field, timestamp) {
    if (!isTRUE(self$alive(key, field, timestamp))) {
      return("false")
    }
    self$database[[key]][[field]] <- NULL
    "true"
  }

  self$get_at <- function(key, field, timestamp) {
    if (!isTRUE(self$alive(key, field, timestamp))) {
      return("")
    }
    self$database[[key]][[field]][[1]]
  }

  self$scan_at <- function(key, timestamp) {
    if (is.null(self$database[[key]])) {
      return("")
    }
    parts <- character(0)
    for (field in sorted_fields(key)) {
      if (isTRUE(self$alive(key, field, timestamp))) {
        value <- self$database[[key]][[field]][[1]]
        parts <- c(parts, paste0(field, "(", value, ")"))
      }
    }
    paste(parts, collapse = ", ")
  }

  self$scan_by_prefix_at <- function(key, prefix, timestamp) {
    if (is.null(self$database[[key]])) {
      return("")
    }
    parts <- character(0)
    for (field in sorted_fields(key)) {
      if (startsWith(field, prefix) && isTRUE(self$alive(key, field, timestamp))) {
        value <- self$database[[key]][[field]][[1]]
        parts <- c(parts, paste0(field, "(", value, ")"))
      }
    }
    paste(parts, collapse = ", ")
  }

  self$backup <- function(timestamp) {
    state <- list()
    count <- 0
    for (key in names(self$database)) {
      fields <- self$database[[key]]
      for (field in names(fields)) {
        if (!isTRUE(self$alive(key, field, timestamp))) {
          next
        }
        if (is.null(state[[key]])) {
          state[[key]] <- list()
          count <- count + 1
        }
        expiry <- fields[[field]][[2]]
        remaining <- NULL
        if (!is.null(expiry)) {
          remaining <- expiry - timestamp
        }
        state[[key]][[field]] <- list(fields[[field]][[1]], remaining)
      }
    }
    self$backup_timestamps[[length(self$backup_timestamps) + 1]] <- timestamp
    self$backup_states[[length(self$backup_states) + 1]] <- state
    format(count, scientific = FALSE, trim = TRUE)
  }

  self$restore <- function(timestamp, timestamp_to_restore) {
    idx <- 0
    if (length(self$backup_timestamps) > 0) {
      for (i in seq_along(self$backup_timestamps)) {
        if (self$backup_timestamps[[i]] <= timestamp_to_restore) {
          idx <- i
        }
      }
    }
    backup_state <- self$backup_states[[idx]]
    self$database <- list()
    for (key in names(backup_state)) {
      fields <- backup_state[[key]]
      for (field in names(fields)) {
        remaining <- fields[[field]][[2]]
        expiry <- NULL
        if (!is.null(remaining)) {
          expiry <- timestamp + remaining
        }
        self$set_internal(key, field, fields[[field]][[1]], expiry)
      }
    }
    ""
  }

  self
}
