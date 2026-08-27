program adapter
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  use solution
  implicit none

  character(len=4096) :: path
  character(len=:), allocatable :: raw, case_id, method, got, want, exc
  character(len=256) :: call_err
  type(c_ptr) :: cases, failed, report, row, calls, call_row
  type(c_ptr) :: id_v, method_v, expected, args, actual
  integer(int64) :: passed, c, i, ncases, ncalls
  logical :: ok, call_ok
  integer :: argc

  argc = command_argument_count()
  if (argc < 1) then
    write (0, '(a)') "usage: adapter cases.json"
    stop 2
  end if
  call get_command_argument(1, path)
  raw = read_file_f(trim(path))
  if (len(raw) == 0) then
    write (0, '(a)') "cannot read cases.json"
    stop 2
  end if
  cases = json_parse_f(raw)
  if (.not. c_associated(cases) .or. .not. json_is_arr(cases)) then
    write (0, '(a)') "cases.json must be a JSON list"
    stop 2
  end if

  failed = json_arr_f()
  passed = 0
  ncases = json_arr_len_f(cases)
  do c = 0, ncases - 1
    row = json_arr_at_f(cases, c)
    call honepad_reset()
    id_v = json_obj_get_f(row, "id")
    calls = json_obj_get_f(row, "calls")
    if (.not. json_is_str(id_v) .or. .not. json_is_arr(calls)) then
      write (0, '(a)') "bad case row"
      stop 2
    end if
    case_id = json_as_str_f(id_v)
    ok = .true.
    ncalls = json_arr_len_f(calls)
    do i = 0, ncalls - 1
      call_row = json_arr_at_f(calls, i)
      method_v = json_obj_get_f(call_row, "m")
      expected = json_obj_get_f(call_row, "e")
      args = json_obj_get_f(call_row, "a")
      if (.not. json_is_str(method_v)) then
        write (0, '(a)') "bad method"
        stop 2
      end if
      method = json_as_str_f(method_v)
      call_err = ""
      actual = honepad_call(method, args, call_ok, call_err)
      if (.not. call_ok) then
        exc = "exc:" // trim(call_err)
        call json_arr_push_f(failed, fail_row(case_id, i, method, expected, json_str_f(exc)))
        ok = .false.
        exit
      end if
      got = json_stringify_f(actual)
      want = json_stringify_f(expected)
      if (got /= want) then
        call json_arr_push_f(failed, fail_row(case_id, i, method, expected, actual))
        ok = .false.
        exit
      end if
      call json_free_f(actual)
    end do
    if (ok) then
      passed = passed + 1
    end if
  end do

  report = json_obj_f()
  call json_obj_put_f(report, "passed", json_int_f(passed))
  call json_obj_put_f(report, "failed", failed)
  write (*, '(a)') json_stringify_f(report)
  if (json_arr_len_f(failed) == 0) then
    call json_free_f(report)
    call json_free_f(cases)
    stop 0
  end if
  call json_free_f(report)
  call json_free_f(cases)
  stop 1

contains

  function fail_row(case_id_in, index, method_in, expected_in, actual_in) result(row_out)
    character(len=*), intent(in) :: case_id_in, method_in
    integer(int64), intent(in) :: index
    type(c_ptr), intent(in) :: expected_in, actual_in
    type(c_ptr) :: row_out
    row_out = json_obj_f()
    call json_obj_put_f(row_out, "case", json_str_f(case_id_in))
    call json_obj_put_f(row_out, "index", json_int_f(index))
    call json_obj_put_f(row_out, "method", json_str_f(method_in))
    call json_obj_put_f(row_out, "expected", json_clone_f(expected_in))
    call json_obj_put_f(row_out, "actual", actual_in)
  end function
end program
