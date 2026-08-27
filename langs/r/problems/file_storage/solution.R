fmt_int <- function(value) {
  format(value, scientific = FALSE, trim = TRUE)
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$files <- list()
  self$order <- character(0)
  self$capacity <- list()
  self$capacity[["admin"]] <- NA_real_
  self$backups <- list()

  self$used <- function(user_id) {
    total <- 0
    for (name in self$order) {
      item <- self$files[[name]]
      if (!is.null(item) && identical(item$owner, user_id)) {
        total <- total + item$size
      }
    }
    total
  }

  self$remaining <- function(user_id) {
    if (is.null(self$capacity[[user_id]]) && !(user_id %in% names(self$capacity))) {
      return(NULL)
    }
    cap <- self$capacity[[user_id]]
    if (is.null(cap) || is.na(cap)) {
      return(NULL)
    }
    cap - self$used(user_id)
  }

  self$add <- function(name, size, owner) {
    self$files[[name]] <- list(name = name, size = size, owner = owner)
    self$order <- c(self$order, name)
    invisible(NULL)
  }

  self$delete_name <- function(name) {
    self$files[[name]] <- NULL
    self$order <- self$order[self$order != name]
    invisible(NULL)
  }

  self$add_file <- function(name, size) {
    if (!is.null(self$files[[name]])) {
      return("false")
    }
    self$add(name, size, "admin")
    "true"
  }

  self$get_file_size <- function(name) {
    item <- self$files[[name]]
    if (is.null(item)) {
      return("")
    }
    fmt_int(item$size)
  }

  self$delete_file <- function(name) {
    item <- self$files[[name]]
    if (is.null(item)) {
      return("")
    }
    size <- item$size
    self$delete_name(name)
    fmt_int(size)
  }

  self$get_n_largest <- function(prefix, n) {
    matched <- list()
    for (name in self$order) {
      item <- self$files[[name]]
      if (!is.null(item) && startsWith(item$name, prefix)) {
        matched[[length(matched) + 1]] <- item
      }
    }
    if (length(matched) == 0) {
      return("")
    }
    sizes <- vapply(matched, function(item) item$size, numeric(1))
    names_ <- vapply(matched, function(item) item$name, character(1))
    matched <- matched[order(-sizes, names_)]
    if (length(matched) > n) {
      matched <- matched[seq_len(n)]
    }
    parts <- vapply(matched, function(item) {
      paste0(item$name, "(", fmt_int(item$size), ")")
    }, character(1))
    paste(parts, collapse = ", ")
  }

  self$add_user <- function(user_id, capacity) {
    if (user_id %in% names(self$capacity)) {
      return("false")
    }
    self$capacity[[user_id]] <- capacity
    "true"
  }

  self$add_file_by <- function(user_id, name, size) {
    if (!(user_id %in% names(self$capacity)) || !is.null(self$files[[name]])) {
      return("")
    }
    left <- self$remaining(user_id)
    if (!is.null(left) && size > left) {
      return("")
    }
    self$add(name, size, user_id)
    left <- self$remaining(user_id)
    if (is.null(left)) {
      return("")
    }
    fmt_int(left)
  }

  self$merge_user <- function(user_id1, user_id2) {
    if (identical(user_id1, user_id2)) {
      return("")
    }
    if (!(user_id1 %in% names(self$capacity)) || !(user_id2 %in% names(self$capacity))) {
      return("")
    }
    cap1 <- self$capacity[[user_id1]]
    cap2 <- self$capacity[[user_id2]]
    if (is.null(cap1) || is.na(cap1) || is.null(cap2) || is.na(cap2)) {
      return("")
    }
    self$capacity[[user_id1]] <- cap1 + cap2
    for (name in self$order) {
      item <- self$files[[name]]
      if (!is.null(item) && identical(item$owner, user_id2)) {
        item$owner <- user_id1
        self$files[[name]] <- item
      }
    }
    self$capacity[[user_id2]] <- NULL
    self$backups[[user_id2]] <- NULL
    left <- self$remaining(user_id1)
    if (is.null(left)) {
      return("")
    }
    fmt_int(left)
  }

  self$backup_user <- function(user_id) {
    if (!(user_id %in% names(self$capacity))) {
      return("")
    }
    snap <- list()
    for (name in self$order) {
      item <- self$files[[name]]
      if (!is.null(item) && identical(item$owner, user_id)) {
        snap[[length(snap) + 1]] <- list(name, item$size)
      }
    }
    self$backups[[user_id]] <- snap
    fmt_int(length(snap))
  }

  self$restore_user <- function(user_id) {
    if (!(user_id %in% names(self$capacity))) {
      return("")
    }
    keep <- character(0)
    for (name in self$order) {
      item <- self$files[[name]]
      if (!is.null(item) && identical(item$owner, user_id)) {
        self$files[[name]] <- NULL
      } else {
        keep <- c(keep, name)
      }
    }
    self$order <- keep
    snapshot <- self$backups[[user_id]]
    if (is.null(snapshot)) {
      return("0")
    }
    restored <- 0
    for (row in snapshot) {
      name <- row[[1]]
      size <- row[[2]]
      if (!is.null(self$files[[name]])) {
        next
      }
      left <- self$remaining(user_id)
      if (is.null(left) || size <= left) {
        self$add(name, size, user_id)
        restored <- restored + 1
      }
    }
    fmt_int(restored)
  }

  self
}
