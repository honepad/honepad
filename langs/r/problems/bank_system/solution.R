new_account <- function(account_id, created_at) {
  acc <- new.env(parent = emptyenv())
  acc$account_id <- account_id
  acc$balance <- 0
  acc$outgoing <- 0
  acc$payments <- list()
  acc$created_at <- created_at
  acc$balance_history <- list(c(created_at, 0))
  acc
}

record_balance <- function(account, timestamp) {
  account$balance_history[[length(account$balance_history) + 1]] <-
    c(timestamp, account$balance)
  invisible(NULL)
}

account_deposit <- function(account, amount) {
  account$balance <- account$balance + amount
  account$balance
}

account_withdraw <- function(account, amount) {
  if (account$balance < amount) {
    return(FALSE)
  }
  account$balance <- account$balance - amount
  account$outgoing <- account$outgoing + amount
  TRUE
}

account_balance_at <- function(account, time_at) {
  if (time_at < account$created_at) {
    return(NULL)
  }
  result <- NULL
  for (row in account$balance_history) {
    if (row[[1]] > time_at) {
      break
    }
    result <- row[[2]]
  }
  result
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$accounts <- list()
  self$payment_counter <- 0
  self$pending_cashbacks <- list()
  cashback_delay <- 24 * 60 * 60 * 1000

  self$process_cashbacks <- function(timestamp) {
    pending <- self$pending_cashbacks
    while (length(pending) > 0 && pending[[1]][[1]] <= timestamp) {
      row <- pending[[1]]
      pending <- pending[-1]
      account <- self$accounts[[row[[2]]]]
      if (!is.null(account)) {
        account_deposit(account, row[[3]])
        account$payments[[row[[4]]]] <- "CASHBACK_RECEIVED"
        record_balance(account, row[[1]])
      }
    }
    self$pending_cashbacks <- pending
    invisible(NULL)
  }

  self$create_account <- function(timestamp, account_id) {
    self$process_cashbacks(timestamp)
    if (!is.null(self$accounts[[account_id]])) {
      return(FALSE)
    }
    self$accounts[[account_id]] <- new_account(account_id, timestamp)
    TRUE
  }

  self$deposit <- function(timestamp, account_id, amount) {
    self$process_cashbacks(timestamp)
    account <- self$accounts[[account_id]]
    if (is.null(account)) {
      return(NULL)
    }
    result <- account_deposit(account, amount)
    record_balance(account, timestamp)
    result
  }

  self$transfer <- function(timestamp, source_account_id, target_account_id, amount) {
    self$process_cashbacks(timestamp)
    if (is.null(self$accounts[[source_account_id]]) ||
        is.null(self$accounts[[target_account_id]])) {
      return(NULL)
    }
    if (identical(source_account_id, target_account_id)) {
      return(NULL)
    }
    source <- self$accounts[[source_account_id]]
    target <- self$accounts[[target_account_id]]
    if (!isTRUE(account_withdraw(source, amount))) {
      return(NULL)
    }
    account_deposit(target, amount)
    record_balance(source, timestamp)
    record_balance(target, timestamp)
    source$balance
  }

  self$top_spenders <- function(timestamp, n) {
    self$process_cashbacks(timestamp)
    ids <- names(self$accounts)
    if (is.null(ids) || length(ids) == 0) {
      return(list())
    }
    outgoing <- vapply(ids, function(id) self$accounts[[id]]$outgoing, numeric(1))
    ids <- ids[order(-outgoing, ids)]
    if (length(ids) > n) {
      ids <- ids[seq_len(n)]
    }
    lapply(ids, function(id) {
      paste0(id, "(", format(self$accounts[[id]]$outgoing, scientific = FALSE, trim = TRUE), ")")
    })
  }

  self$pay <- function(timestamp, account_id, amount) {
    self$process_cashbacks(timestamp)
    account <- self$accounts[[account_id]]
    if (is.null(account)) {
      return(NULL)
    }
    if (!isTRUE(account_withdraw(account, amount))) {
      return(NULL)
    }
    self$payment_counter <- self$payment_counter + 1
    payment_id <- paste0("payment", self$payment_counter)
    account$payments[[payment_id]] <- "IN_PROGRESS"
    record_balance(account, timestamp)
    cashback_amount <- (amount * 2) %/% 100
    self$pending_cashbacks[[length(self$pending_cashbacks) + 1]] <- list(
      timestamp + cashback_delay,
      account_id,
      cashback_amount,
      payment_id
    )
    payment_id
  }

  self$get_payment_status <- function(timestamp, account_id, payment) {
    self$process_cashbacks(timestamp)
    account <- self$accounts[[account_id]]
    if (is.null(account)) {
      return(NULL)
    }
    account$payments[[payment]]
  }

  self$merge_accounts <- function(timestamp, account_id_1, account_id_2) {
    self$process_cashbacks(timestamp)
    if (identical(account_id_1, account_id_2)) {
      return(FALSE)
    }
    if (is.null(self$accounts[[account_id_1]]) ||
        is.null(self$accounts[[account_id_2]])) {
      return(FALSE)
    }
    account1 <- self$accounts[[account_id_1]]
    account2 <- self$accounts[[account_id_2]]
    account1$balance <- account1$balance + account2$balance
    account1$outgoing <- account1$outgoing + account2$outgoing
    for (payment_id in names(account2$payments)) {
      account1$payments[[payment_id]] <- account2$payments[[payment_id]]
    }
    if (length(account2$balance_history) > 0) {
      account1$balance_history <- c(account1$balance_history, account2$balance_history)
    }
    ts <- vapply(account1$balance_history, function(row) row[[1]], numeric(1))
    account1$balance_history <- account1$balance_history[order(ts)]
    if (account2$created_at < account1$created_at) {
      account1$created_at <- account2$created_at
    }
    record_balance(account1, timestamp)
    if (length(self$pending_cashbacks) > 0) {
      self$pending_cashbacks <- lapply(self$pending_cashbacks, function(cb) {
        if (identical(cb[[2]], account_id_2)) {
          cb[[2]] <- account_id_1
        }
        cb
      })
    }
    self$accounts[[account_id_2]] <- NULL
    TRUE
  }

  self$get_balance <- function(timestamp, account_id, time_at) {
    self$process_cashbacks(timestamp)
    account <- self$accounts[[account_id]]
    if (is.null(account)) {
      return(NULL)
    }
    account_balance_at(account, time_at)
  }

  self
}
