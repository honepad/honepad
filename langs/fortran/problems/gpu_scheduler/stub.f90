! Simulation stub. Fill methods from the problem spec.
! add_gpu(gpu_id, mem)
! submit_job(job_id, mem)
! status(job_id)
! assign()
! complete(job_id)
! cancel(job_id)
! set_priority(job_id, priority)

module solution
  use iso_c_binding
  use honepad_json
  implicit none
contains
  subroutine honepad_reset()
  end subroutine

  function honepad_call(method, args, ok, err) result(out)
    character(len=*), intent(in) :: method
    type(c_ptr), intent(in) :: args
    logical, intent(out) :: ok
    character(len=*), intent(out) :: err
    type(c_ptr) :: out
    if (.not. c_associated(args)) then
      out = c_null_ptr
    else
      out = c_null_ptr
    end if
    ok = .false.
    err = "not implemented: " // trim(method)
  end function
end module
