fmt_int <- function(value) {
  format(value, scientific = FALSE, trim = TRUE)
}

new_item <- function(sku, name) {
  item <- new.env(parent = emptyenv())
  item$sku <- sku
  item$name <- name
  item$qty <- 0
  item$reserved <- 0
  item
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$items <- list()

  self$create_item <- function(sku, name) {
    if (!is.null(self$items[[sku]])) {
      return("false")
    }
    self$items[[sku]] <- new_item(sku, name)
    "true"
  }

  self$stock <- function(sku, delta) {
    item <- self$items[[sku]]
    if (is.null(item)) {
      return("")
    }
    nxt <- item$qty + delta
    if (nxt < item$reserved) {
      return("invalid_request")
    }
    item$qty <- nxt
    fmt_int(item$qty)
  }

  self$get_qty <- function(sku) {
    item <- self$items[[sku]]
    if (is.null(item)) {
      return("")
    }
    fmt_int(item$qty)
  }

  self$list_low <- function(threshold) {
    matched <- list()
    for (sku in names(self$items)) {
      item <- self$items[[sku]]
      if (item$qty <= threshold) {
        matched[[length(matched) + 1]] <- item
      }
    }
    if (length(matched) == 0) {
      return("")
    }
    qtys <- vapply(matched, function(item) item$qty, numeric(1))
    skus <- vapply(matched, function(item) item$sku, character(1))
    matched <- matched[order(qtys, skus)]
    parts <- vapply(matched, function(item) {
      paste0(item$sku, "(", fmt_int(item$qty), ")")
    }, character(1))
    paste(parts, collapse = ", ")
  }

  self$reserve <- function(sku, n) {
    item <- self$items[[sku]]
    if (is.null(item) || n <= 0 || item$reserved + n > item$qty) {
      return("invalid_request")
    }
    item$reserved <- item$reserved + n
    "true"
  }

  self$release <- function(sku, n) {
    item <- self$items[[sku]]
    if (is.null(item) || n <= 0 || n > item$reserved) {
      return("invalid_request")
    }
    item$reserved <- item$reserved - n
    "true"
  }

  self$ship <- function(sku, n) {
    item <- self$items[[sku]]
    if (is.null(item) || n <= 0 || n > item$reserved) {
      return("invalid_request")
    }
    item$reserved <- item$reserved - n
    item$qty <- item$qty - n
    "true"
  }

  self
}
