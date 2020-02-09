{   Program IMAGE_DISP [<options>]
}
program "gui" image_disp;
%include 'idisp.ins.pas';
define idisp;

const
  max_msg_parms = 2;                   {max parameters we can pass to a message}

var
  event: rend_event_t;                 {descriptor for last event encountered}
  fnam:                                {scratch file name}
    %include '(cog)lib/string_treename.ins.pas';
  p: string_index_t;                   {string parse index}
  conn: file_conn_t;                   {scratch file connection}

  pick: sys_int_machine_t;             {number of token picked from list}
  opt:                                 {command line option name}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {system-independent error code}

label
  next_opt, loop_list, err_list, done_opt, parm_error, done_opts,
  new_image, size_changed, redraw, event_wait, done_event;
{
********************************************************************************
*
*   Start of main routine.
}
begin
  string_cmline_init;                  {init for reading command line}
{
*   Init to defaults before processing command line options.
}
  string_list_init (img_list, util_top_mem_context); {init list of image files}
  img_list.deallocable := false;       {won't need to deallocate individual entries}

  wait := 3.0;
  string_vstring (                     {set default RENDlib device specifier string}
    dev_name,
    default_rendlib_dev,
    sizeof(default_rendlib_dev));
  auto_advance := false;
  list_loop := false;

  bitmap_alloc := false;               {init to RENDlib bitmap not allocated yet}

  imgpix_p := nil;                     {init to no image currently loaded}
{
*   Process command line options.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {nothing more on command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if opt.len <= 0 then goto next_opt;  {ignore null string command line options}

  if opt.str[1] <> '-' then begin      {bare image file name ?}
    img_list.size := opt.len;          {set size of new string to create}
    string_list_line_add (img_list);   {create new entry in image file names list}
    string_copy (opt, img_list.str_p^); {copy this file name into images list}
    goto next_opt;
    end;

  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (                    {pick option name from list}
    opt,                               {option name}
    '-LIST -DEV -SCREEN -WAIT -LOOP',
    pick);                             {number of picked option}
  case pick of                         {do routine for specific option}
{
*   -LIST <filename>
}
1: begin
  string_cmline_token (parm, stat);
  if sys_error(stat) then goto parm_error;
  file_open_read_text (parm, '', conn, stat); {open images list file}
  if sys_error(stat) then goto parm_error;

loop_list:                             {back here to read each new list file entry}
  file_read_text (conn, parm, stat);   {read next line from images list file}
  if file_eof(stat) then begin         {hit end of file ?}
    file_close (conn);                 {close images list file}
    goto done_opt;                     {done with -LIST command line option}
    end;
  if sys_error(stat) then begin
err_list:                              {error with curr images list file entry}
    sys_msg_parm_vstr (msg_parm[1], conn.tnam);
    sys_msg_parm_int (msg_parm[2], conn.lnum);
    sys_error_print (stat, 'rend', 'image_disp_list_err', msg_parm, 2);
    sys_bomb;
    end;

  p := 1;                              {init parse index}
  string_token (parm, p, fnam, stat);  {extract image file name}
  if string_eos(stat) then goto loop_list; {ignore blank lines}
  if sys_error(stat) then goto err_list;
  if fnam.len <= 0 then goto loop_list; {ignore empty file names}

  img_list.size := fnam.len;           {set size to make new images list entry}
  string_list_line_add (img_list);     {create new list entry and make it current}
  string_copy (fnam, img_list.str_p^); {set new list entry value}
  goto loop_list;                      {back to do next line in images list file}
  end;
{
*   -DEV <device specifier string>
}
2: begin
  string_cmline_token (dev_name, stat);
  end;
{
*   -SCREEN
}
3: begin
  string_vstring (dev_name, 'IMAGE_DISP_SCREEN', 17);
  end;
{
*   -WAIT s
}
4: begin
  auto_advance := true;
  string_cmline_token_fpm (wait, stat);
  end;
{
*   -LOOP
}
5: begin
  list_loop := true;
  end;
{
*   Unrecognized command line option.
}
otherwise
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_bad', msg_parm, 1);
    end;                               {end of command line option case statement}
done_opt:                              {done with this command line option}

parm_error:
  string_cmline_parm_check (stat, opt); {check for error with a parameter}
  goto next_opt;

done_opts:                             {done with all the command line options}
  clock_wait := sys_clock_from_fp_rel (wait); {make clock value of wait duration}
{
*   All done processing command line.
}
  draw_setup;                          {set up RENDlib, into graphics mode}
  event_setup;                         {set up the RENDlib events for our use}
  rend_set.exit_rend^;
  ovl_init;                            {one-time initialization of overlay}
  draw_resize;                         {adjust to the drawing area size}

  string_list_pos_abs (img_list, 1);   {position to first image in list}
{
*   Back here to display with a new current image.  The new IMG_LIST
*   position has already been set.
}
new_image:
  image_load (stat);                   {open the new image file}
  sys_error_abort (stat, '', '', nil, 0);
  goto redraw;
{
*   Back here if the RENDlib device changed in size.  The bitmap handle
*   exists, but no pixels are currently allocated.
}
size_changed:
  draw_resize;                         {update to new RENDlib device size}
{
*   Update the whole drawing device.
}
redraw:
  draw_image (0, 0, dev_dx, dev_dy);   {update all drawing device pixels}
{
*   Back here to wait for another event.
}
event_wait:
  rend_set.enter_level^ (0);           {leave graphics mode before event wait}
  rend_event_get (event);              {get next event, wait as needed}
  case event.ev_type of                {which event is this ?}
{
**************************************
*
*   The draw device was closed, or the user asked us to close our use of it.
*   In either case we exit the program.
}
rend_ev_close_k,                       {draw device was closed}
rend_ev_close_user_k: begin            {user aksed to close device}
  rend_end;                            {close all graphics}
  return;
  end;
{
**************************************
*
*   A rectangular region of pixels was previously corrupted, and we are now
*   able to draw into them again.
}
rend_ev_wiped_rect_k: begin
  rend_set.enter_rend^;                {enter graphics mode}
  draw_image (                         {redraw the corrupted area}
    event.wiped_rect.x, event.wiped_rect.y, {top left pixel of redraw area}
    event.wiped_rect.dx, event.wiped_rect.dy); {size of redraw area}
  end;
{
**************************************
*
*   The draw area size has changed, and we can now redraw all the pixels.
}
rend_ev_wiped_resize_k: begin
  goto size_changed;
  end;
{
**************************************
*
*   A key changed state.
}
rend_ev_key_k: begin
  if not event.key.down then goto done_event; {ignore top level key releases}
  case event.key.key_p^.id_user of     {which one of our keys is this ?}

key_next_k: begin                      {advance to next image in list}
      discard( rend_event_key_multiple(event) ); {discard multiple of this event}
      if image_pos_next then begin     {went to next image ?}
        goto new_image;
        end;
      end;

key_prev_k: begin                      {back to previous image in list}
      discard( rend_event_key_multiple(event) ); {discard multiple of this event}
      if image_pos_prev then begin     {went to next image ?}
        goto new_image;
        end;
      end;

    end;                               {end of which key cases}
  end;                                 {end of key changed state event}
{
**************************************
*
*   A new line from standard input is available.
}
rend_ev_stdin_line_k: begin
  rend_get_stdin_line (opt);           {read and ignore the stdin line}
  end;
{
**************************************
*
*   Not an event we care about.  All these events are just ignored.
}
    end;                               {end of event type cases}

done_event:                            {jump here if done processing event}
  goto event_wait;                     {back and wait for another event}
  end.
