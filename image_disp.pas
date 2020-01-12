{   Program IMAGE_DISP <image file name> [<options>]
*
*   Display the image centered in the current window.
*
*   -DEV <RENDlib device specifier string>
*
*     Explicitly set the RENDlib device to use for drawing.  The default is to
*     use the IMAGE_DISP logical RENDlib device.  The default rendlib.dev
*     file causes this to try the current window first, then the whole workstation
*     screen, then the VIDEO logical device.
*
*   -SCREEN
*
*     Use the whole screen, if possible, to display the image.  This is the same
*     as specifying -DEV IMAGE_DISP_SCREEN.
*
*   -ZOOM n
*
*     Specify pixel replication zoom factor.  This must be an integer greater
*     than zero.  The default is -FIT.
*
*   -FIT
*
*     Causes the largest zoom factor to be used so that the image still fits
*     onto the draw area.  This is the default.  The zoom factor will be
*     re-evaluated when the window size is changed, until the first time the
*     zoom factor is interactively altered.
*
*   -ANCH <anchor point name>
*
*     Specifies how the image is to be anchored to the display area.
*     A different anchor point name is available for each corner, center
*     of an edge, and the middle of the image.  The names specify the points
*     as arranged:
*
*       UL   UM   UR
*       ML   MID  MR
*       LL   LM   LR
*
*     For example, -ANCH UL will put the upper left corner of the image
*     into the upper left corner of the display area.  The anchor point
*     is also the point about which any zoom is done.  The default is
*     MID (middle of image goes in middle of display area).
*
*   -WAIT s
*
*     Automatically sequence between the images on the command line,
*     waiting S seconds between each one.
*
*   -LOOP
*
*     Loop back to the first image after displaying the last.  The default
*     is to exit after the last image.  This option puts IMAGE_DISP into
*     an infinite loop.
}
program "gui" image_disp;
%include 'idisp.ins.pas';
define idisp;

const
  max_msg_parms = 2;                   {max parameters we can pass to a message}

var
  x, y: real;                          {scratch FP coordinates}
  ix, iy: sys_int_machine_t;           {scratch integer coordinates}
  ii: sys_int_machine_t;               {scratch integer an loop counter}
  start_x: sys_int_machine_t;          {first image scan line pixel used}
  start_x_zoom: sys_int_machine_t;     {starting X zoom phase}
  start_y: sys_int_machine_t;          {first image scan line used}
  ul_x, ul_y: sys_int_machine_t;       {upper left corner of rect to draw img in}
  lr_x, lr_y: sys_int_machine_t;       {next pix below and right of draw rectangle}
  dx, dy: sys_int_machine_t;           {size of image rectangle to draw}
  event: rend_event_t;                 {descriptor for last event encountered}
  fnam:                                {scratch file name}
    %include '(cog)lib/string_treename.ins.pas';
  p: string_index_t;                   {string parse index}
  conn: file_conn_t;                   {scratch file connection}
  clock_wait: sys_clock_t;             {WAIT value in sys clock format}
  clock_done: sys_clock_t;             {time when done waiting}
  pending_resize: boolean;             {TRUE if window resized but not redrawn}
  pending_redraw: boolean;             {TRUE if window needs redrawing}

  pick: sys_int_machine_t;             {number of token picked from list}
  opt:                                 {command line option name}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {system-independent error code}

label
  next_opt, loop_list, err_list, done_opt,  parm_error, done_opts,
  next_image, new_image, size_changed, redraw, done_drawing, event_wait,
  zoom_in, zoom_out, done_event;
{
********************************************************************************
*
*   Local subroutine WAIT_CHANGED
*
*   Wait for the current image file to have changed.
}
procedure wait_changed;

const
  wait_sec_k = 1.0;                    {seconds to wait before re-checking file}

var
  finfo: file_info_t;                  {current file info about image file}
  stat: sys_err_t;                     {completion status code}

label
  wait_loop;

begin
wait_loop:                             {back here to wait again for file to change}
  file_info (                          {get info about newly opened image file}
    img.tnam,                          {name of file inquiring about}
    [file_iflag_dtm_k],                {we are requesting last modified time stamp}
    finfo,                             {returned date/time info}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  if                                   {file no different than when last opened ?}
      (finfo.modified.low = imgfile_info.modified.low) and
      (finfo.modified.sec = imgfile_info.modified.sec) and
      (finfo.modified.high = imgfile_info.modified.high)
      then begin
    sys_wait (wait_sec_k);             {wait a while for file to possibly change}
    goto wait_loop;                    {back and check file again}
    end;
  end;
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

  anch_img.x := 0.5;                   {init to defaults before reading command line}
  anch_img.y := 0.5;
  anch_dev.x := 0.5;
  anch_dev.y := 0.5;
  zoom := 1;
  fit_on := true;
  auto_advance := false;
  auto_loop := false;
  backg_clear := true;
  wait := 3.0;
  img_open := false;
  scan_dev_p := nil;

  string_vstring (                     {set default RENDlib device specifier string}
    dev_name,
    default_rendlib_dev,
    sizeof(default_rendlib_dev));
{
*   Process command line options.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {nothing more on command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if opt.len <= 0 then goto next_opt;  {ignore null string command line options}

  if opt.str[1] <> '-' then begin      {assume this is a new file name}
    img_list.size := opt.len;          {set size of new string to create}
    string_list_line_add (img_list);   {create new entry in image file names list}
    string_copy (opt, img_list.str_p^); {copy this file name into images list}
    goto next_opt;
    end;

  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (                    {pick option name from list}
    opt,                               {option name}
    '-DEV -SCREEN -ZOOM -ANCH -FIT -WAIT -LOOP -NOCLEAR -LIST',
    pick);                             {number of picked option}
  case pick of                         {do routine for specific option}
{
*   -DEV <device specifier string>
}
1: begin
  string_cmline_token (dev_name, stat);
  end;
{
*   -SCREEN
}
2: begin
  string_vstring (dev_name, 'IMAGE_DISP_SCREEN', 17);
  end;
{
*   -ZOOM n
}
3: begin
  string_cmline_token_int (zoom, stat);
  if sys_error(stat) then goto parm_error;
  if zoom < 1 then begin               {illegal zoom value ?}
    string_cmline_reuse;               {re-use last command line token}
    string_cmline_token (parm, stat);
    sys_msg_parm_vstr (msg_parm[1], parm);
    sys_msg_parm_vstr (msg_parm[2], opt);
    sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);
    end;
  fit_on := false;
  end;
{
*   -ANCH <anchor point name>
}
4: begin
  string_cmline_token (parm, stat);    {get anchor point name}
  if sys_error(stat) then goto parm_error;
  string_upcase (parm);
  string_tkpick80 (parm,
    'UL UM UR ML MID MR LL LM LR',
    pick);
  case pick of
1:  begin                              {UL}
      anch_img.x := 0.0;
      anch_img.y := 0.0;
      end;
2:  begin                              {UM}
      anch_img.x := 0.5;
      anch_img.y := 0.0;
      end;
3:  begin                              {UR}
      anch_img.x := 1.0;
      anch_img.y := 0.0;
      end;
4:  begin                              {ML}
      anch_img.x := 0.0;
      anch_img.y := 0.5;
      end;
5:  begin                              {MID}
      anch_img.x := 0.5;
      anch_img.y := 0.5;
      end;
6:  begin                              {MR}
      anch_img.x := 1.0;
      anch_img.y := 0.5;
      end;
7:  begin                              {LL}
      anch_img.x := 0.0;
      anch_img.y := 1.0;
      end;
8:  begin                              {LM}
      anch_img.x := 0.5;
      anch_img.y := 1.0;
      end;
9:  begin                              {LR}
      anch_img.x := 1.0;
      anch_img.y := 1.0;
      end;
otherwise
    sys_msg_parm_vstr (msg_parm[1], parm);
    sys_msg_parm_vstr (msg_parm[2], opt);
    sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);
    end;
  anch_dev.x := anch_img.x;
  anch_dev.y := anch_img.y;
  end;                                 {end of command line option -ANCH case}
{
*   -FIT
}
5: begin
  fit_on := true;
  end;
{
*   -WAIT s
}
6: begin
  auto_advance := true;
  string_cmline_token_fpm (wait, stat);
  end;
{
*   -LOOP
}
7: begin
  auto_loop := true;
  end;
{
*   -NOCLEAR
}
8: begin
  backg_clear := false;
  end;
{
*   -LIST <filename>
}
9: begin
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
  string_list_pos_start (img_list);    {position to before first image file}

  draw_setup;                          {set up RENDlib, into graphics mode}
  event_setup;                         {set up the RENDlib events for our use}
  rend_set.exit_rend^;

  scan_img_p := nil;                   {init to no scan line memory allocated}
  img_open := false;                   {init to no image file currently open}
  first_img := true;                   {init to next draw is first image}
{
*   Back here to advance to next image in list and display it.
}
next_image:
  if not image_next then begin         {no next image to advance to ?}
    rend_end;                          {close the graphics}
    return;                            {end the program}
    end;
{
*   Back here to display with a new current image.  The new IMG_LIST
*   position has already been set.
}
new_image:
  image_close (stat);                  {make sure old image, if any, is closed}
  sys_error_abort (stat, '', '', nil, 0);
  image_open (stat);                   {open the new image file}
  sys_error_abort (stat, '', '', nil, 0);

  if scan_img_p <> nil then begin      {scan line buffer previously allocated ?}
    rend_mem_dealloc (scan_img_p, rend_scope_dev_k); {deallocate scan line buffer}
    end;

  rend_mem_alloc (                     {allocate memory for image scan line}
    img.x_size * sizeof(img_pixel1_t), {amount of memory to allocate}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    true,                              {we will need to separately deallocate this}
    scan_img_p);                       {returned pointer to the new memory}
{
*   Back here if the RENDlib device changed in size.  The bitmap handle
*   exists, but no pixels are currently allocated.
}
size_changed:
  image_open (stat);                   {make sure image input file is open}
  sys_error_abort (stat, '', '', nil, 0);

  draw_resize;                         {update to RENDlib device size}
{
*   Back here to redraw.
}
redraw:
  image_open (stat);                   {make sure image input file is open}
  sys_error_abort (stat, '', '', nil, 0);

  rend_set.enter_level^ (1);           {get into graphics mode}
  if img.next_y <> 0 then begin        {image file not at start of image ?}
    img_rewind (img, stat);            {rewind image file to first scan line}
    rend_error_abort (stat, 'img', 'rewind', nil, 0);
    end;

  if first_img or backg_clear then begin {clear to background color ?}
    rend_set.min_bits_vis^ (1.0);      {nothing special needed for background clear}
    rend_set.dith_on^ (false);         {disable dithering, if possible}
    rend_set.rgb^ (0.0, 0.0, 0.0);     {set color of background}
    rend_prim.clear_cwind^;            {clear to backround color}
    end;

  rend_set.min_bits_vis^ (24.0);       {try for maximum color resolution}

  x :=                                 {top left image corner in 0-1 dev coordinates}
    anch_dev.x - (zoom * anch_img.x * img.x_size / image_width);
  y :=
    anch_dev.y - (zoom * anch_img.y * img.y_size / image_height);

  uli_x := round((image_width * x) - 0.001); {dev pixel mapped to top left of image}
  uli_y := round((image_height * y) - 0.001);

  ul_x := max(0, min(image_width, uli_x)); {upper left of rectangle to draw}
  ul_y := max(0, min(image_height, uli_y));

  lr_x := max(0, min(image_width, uli_x + (img.x_size * zoom)));
  lr_y := max(0, min(image_height, uli_y + (img.y_size * zoom)));

  dx := max(0, lr_x - ul_x);           {size of rectangle to draw}
  dy := max(0, lr_y - ul_y);

  start_x := (ul_x - uli_x) div zoom;  {first image pixel we actually use}
  start_y := (ul_y - uli_y) div zoom;

  start_x_zoom := zoom - ((ul_x - uli_x) mod zoom); {zoom phase for first image pixel}
  y_zoom := zoom - ((ul_y - uli_y) mod zoom);

  if (dx <= 0) or (dy <= 0) then goto done_drawing; {nothing to draw ?}
  rend_set.cpnt_2dimi^ (ul_x, ul_y);   {declare position and size of image rectangle}
  rend_prim.rect_px_2dimcl^ (dx, dy);

  repeat
    img_read_scan1 (img, scan_img_p^, stat); {read scan line from image file}
    if file_eof(stat) then goto done_drawing;
    rend_error_abort (stat, 'img', 'read_scan_line', nil, 0);
    until img.next_y > start_y;        {back if not read first useable scan line yet}

  for iy := 1 to dy do begin           {once for each line in rectangle to draw}
    if y_zoom <= 0 then begin          {need to read new scan line ?}
      img_read_scan1 (img, scan_img_p^, stat); {read scan line from image file}
      if file_eof(stat) then goto done_drawing;
      rend_error_abort (stat, 'img', 'read_scan_line', nil, 0);
      y_zoom := zoom;                  {reset number of times left to use this scan}
      end;
    if zoom <= 1
      then begin                       {no horizontal zoom, write pixels directly}
        rend_prim.span_2dimcl^ (       {write this scan line to draw rectangle}
          dx, scan_img_p^[start_x]);
        end
      else begin                       {horizontal zoom in effect, copy pixels}
        ix := start_x;                 {init image scan line index for first pixel}
        x_zoom := start_x_zoom;        {init zoom phase for first pixel}
        for ii := 0 to dx-1 do begin   {once for each device pixel to fill in}
          if x_zoom <= 0 then begin    {exhausted this pixel, move on to next ?}
            ix := ix + 1;              {advance to next source pixel}
            x_zoom := zoom;            {reset zoom phase for new pixel}
            end;
          scan_dev_p^[ii] := scan_img_p^[ix]; {copy this output pixel}
          x_zoom := x_zoom - 1;        {one less time we can use this input pixel}
          end;                         {back to do next output pixel}
        rend_prim.span_2dimcl^ (       {write this scan line to draw rectangle}
          dx, scan_dev_p^);
        end
      ;                                {done writing this output scan line}
    y_zoom := y_zoom - 1;              {one less time we can use this input scan}
    end;                               {back to write next output scan line}

done_drawing:                          {all done drawing the image}
  clock_done := sys_clock_add (        {make sys clock time when done waiting}
    sys_clock, clock_wait);
  rend_set.clip_2dim_on^ (clip_handle, false); {disable 2DIM clip window}
  pending_resize := false;             {no more pending redraws of any kind}
  pending_redraw := false;
  first_img := false;                  {next redraw won't be first image draw}

  if                                   {should close image file ?}
      auto_advance or                  {automatically going to advance to next img ?}
      auto_loop                        {in infinite loop thru image list ?}
      then begin
    image_close (stat);                {close currently displayed image file}
    sys_error_abort (stat, '', '', nil, 0);
    end;
{
*   Back here to wait for another event.
}
event_wait:
  rend_set.enter_level^ (0);           {leave graphics mode before event wait}

  if                                   {automatically advance to next image now ?}
      auto_advance and                 {auto advance enabled ?}
      (sys_clock_compare(sys_clock, clock_done) <> sys_compare_lt_k) {wait over ?}
      then begin
    if auto_loop and (img_list.n <= 1) then begin {just redisplaying same image ?}
      wait_changed;                    {wait for image file to change}
      end;
    goto next_image;                   {advance to next image in list}
    end;

  if pending_resize or pending_redraw or auto_advance
    then begin                         {need to take other action than event ?}
      rend_event_get_nowait (event);   {get next event immediately}
      end
    else begin                         {nothing pending, wait for next event}
      rend_event_get (event);
      end
    ;
  case event.ev_type of                {what kind of event is this ?}
{
**************************************
*
*   No event was waiting.
}
rend_ev_none_k: begin
  if pending_resize then goto size_changed;
  if pending_redraw then goto redraw;
  sys_wait (0.25);
  end;
{
**************************************
*
*   The draw device was closed, or the user asked us to close our use of it.
*   In either case we exit the program.
}
rend_ev_close_k,                       {draw device was closed}
rend_ev_close_user_k: begin            {user aksed to close device}
  image_close (stat);                  {close current image file, if open}
  sys_error_abort (stat, '', '', nil, 0);
  rend_end;                            {close all graphics}
  return;
  end;
{
**************************************
*
*   A line of text is available on standard input.
}
rend_ev_stdin_line_k: begin            {a line of text is available from standard in}
  rend_get_stdin_line (opt);           {read the pending standard input line}
  if opt.len > 0 then begin            {there were some characters here ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    rend_message_bomb ('rend', 'image_disp_cmd_bad', msg_parm, 1);
    end;
  image_close (stat);                  {close current image file, if open}
  sys_error_abort (stat, '', '', nil, 0);
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
  rend_set.clip_2dim^ (                {enable clip window and set coordinates}
    clip_handle,                       {handle to clip window}
    event.wiped_rect.x,                {left edge}
    event.wiped_rect.x + event.wiped_rect.dx, {right edge}
    event.wiped_rect.y,                {top edge}
    event.wiped_rect.y + event.wiped_rect.dy, {bottom edge}
    true);                             {draw inside, clip outside}
  pending_redraw := true;              {image needs to be redrawn}
  end;
{
**************************************
*
*   The draw area size has changed, and we can now redraw all the pixels.
}
rend_ev_wiped_resize_k: begin
  pending_resize := true;
  end;
{
**************************************
*
*   A key changed state.
}
rend_ev_key_k: begin
  if not event.key.down then goto done_event; {ignore top level key releases}
  case event.key.key_p^.id_user of     {which one of our keys is this ?}

key_pan_k: begin                       {pan old anchor point to new anchor point}
      pending_redraw := pending_redraw or event_pan (event.key.x, event.key.y);
      end;

key_inquire_k: begin                   {get value of pixel or rectangular region}
      event_inquire (event.key.x, event.key.y); {handle the inquiry}
      end;

key_zoom_in_k: begin                   {zoom in one increment}
zoom_in:
      zoom := max(zoom + 1, round(zoom * zoom_factor));
      fit_on := false;                 {disable auto-scale}
      pending_redraw := true;          {image needs to be redrawn}
      end;

key_zoom_out_k: begin                  {zoom out one increment}
zoom_out:
      if zoom <= 1 then goto done_event; {can't zoom back any further ?}
      zoom := max(1, min(zoom - 1, round(zoom / zoom_factor)));
      fit_on := false;                 {disable auto-scale}
      pending_redraw := true;          {image needs to be redrawn}
      end;

key_zoom_k: begin                      {zoom in/out depending on SHIFT state}
      if rend_key_mod_shift_k in event.key.modk
        then goto zoom_out
        else goto zoom_in;
      end;

key_next_k: begin                      {advance to next image in list}
      if img_list.curr >= img_list.n then begin {already at last image in list ?}
        if auto_loop
          then begin                   {images list is circular}
            string_list_pos_abs (img_list, 1);
            goto new_image;
            end
          else begin                   {images list is linear}
            goto done_event;           {ignore this event}
            end
          ;
        end;
      string_list_pos_rel (img_list, 1); {advance to next image in list}
      goto new_image;                  {back to display this new image}
      end;

key_prev_k: begin                      {back to previous image in list}
      if img_list.curr <= 1 then begin {already at first image in list ?}
        if auto_loop
          then begin                   {images list is circular}
            string_list_pos_last (img_list);
            goto new_image;
            end
          else begin                   {images list is linear}
            goto done_event;           {ignore this event}
            end
          ;
        end;
      string_list_pos_rel (img_list, -1); {back to previous image in list}
      goto new_image;                  {back to display this new image}
      end;

    end;                               {end of which key cases}
  end;                                 {end of key changed state event}
{
**************************************
*
*   Not an event we care about.  All these events are just ignored.
}
    end;                               {end of event type cases}

done_event:                            {jump here if done processing event}
  goto event_wait;                     {back and wait for another event}
  end.
