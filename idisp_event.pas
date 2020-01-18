{   User events handling.
}
module idisp_event;
define event_setup;
define event_pan;
define event_inquire;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Subroutine EVENT_SETUP
*
*   Set up the RENDlib event state for our use.
}
procedure event_setup;                 {set up RENDlib events for our use}
  val_param;

begin
  rend_set.event_req_close^ (true);    {enable events we care about}
  rend_set.event_req_wiped_resize^ (true);
  rend_set.event_req_wiped_rect^ (true);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_pointer_k, 1),
    key_pan_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_pointer_k, 2),
    key_inquire_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_arrow_up_k, 0),
    key_zoom_in_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_arrow_down_k, 0),
    key_zoom_out_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_pointer_k, 3),
    key_zoom_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_arrow_right_k, 0),
    key_next_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_arrow_left_k, 0),
    key_prev_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_enter_k, 0),
    key_prev_k);
  rend_event_req_stdin_line (true);
  end;
