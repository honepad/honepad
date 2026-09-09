module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: gpu_t
    character(len=:), allocatable :: gpu_id
    integer(int64) :: mem = 0
    character(len=:), allocatable :: job_id
    logical :: busy = .false.
  end type

  type :: job_t
    character(len=:), allocatable :: job_id
    integer(int64) :: mem = 0
    integer(int64) :: seq = 0
    integer(int64) :: priority = 0
    character(len=16) :: state = "queued"
    character(len=:), allocatable :: gpu_id
    logical :: has_gpu = .false.
  end type

  type :: sim_t
    type(gpu_t), allocatable :: gpus(:)
    integer :: gpu_n = 0
    type(job_t), allocatable :: jobs(:)
    integer :: job_n = 0
    integer(int64) :: next_seq = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%gpus)) deallocate (sim%gpus)
    if (allocated(sim%jobs)) deallocate (sim%jobs)
    sim%gpu_n = 0
    sim%job_n = 0
    sim%next_seq = 0
  end subroutine

  function honepad_call(method, args, ok, err) result(out)
    character(len=*), intent(in) :: method
    type(c_ptr), intent(in) :: args
    logical, intent(out) :: ok
    character(len=*), intent(out) :: err
    type(c_ptr) :: out
    character(len=:), allocatable :: text
    ok = .true.
    err = ""
    if (method == "add_gpu") then
      text = add_gpu(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "submit_job") then
      text = submit_job(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "status") then
      text = job_status(arg_str(args, 0))
    else if (method == "assign") then
      text = assign_job()
    else if (method == "complete") then
      text = complete_job(arg_str(args, 0))
    else if (method == "cancel") then
      text = cancel_job(arg_str(args, 0))
    else if (method == "set_priority") then
      text = set_priority(arg_str(args, 0), arg_i64(args, 1))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_gpu(gpu_id) result(idx)
    character(len=*), intent(in) :: gpu_id
    integer :: i
    idx = 0
    do i = 1, sim%gpu_n
      if (sim%gpus(i)%gpu_id == gpu_id) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_job(job_id) result(idx)
    character(len=*), intent(in) :: job_id
    integer :: i
    idx = 0
    do i = 1, sim%job_n
      if (sim%jobs(i)%job_id == job_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_gpus()
    type(gpu_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%gpus)) then
      allocate (sim%gpus(8))
      return
    end if
    if (sim%gpu_n < size(sim%gpus)) return
    cap = size(sim%gpus) * 2
    allocate (tmp(cap))
    tmp(1:sim%gpu_n) = sim%gpus(1:sim%gpu_n)
    call move_alloc(tmp, sim%gpus)
  end subroutine

  subroutine grow_jobs()
    type(job_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%jobs)) then
      allocate (sim%jobs(8))
      return
    end if
    if (sim%job_n < size(sim%jobs)) return
    cap = size(sim%jobs) * 2
    allocate (tmp(cap))
    tmp(1:sim%job_n) = sim%jobs(1:sim%job_n)
    call move_alloc(tmp, sim%jobs)
  end subroutine

  function add_gpu(gpu_id, mem) result(out)
    character(len=*), intent(in) :: gpu_id
    integer(int64), intent(in) :: mem
    character(len=:), allocatable :: out
    if (mem <= 0) then
      out = "invalid_request"
      return
    end if
    if (find_gpu(gpu_id) > 0) then
      out = "false"
      return
    end if
    call grow_gpus()
    sim%gpu_n = sim%gpu_n + 1
    sim%gpus(sim%gpu_n)%gpu_id = gpu_id
    sim%gpus(sim%gpu_n)%mem = mem
    sim%gpus(sim%gpu_n)%busy = .false.
    if (allocated(sim%gpus(sim%gpu_n)%job_id)) deallocate (sim%gpus(sim%gpu_n)%job_id)
    out = "true"
  end function

  function submit_job(job_id, mem) result(out)
    character(len=*), intent(in) :: job_id
    integer(int64), intent(in) :: mem
    character(len=:), allocatable :: out
    if (mem <= 0) then
      out = "invalid_request"
      return
    end if
    if (find_job(job_id) > 0) then
      out = "false"
      return
    end if
    call grow_jobs()
    sim%job_n = sim%job_n + 1
    sim%jobs(sim%job_n)%job_id = job_id
    sim%jobs(sim%job_n)%mem = mem
    sim%jobs(sim%job_n)%seq = sim%next_seq
    sim%jobs(sim%job_n)%priority = 0
    sim%jobs(sim%job_n)%state = "queued"
    sim%jobs(sim%job_n)%has_gpu = .false.
    if (allocated(sim%jobs(sim%job_n)%gpu_id)) deallocate (sim%jobs(sim%job_n)%gpu_id)
    sim%next_seq = sim%next_seq + 1
    out = "true"
  end function

  function job_status(job_id) result(out)
    character(len=*), intent(in) :: job_id
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_job(job_id)
    if (idx == 0) then
      out = ""
      return
    end if
    out = trim(sim%jobs(idx)%state)
  end function

  subroutine place(job_idx, gpu_idx)
    integer, intent(in) :: job_idx, gpu_idx
    sim%jobs(job_idx)%state = "running"
    sim%jobs(job_idx)%gpu_id = sim%gpus(gpu_idx)%gpu_id
    sim%jobs(job_idx)%has_gpu = .true.
    sim%gpus(gpu_idx)%job_id = sim%jobs(job_idx)%job_id
    sim%gpus(gpu_idx)%busy = .true.
  end subroutine

  function assign_job() result(out)
    character(len=:), allocatable :: out
    integer :: queued(256)
    integer :: qn, i, j, g, tmp
    qn = 0
    do i = 1, sim%job_n
      if (trim(sim%jobs(i)%state) == "queued") then
        qn = qn + 1
        queued(qn) = i
      end if
    end do
    do i = 1, qn - 1
      do j = i + 1, qn
        if (sim%jobs(queued(j))%priority > sim%jobs(queued(i))%priority .or. &
            (sim%jobs(queued(j))%priority == sim%jobs(queued(i))%priority .and. &
             sim%jobs(queued(j))%seq < sim%jobs(queued(i))%seq)) then
          tmp = queued(i)
          queued(i) = queued(j)
          queued(j) = tmp
        end if
      end do
    end do
    do i = 1, qn
      do g = 1, sim%gpu_n
        if ((.not. sim%gpus(g)%busy) .and. sim%gpus(g)%mem >= sim%jobs(queued(i))%mem) then
          call place(queued(i), g)
          out = sim%jobs(queued(i))%job_id
          return
        end if
      end do
    end do
    out = ""
  end function

  function complete_job(job_id) result(out)
    character(len=*), intent(in) :: job_id
    character(len=:), allocatable :: out
    integer :: idx, g
    idx = find_job(job_id)
    if (idx == 0 .or. trim(sim%jobs(idx)%state) /= "running" .or. .not. sim%jobs(idx)%has_gpu) then
      out = "invalid_request"
      return
    end if
    g = find_gpu(sim%jobs(idx)%gpu_id)
    if (g > 0) then
      sim%gpus(g)%busy = .false.
      if (allocated(sim%gpus(g)%job_id)) deallocate (sim%gpus(g)%job_id)
    end if
    sim%jobs(idx)%has_gpu = .false.
    if (allocated(sim%jobs(idx)%gpu_id)) deallocate (sim%jobs(idx)%gpu_id)
    sim%jobs(idx)%state = "done"
    out = "true"
  end function

  subroutine drop_job(idx)
    integer, intent(in) :: idx
    if (idx < sim%job_n) then
      sim%jobs(idx) = sim%jobs(sim%job_n)
    end if
    sim%job_n = sim%job_n - 1
  end subroutine

  function cancel_job(job_id) result(out)
    character(len=*), intent(in) :: job_id
    character(len=:), allocatable :: out
    integer :: idx, g
    logical :: running
    character(len=:), allocatable :: ignored
    idx = find_job(job_id)
    if (idx == 0 .or. trim(sim%jobs(idx)%state) == "done") then
      out = "invalid_request"
      return
    end if
    running = trim(sim%jobs(idx)%state) == "running"
    if (running .and. sim%jobs(idx)%has_gpu) then
      g = find_gpu(sim%jobs(idx)%gpu_id)
      if (g > 0) then
        sim%gpus(g)%busy = .false.
        if (allocated(sim%gpus(g)%job_id)) deallocate (sim%gpus(g)%job_id)
      end if
    end if
    call drop_job(idx)
    if (running) then
      ignored = assign_job()
    end if
    out = "true"
  end function

  function set_priority(job_id, priority) result(out)
    character(len=*), intent(in) :: job_id
    integer(int64), intent(in) :: priority
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_job(job_id)
    if (idx == 0 .or. trim(sim%jobs(idx)%state) /= "queued") then
      out = "invalid_request"
      return
    end if
    sim%jobs(idx)%priority = priority
    out = "true"
  end function
end module
