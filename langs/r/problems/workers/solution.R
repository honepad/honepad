fmt_int <- function(value) {
  format(value, scientific = FALSE, trim = TRUE)
}

new_worker <- function(worker_id, position, compensation) {
  worker <- new.env(parent = emptyenv())
  worker$worker_id <- worker_id
  worker$position <- position
  worker$compensation <- compensation
  worker$in_office <- FALSE
  worker$entered_at <- NULL
  worker$finished <- list()
  worker$pending_promo <- NULL
  worker
}

worker_total_time <- function(worker) {
  total <- 0
  for (row in worker$finished) {
    total <- total + (row[[2]] - row[[1]])
  }
  total
}

worker_position_time <- function(worker, position) {
  total <- 0
  for (row in worker$finished) {
    if (identical(row[[4]], position)) {
      total <- total + (row[[2]] - row[[1]])
    }
  }
  total
}

apply_promo_on_enter <- function(worker, timestamp) {
  promo <- worker$pending_promo
  if (is.null(promo)) {
    return(invisible(NULL))
  }
  if (timestamp < promo[[3]]) {
    return(invisible(NULL))
  }
  worker$position <- promo[[1]]
  worker$compensation <- promo[[2]]
  worker$pending_promo <- NULL
  invisible(NULL)
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$workers <- list()

  self$add_worker <- function(worker_id, position, compensation) {
    if (!is.null(self$workers[[worker_id]])) {
      return("false")
    }
    self$workers[[worker_id]] <- new_worker(worker_id, position, compensation)
    "true"
  }

  self$register <- function(worker_id, timestamp) {
    worker <- self$workers[[worker_id]]
    if (is.null(worker)) {
      return("invalid_request")
    }
    if (isTRUE(worker$in_office)) {
      worker$finished[[length(worker$finished) + 1]] <- list(
        worker$entered_at,
        timestamp,
        worker$compensation,
        worker$position
      )
      worker$in_office <- FALSE
      worker$entered_at <- NULL
      return("registered")
    }
    apply_promo_on_enter(worker, timestamp)
    worker$in_office <- TRUE
    worker$entered_at <- timestamp
    "registered"
  }

  self$get <- function(worker_id) {
    worker <- self$workers[[worker_id]]
    if (is.null(worker)) {
      return("")
    }
    fmt_int(worker_total_time(worker))
  }

  self$top_n_workers <- function(n, position) {
    matched <- list()
    for (worker_id in names(self$workers)) {
      worker <- self$workers[[worker_id]]
      if (identical(worker$position, position)) {
        matched[[length(matched) + 1]] <- worker
      }
    }
    if (length(matched) == 0) {
      return("")
    }
    times <- vapply(matched, function(worker) worker_position_time(worker, position), numeric(1))
    ids <- vapply(matched, function(worker) worker$worker_id, character(1))
    matched <- matched[order(-times, ids)]
    if (length(matched) > n) {
      matched <- matched[seq_len(n)]
    }
    parts <- vapply(matched, function(worker) {
      paste0(worker$worker_id, "(", fmt_int(worker_position_time(worker, position)), ")")
    }, character(1))
    paste(parts, collapse = ", ")
  }

  self$promote <- function(worker_id, new_position, new_compensation, start_timestamp) {
    worker <- self$workers[[worker_id]]
    if (is.null(worker) || !is.null(worker$pending_promo)) {
      return("invalid_request")
    }
    worker$pending_promo <- list(new_position, new_compensation, start_timestamp)
    "success"
  }

  self$calc_salary <- function(worker_id, start_timestamp, end_timestamp) {
    worker <- self$workers[[worker_id]]
    if (is.null(worker)) {
      return("")
    }
    total <- 0
    for (row in worker$finished) {
      session_start <- row[[1]]
      session_end <- row[[2]]
      rate <- row[[3]]
      lo <- max(session_start, start_timestamp)
      hi <- min(session_end, end_timestamp)
      if (hi > lo) {
        total <- total + (hi - lo) * rate
      }
    }
    fmt_int(total)
  }

  self
}
