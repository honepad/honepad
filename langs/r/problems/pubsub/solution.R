fmt_int <- function(value) {
  format(value, scientific = FALSE, trim = TRUE)
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$subs <- list()
  self$inbox_map <- list()
  self$retained <- list()

  self$subscribe <- function(topic, client) {
    clients <- self$subs[[topic]]
    if (is.null(clients)) {
      clients <- character(0)
    }
    if (client %in% clients) {
      return("false")
    }
    self$subs[[topic]] <- c(clients, client)
    if (!is.null(self$retained[[topic]])) {
      items <- self$inbox_map[[client]]
      if (is.null(items)) {
        items <- character(0)
      }
      self$inbox_map[[client]] <- c(items, paste0(topic, ":", self$retained[[topic]]))
    }
    "true"
  }

  self$unsubscribe <- function(topic, client) {
    clients <- self$subs[[topic]]
    if (is.null(clients) || !(client %in% clients)) {
      return("false")
    }
    clients <- clients[clients != client]
    if (length(clients) == 0) {
      self$subs[[topic]] <- NULL
    } else {
      self$subs[[topic]] <- clients
    }
    "true"
  }

  self$publish <- function(topic, message) {
    clients <- self$subs[[topic]]
    if (is.null(clients)) {
      clients <- character(0)
    }
    payload <- paste0(topic, ":", message)
    for (client in clients) {
      items <- self$inbox_map[[client]]
      if (is.null(items)) {
        items <- character(0)
      }
      self$inbox_map[[client]] <- c(items, payload)
    }
    fmt_int(length(clients))
  }

  self$inbox <- function(client) {
    items <- self$inbox_map[[client]]
    if (is.null(items) || length(items) == 0) {
      return("")
    }
    paste(items, collapse = ", ")
  }

  self$list_topics <- function() {
    topics <- names(self$subs)
    if (is.null(topics) || length(topics) == 0) {
      return("")
    }
    paste(sort(topics), collapse = ", ")
  }

  self$subscribers <- function(topic) {
    clients <- self$subs[[topic]]
    if (is.null(clients) || length(clients) == 0) {
      return("")
    }
    paste(sort(clients), collapse = ", ")
  }

  self$peek <- function(client) {
    items <- self$inbox_map[[client]]
    if (is.null(items) || length(items) == 0) {
      return("")
    }
    items[[1]]
  }

  self$ack <- function(client, n) {
    if (n <= 0 || is.null(self$inbox_map[[client]])) {
      return("invalid_request")
    }
    items <- self$inbox_map[[client]]
    if (n > length(items)) {
      return("invalid_request")
    }
    if (n == length(items)) {
      self$inbox_map[[client]] <- character(0)
    } else {
      self$inbox_map[[client]] <- items[(n + 1):length(items)]
    }
    fmt_int(length(self$inbox_map[[client]]))
  }

  self$retain <- function(topic, message) {
    self$retained[[topic]] <- message
    ""
  }

  self
}
