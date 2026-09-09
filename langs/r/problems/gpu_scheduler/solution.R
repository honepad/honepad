new_gpu <- function(gpu_id, mem) {
  item <- new.env(parent = emptyenv())
  item$gpu_id <- gpu_id
  item$mem <- mem
  item$job_id <- NULL
  item
}

new_job <- function(job_id, mem, seq) {
  item <- new.env(parent = emptyenv())
  item$job_id <- job_id
  item$mem <- mem
  item$seq <- seq
  item$priority <- 0
  item$state <- "queued"
  item$gpu_id <- NULL
  item
}

Simulation <- function() {
  self <- new.env(parent = emptyenv())
  self$gpus <- list()
  self$gpu_order <- character()
  self$jobs <- list()
  self$next_seq <- 0

  self$place <- function(job, gpu) {
    job$state <- "running"
    job$gpu_id <- gpu$gpu_id
    gpu$job_id <- job$job_id
  }

  self$add_gpu <- function(gpu_id, mem) {
    if (mem <= 0) {
      return("invalid_request")
    }
    if (!is.null(self$gpus[[gpu_id]])) {
      return("false")
    }
    self$gpus[[gpu_id]] <- new_gpu(gpu_id, mem)
    self$gpu_order <- c(self$gpu_order, gpu_id)
    "true"
  }

  self$submit_job <- function(job_id, mem) {
    if (mem <= 0) {
      return("invalid_request")
    }
    if (!is.null(self$jobs[[job_id]])) {
      return("false")
    }
    self$jobs[[job_id]] <- new_job(job_id, mem, self$next_seq)
    self$next_seq <- self$next_seq + 1
    "true"
  }

  self$status <- function(job_id) {
    job <- self$jobs[[job_id]]
    if (is.null(job)) {
      return("")
    }
    job$state
  }

  self$assign <- function() {
    queued <- list()
    for (job in self$jobs) {
      if (job$state == "queued") {
        queued[[length(queued) + 1]] <- job
      }
    }
    if (length(queued) > 0) {
      pri <- vapply(queued, function(job) job$priority, numeric(1))
      seq <- vapply(queued, function(job) job$seq, numeric(1))
      queued <- queued[order(-pri, seq)]
    }
    for (job in queued) {
      for (gpu_id in self$gpu_order) {
        gpu <- self$gpus[[gpu_id]]
        if (is.null(gpu$job_id) && gpu$mem >= job$mem) {
          self$place(job, gpu)
          return(job$job_id)
        }
      }
    }
    ""
  }

  self$complete <- function(job_id) {
    job <- self$jobs[[job_id]]
    if (is.null(job) || job$state != "running" || is.null(job$gpu_id)) {
      return("invalid_request")
    }
    self$gpus[[job$gpu_id]]$job_id <- NULL
    job$gpu_id <- NULL
    job$state <- "done"
    "true"
  }

  self$cancel <- function(job_id) {
    job <- self$jobs[[job_id]]
    if (is.null(job) || job$state == "done") {
      return("invalid_request")
    }
    if (job$state == "running" && !is.null(job$gpu_id)) {
      self$gpus[[job$gpu_id]]$job_id <- NULL
    }
    self$jobs[[job_id]] <- NULL
    if (job$state == "running") {
      self$assign()
    }
    "true"
  }

  self$set_priority <- function(job_id, priority) {
    job <- self$jobs[[job_id]]
    if (is.null(job) || job$state != "queued") {
      return("invalid_request")
    }
    job$priority <- priority
    "true"
  }

  self
}
