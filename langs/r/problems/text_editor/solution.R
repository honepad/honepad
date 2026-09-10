fmt_int <- function(value) {
  format(value, scientific = FALSE, trim = TRUE)
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$buf <- ""
  self$pos <- 0
  self$undo_stack <- list()
  self$redo_stack <- list()
  self$sel <- NULL
  self$clip <- ""

  self$push <- function() {
    self$undo_stack[[length(self$undo_stack) + 1]] <- list(self$buf, self$pos)
    self$redo_stack <- list()
    self$sel <- NULL
  }

  self$insert <- function(pos, text) {
    if (pos < 0 || pos > nchar(self$buf)) {
      return("invalid_request")
    }
    self$push()
    self$buf <- paste0(substr(self$buf, 1, pos), text, substr(self$buf, pos + 1, nchar(self$buf)))
    fmt_int(nchar(self$buf))
  }

  self$erase <- function(pos, n) {
    if (n <= 0 || pos < 0 || pos + n > nchar(self$buf)) {
      return("invalid_request")
    }
    self$push()
    deleted <- substr(self$buf, pos + 1, pos + n)
    self$buf <- paste0(substr(self$buf, 1, pos), substr(self$buf, pos + n + 1, nchar(self$buf)))
    if (self$pos > nchar(self$buf)) {
      self$pos <- nchar(self$buf)
    }
    deleted
  }

  self$get_text <- function() {
    self$buf
  }

  self$length <- function() {
    fmt_int(nchar(self$buf))
  }

  self$move <- function(pos) {
    if (pos < 0 || pos > nchar(self$buf)) {
      return("invalid_request")
    }
    self$pos <- pos
    "true"
  }

  self$type_text <- function(text) {
    self$push()
    at <- self$pos
    self$buf <- paste0(substr(self$buf, 1, at), text, substr(self$buf, at + 1, nchar(self$buf)))
    self$pos <- at + nchar(text)
    fmt_int(nchar(self$buf))
  }

  self$cursor <- function() {
    fmt_int(self$pos)
  }

  self$undo <- function() {
    if (length(self$undo_stack) == 0) {
      return("false")
    }
    self$redo_stack[[length(self$redo_stack) + 1]] <- list(self$buf, self$pos)
    snap <- self$undo_stack[[length(self$undo_stack)]]
    self$undo_stack[[length(self$undo_stack)]] <- NULL
    self$buf <- snap[[1]]
    self$pos <- snap[[2]]
    self$sel <- NULL
    "true"
  }

  self$redo <- function() {
    if (length(self$redo_stack) == 0) {
      return("false")
    }
    self$undo_stack[[length(self$undo_stack) + 1]] <- list(self$buf, self$pos)
    snap <- self$redo_stack[[length(self$redo_stack)]]
    self$redo_stack[[length(self$redo_stack)]] <- NULL
    self$buf <- snap[[1]]
    self$pos <- snap[[2]]
    self$sel <- NULL
    "true"
  }

  self$select <- function(start, end) {
    if (start < 0 || end < 0 || start > end || end > nchar(self$buf)) {
      return("invalid_request")
    }
    self$sel <- c(start, end)
    "true"
  }

  self$cut <- function() {
    if (is.null(self$sel) || self$sel[[1]] == self$sel[[2]]) {
      return("invalid_request")
    }
    start <- self$sel[[1]]
    end <- self$sel[[2]]
    text <- substr(self$buf, start + 1, end)
    self$buf <- paste0(substr(self$buf, 1, start), substr(self$buf, end + 1, nchar(self$buf)))
    self$clip <- text
    self$pos <- start
    self$sel <- NULL
    text
  }

  self$copy_sel <- function() {
    if (is.null(self$sel) || self$sel[[1]] == self$sel[[2]]) {
      return("invalid_request")
    }
    start <- self$sel[[1]]
    end <- self$sel[[2]]
    self$clip <- substr(self$buf, start + 1, end)
    self$clip
  }

  self$paste <- function() {
    if (identical(self$clip, "")) {
      return("invalid_request")
    }
    at <- self$pos
    self$buf <- paste0(substr(self$buf, 1, at), self$clip, substr(self$buf, at + 1, nchar(self$buf)))
    self$pos <- at + nchar(self$clip)
    fmt_int(nchar(self$buf))
  }

  self
}
