#!/usr/bin/env Rscript
# argv: Rscript adapter.R <src> <class> <cases.json>

suppressPackageStartupMessages(library(jsonlite))

json_encode <- function(value) {
  if (is.null(value)) {
    return("null")
  }
  as.character(toJSON(
    value,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  ))
}

contains_nonfinite <- function(value) {
  if (is.null(value)) {
    return(FALSE)
  }
  if (is.numeric(value) && !is.list(value)) {
    return(any(is.nan(value)) || any(is.infinite(value)))
  }
  if (is.list(value)) {
    if (length(value) == 0) {
      return(FALSE)
    }
    return(any(vapply(value, contains_nonfinite, logical(1))))
  }
  FALSE
}

tag_nonfinite <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  if (is.numeric(value) && !is.list(value)) {
    if (!any(is.nan(value)) && !any(is.infinite(value))) {
      return(value)
    }
    out <- vector("list", length(value))
    for (i in seq_along(value)) {
      item <- value[[i]]
      if (is.nan(item)) {
        out[[i]] <- "NaN"
      } else if (is.infinite(item)) {
        out[[i]] <- if (item > 0) "Infinity" else "-Infinity"
      } else {
        out[[i]] <- item
      }
    }
    if (length(out) == 1) {
      return(out[[1]])
    }
    return(out)
  }
  if (is.list(value)) {
    return(lapply(value, tag_nonfinite))
  }
  value
}

lookup_method <- function(obj, method) {
  if (is.environment(obj) && exists(method, envir = obj, inherits = FALSE)) {
    return(get(method, envir = obj, inherits = FALSE))
  }
  if (is.list(obj)) {
    return(obj[[method]])
  }
  NULL
}

instantiate <- function(class_name) {
  if (!exists(class_name, envir = .GlobalEnv, inherits = FALSE)) {
    stop(paste("missing class", class_name))
  }
  ctor <- get(class_name, envir = .GlobalEnv, inherits = FALSE)
  if (!is.function(ctor)) {
    stop(paste("missing class", class_name))
  }
  ctor()
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  src <- args[[1]]
  class_name <- args[[2]]
  cases_path <- args[[3]]
  report_con <- stdout()
  sink(nullfile())
  source(src, local = FALSE)
  cases <- fromJSON(cases_path, simplifyVector = FALSE)
  failed <- list()
  passed <- 0
  for (case in cases) {
    obj <- instantiate(class_name)
    ok <- TRUE
    calls <- case$calls
    if (is.null(calls)) {
      calls <- list()
    }
    for (i in seq_along(calls)) {
      call <- calls[[i]]
      method <- call$m
      call_args <- call$a
      if (is.null(call_args)) {
        call_args <- list()
      }
      expected <- call$e
      fn <- lookup_method(obj, method)
      if (!is.function(fn)) {
        failed[[length(failed) + 1]] <- list(
          case = case$id,
          index = i - 1,
          method = method,
          expected = expected,
          actual = "exc:missing_method"
        )
        ok <- FALSE
        break
      }
      ran <- tryCatch(
        list(ok = TRUE, value = do.call(fn, call_args)),
        error = function(err) {
          msg <- conditionMessage(err)
          msg <- sub("[[:space:]]+$", "", msg)
          list(ok = FALSE, value = paste0("exc:", msg))
        }
      )
      if (!isTRUE(ran$ok)) {
        failed[[length(failed) + 1]] <- list(
          case = case$id,
          index = i - 1,
          method = method,
          expected = expected,
          actual = ran$value
        )
        ok <- FALSE
        break
      }
      actual <- ran$value
      bad <- contains_nonfinite(actual)
      if (bad || json_encode(actual) != json_encode(expected)) {
        failed[[length(failed) + 1]] <- list(
          case = case$id,
          index = i - 1,
          method = method,
          expected = expected,
          actual = if (bad) tag_nonfinite(actual) else actual
        )
        ok <- FALSE
        break
      }
    }
    if (ok) {
      passed <- passed + 1
    }
  }
  sink()
  cat(toJSON(
    list(passed = passed, failed = failed),
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  ), "\n", sep = "", file = report_con)
  if (length(failed) > 0) {
    quit(status = 1)
  }
  quit(status = 0)
}

main()
