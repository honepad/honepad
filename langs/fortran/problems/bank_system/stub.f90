! Simulation stub. Fill methods from the problem spec.
! create_account(timestamp, account_id)
! deposit(timestamp, account_id, amount)
! transfer(timestamp, source_account_id, target_account_id, amount)
! top_spenders(timestamp, n)
! pay(timestamp, account_id, amount)
! get_payment_status(timestamp, account_id, payment)
! merge_accounts(timestamp, account_id_1, account_id_2)
! get_balance(timestamp, account_id, time_at)

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
