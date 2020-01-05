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
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'vect.ins.pas';
%include 'rend.ins.pas';

const
  default_rendlib_dev = 'IMAGE_DISP';  {default RENDlib device name}
  zoom_factor = 1.50;                  {relative incremental zoom factor}
  max_msg_parms = 2;                   {max parameters we can pass to a message}
{
*   Our internal IDs for interactive keys the user can hit.
}
  key_pan_k = 1;                       {translate image in X,Y on screen}
  key_inquire_k = 2;                   {inquire value of image region}
  key_zoom_in_k = 3;                   {increase image magnification}
  key_zoom_out_k = 4;                  {decrease image magnification}
  key_zoom_k = 5;                      {zoom in/out depending on SHIFT}
  key_next_k = 6;                      {advance to next image in list}
  key_prev_k = 7;                      {advance to previous image in list}

type
  anch_t = record                      {info about an anchor point}
    x, y: real;                        {0.0 to 1.0 relative anchor value}
    end;

  inqrect_t = record                   {describes bounds of inquire rectangle}
    xmin, xmax: sys_int_machine_t;     {min/max X coordinates, inclusive}
    ymin, ymax: sys_int_machine_t;     {min/max Y coordinates, inclusive}
    end;

var
  img_list: string_list_t;             {file names of images to display}
  tnam_p: ^string_treename_t;          {scratch pointer to image file name string}
  img: img_conn_t;                     {handle to open image file}
  dev_name:                            {RENDlib device name}
    %include '/cognivision_links/dsee_libs/string/string_treename.ins.pas';
  rend_dev: rend_dev_id_t;             {RENDlib ID for our graphics device}
  image_width: sys_int_machine_t;      {horizontal size of RENDlib device}
  image_height: sys_int_machine_t;     {vertical size of RENDlib device}
  aspect: real;                        {aspect ratio of RENDlib device}
  wait: real;                          {seconds to wait in auto advance mode}
  clock_wait: sys_clock_t;             {WAIT value in sys clock format}
  clock_done: sys_clock_t;             {time when done waiting}
  image_bitmap: rend_bitmap_handle_t;  {handle to RENDlib bitmap}
  clip_handle: rend_clip_2dim_handle_t; {handle to 2DIM clip rectangle}
  anch_img: anch_t;                    {anchor point on raw image}
  anch_dev: anch_t;                    {anchor point on RENDlib device}
  x, y: real;                          {scratch FP coordinates}
  ix, iy: sys_int_machine_t;           {scratch integer coordinates}
  i: sys_int_machine_t;                {scratch integer an loop counter}
  start_x: sys_int_machine_t;          {first image scan line pixel used}
  start_x_zoom: sys_int_machine_t;     {starting X zoom phase}
  start_y: sys_int_machine_t;          {first image scan line used}
  x_zoom, y_zoom: sys_int_machine_t;   {current X and Y zoom phase}
  uli_x, uli_y: sys_int_machine_t;     {dev pixel mapped to top left corner of image}
  ul_x, ul_y: sys_int_machine_t;       {upper left corner of rect to draw img in}
  lr_x, lr_y: sys_int_machine_t;       {next pix below and right of draw rectangle}
  dx, dy: sys_int_machine_t;           {size of image rectangle to draw}
  zoom: sys_int_machine_t;             {integer zoom factor}
  scan_img_p: img_scan1_arg_p_t;       {pointer to scan line from image file}
  scan_dev_p: img_scan1_arg_p_t;       {pointer to scan line for RENDlib device}
  event: rend_event_t;                 {descriptor for last event encountered}
  imgfile_info: file_info_t;           {file system info about image file}
  fnam:                                {scratch file name}
    %include '/cognivision_links/dsee_libs/string/string_treename.ins.pas';
  p: string_index_t;                   {string parse index}
  conn: file_conn_t;                   {scratch file connection}
  fit_on: boolean;                     {TRUE if -FIT command line option used}
  bitmap_alloc: boolean;               {TRUE if bitmap pixels already allocated}
  dith_on: boolean;                    {TRUE if dithering is ON}
  use_sw: boolean;                     {TRUE if primitive uses SW bitmap}
  xor_ok: boolean;                     {TRUE if use XOR mode when dragging}
  pending_resize: boolean;             {TRUE if window resized but not redrawn}
  pending_redraw: boolean;             {TRUE if window needs redrawing}
  auto_advance: boolean;               {automatically advance to next image}
  auto_loop: boolean;                  {loop back to first image after last}
  img_open: boolean;                   {TRUE if current image file open}
  backg_clear: boolean;                {TRUE if supposed to clear background}
  first_img: boolean;                  {TRUE on first image draw}

  pick: sys_int_machine_t;             {number of token picked from list}
  opt:                                 {command line option name}
    %include '/cognivision_links/dsee_libs/string/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '/cognivision_links/dsee_libs/string/string_treename.ins.pas';
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {system-independent error code}

  envvar_nopex: string_var16_t :=
    [str := 'RENDLIB_NO_PEX', len := 14, max := 16];

label
  next_opt, loop_list, err_list, done_opt,  parm_error, done_opts,
  next_image, new_image, size_changed, redraw, done_drawing, event_wait,
  zoom_in, zoom_out, done_event;
{
**********************************************************
*
*   Subroutine WIND_TO_IMAGE (WX, WY, IX, IY)
*
*   Convert the window coordinates WX,WY to the image pixel coordinates
*   IX, IY.
}
procedure wind_to_image (
  in      wx, wy: sys_int_machine_t;   {input window coordinates}
  out     ix, iy: sys_int_machine_t);  {output image coordinates}
  val_param;

begin
  ix := (wx - uli_x) div zoom;
  iy := (wy - uli_y) div zoom;
  end;
{
**********************************************************
*
*   Subroutine IMAGE_TO_WIND (IX, IY, WX, WY)
*
*   Return the window pixel coordinate WX,WY that maps to the top left
*   corner of the image pixel IX,IY.
}
procedure image_to_wind (
  in      ix, iy: sys_int_machine_t;   {input image coordinates}
  out     wx, wy: sys_int_machine_t);  {output window coordinates}
  val_param;

begin
  wx := uli_x + (ix * zoom);
  wy := uli_y + (iy * zoom);
  end;
{
**********************************************************
*
*   Subroutine DRAG_ON
*
*   Set up state for dragging with the mouse.
}
procedure drag_on;

begin
  rend_get.dith_on^ (dith_on);         {save current dithering state}
  rend_set.dith_on^ (false);           {temporarily disable dithering}
  if xor_ok then begin
    rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_xor_k);
    rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_xor_k);
    rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_xor_k);
    rend_set.rgb^ (0.5, 0.5, 0.5);
    end;
  rend_set.event_req_pnt^ (true);      {enable pointer motion events}
  rend_event_req_stdin_line (false);   {disable standard input events}
  end;
{
**********************************************************
*
*   Subroutine DRAG_DRAW
*
*   Set up state for drawing object in drag mode.
}
procedure drag_draw;

begin
  if not xor_ok then begin
    rend_set.rgb^ (1.0, 1.0, 0.5);
    end;
  end;
{
**********************************************************
*
*   Subroutine DRAG_UNDRAW
*
*   Set up state for undrawing an object previously drawn in drag mode.
}
procedure drag_undraw;

begin
  if not xor_ok then begin
    rend_set.rgb^ (0.0, 0.0, 0.0);
    end;
  end;
{
**********************************************************
*
*   Subroutine DRAG_OFF
*
*   Restore state to normal from dragging with the mouse.
}
procedure drag_off;

begin
  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_insert_k);
  rend_set.dith_on^ (dith_on);         {restore old dithering state}
  rend_set.event_req_pnt^ (false);     {disable pointer motion events}
  rend_event_req_stdin_line (true);    {re-enable standard input events}
  end;
{
**********************************************************
*
*   Function KEY_PAN
*
*   Handle event where PAN key was just pressed.  The function returns TRUE
*   if a redraw is required.
}
function key_pan
  :boolean;                            {TRUE if redraw required}

var
  ps_x, ps_y: sys_int_machine_t;       {starting coordinates of pan operation}
  pnt_x, pnt_y: sys_int_machine_t;     {new pointer coordinates}

label
  wait, event_unexpected;

begin
  key_pan := false;                    {init to no redraw is required}
  ps_x := event.key.x;                 {save original pointer coordinates}
  ps_y := event.key.y;
  pnt_x := ps_x;                       {init current rubber band end point}
  pnt_y := ps_y;
  rend_set.enter_level^ (1);           {enter graphics mode}
  drag_on;                             {set up state for dragging with pointer}
  drag_draw;                           {set of for drawing dragged object}
  rend_set.cpnt_2dim^ (ps_x + 0.5, ps_y + 0.5); {go to start of vector}
  rend_prim.vect_2dimcl^ (pnt_x + 0.5, pnt_y + 0.5); {draw original rubber band}
  rend_prim.flush_all^;                {make sure line is drawn now}

wait:                                  {back here to wait for new event}
  rend_set.enter_level^ (0);           {leave graphics mode before event wait}
  rend_event_get (event);              {get the next event}
  case event.ev_type of                {what kind of event is this ?}

rend_ev_key_k: begin                   {user hit or released a key}
      if event.key.key_p^.id_user <> key_pan_k {this is not our key ?}
        then goto event_unexpected;
      anch_img.x :=                    {update anchor point on image}
        (ps_x - uli_x + 0.5) / (img.x_size * zoom);
      anch_img.y :=
        (ps_y - uli_y + 0.5) / (img.y_size * zoom);
      anch_dev.x :=                    {update anchor point on drawing device}
        (event.key.x + 0.5) / image_width;
      anch_dev.y :=
        (event.key.y + 0.5) / image_height;
      rend_set.enter_rend^;            {enter graphics mode}
      if (event.key.x = ps_x) and (event.key.y = ps_y)
        then begin                     {no net pan was performed}
          rend_set.cpnt_2dim^ (        {go to start of old rubber band}
           ps_x + 0.5, ps_y + 0.5);
          rend_prim.vect_2dimcl^ (pnt_x + 0.5, pnt_y + 0.5); {erase old rubber band}
          rend_prim.flush_all^;        {make sure line is drawn now}
          drag_off;                    {restore from dragging state}
          end
        else begin                     {the picture was panned}
          drag_off;                    {restore from dragging state}
          key_pan := true;             {the picture will need to be redrawn}
          end
        ;
      end;                             {end of key event in pan operation}

rend_ev_pnt_move_k: begin
      rend_set.enter_rend^;            {enter graphics mode}
      drag_undraw;                     {set up for undrawing dragged object}
      rend_set.cpnt_2dim^ (            {go to start of old rubber band}
        ps_x + 0.5, ps_y + 0.5);
      rend_prim.vect_2dimcl^ (pnt_x + 0.5, pnt_y + 0.5); {erase old rubber band}
      drag_draw;                       {set of for drawing dragged object}
      rend_set.cpnt_2dim^ (            {go to start of new rubber band}
        ps_x + 0.5, ps_y + 0.5);
      rend_prim.vect_2dimcl^ (         {redraw rubber band in new position}
        event.pnt_move.x + 0.5,
        event.pnt_move.y + 0.5);
      rend_prim.flush_all^;            {make sure rubber band is drawn now}
      pnt_x := event.pnt_move.x;       {save rubber band end coordinates}
      pnt_y := event.pnt_move.y;
      goto wait;                       {back and wait for more events within PAN}
      end;

otherwise
event_unexpected:                      {jump here if got unexpected event}
    rend_event_push (event);           {put the event back}
    end;                               {end of event cases within pan operation}

  end;
{
**********************************************************
*
*   Subroutine DRAW_INQRECT (RECT)
*
*   Draw the outine of the inquire rectangle.
}
procedure draw_inqrect (
  in      rect: inqrect_t);            {inquire rectangle bounds}

var
  x1, x2: sys_int_machine_t;           {left/right edges of rect in wind coord}
  y1, y2: sys_int_machine_t;           {top/bottom edges of rect in wind coord}

begin
  image_to_wind (rect.xmin, rect.ymin, x1, y1); {convert rect to window coordinates}
  image_to_wind (rect.xmax, rect.ymax, x2, y2);

  x2 := x2 + zoom - 1;                 {go to farthest edge of pixels}
  y2 := y2 + zoom - 1;

  x1 := max(0, min(image_width-1, x1)); {clip to actual window area}
  y1 := max(0, min(image_height-1, y1));
  x2 := max(0, min(image_width-1, x2));
  y2 := max(0, min(image_height-1, y2));

  rend_set.cpnt_2dimi^ (x1, y1);       {move to top left corner of rectangle}

  if (x2 = x1) or (y2 = y1) then begin {rectangle is collapsed to a line ?}
    rend_prim.vect_2dimi^ (x2, y2);
    return;
    end;

  rend_prim.vect_2dimi^ (x1, y2 - 1);  {draw left edge of rectangle}
  rend_set.cpnt_2dimi^ (x1, y2);       {go to start of bottom edge}
  rend_prim.vect_2dimi^ (x2 - 1, y2);  {draw bottom edge}
  rend_set.cpnt_2dimi^ (x2, y2);       {go to start of right edge}
  rend_prim.vect_2dimi^ (x2, y1 + 1);  {draw right edge}
  rend_set.cpnt_2dimi^ (x2, y1);       {go to start of top edge}
  rend_prim.vect_2dimi^ (x1 + 1, y1);  {draw top edge}
  end;
{
**********************************************************
*
*   Subroutine CLIP_RECT (RECT)
*
*   Clip the inquire rectangle to the visible portion of the image in the
*   current window.  The inquire rectangle is in image coordinates.
}
procedure clip_rect (
  in out  rect: inqrect_t);            {rectangle to adjust if neccessary}

var
  x, y: sys_int_machine_t;             {scratch coordinates}

begin
{
*   Clip upper left corner to window.
}
  image_to_wind (rect.xmin, rect.ymin, x, y);
  x := max(0, min(image_width - 1, x));
  y := max(0, min(image_height - 1, y));
  wind_to_image (x, y, rect.xmin, rect.ymin);
{
*   Clip lower right corner to window.
}
  image_to_wind (rect.xmax, rect.ymax, x, y);
  x := max(0, min(image_width - 1, x));
  y := max(0, min(image_height - 1, y));
  wind_to_image (x, y, rect.xmax, rect.ymax);
{
*   Clip upper left corner to image.
}
  rect.xmin := max(0, min(img.x_size - 1, rect.xmin));
  rect.ymin := max(0, min(img.y_size - 1, rect.ymin));
{
*   Clip lower right corner to image.
}
  rect.xmax := max(0, min(img.x_size - 1, rect.xmax));
  rect.ymax := max(0, min(img.y_size - 1, rect.ymax));
  end;
{
**********************************************************
*
*   Subroutine KEY_INQUIRE
*
*   Handle event where INQUIRE key was just pressed.
}
procedure key_inquire;

const
  max_msg_parms = 8;                   {max parameters we can pass to a message}

var
  inqx, inqy: sys_int_machine_t;       {pixel that is always within inquire rect}
  rect: inqrect_t;                     {current inquire rectangle}
  acc_red, acc_grn, acc_blu, acc_alpha: {average color value accumulators}
    sys_int_conv32_t;
  av_red, av_grn, av_blu, av_alpha:    {average 0.0 to 1.0 color values}
    real;
  av_ir, av_ig, av_ib, av_ia:          {average 0-255 color values}
    real;
  n: sys_int_conv24_t;                 {number of pixels in inquire rectangle}
  ix, iy: sys_int_machine_t;           {scratch pixel coordinate}
  dx, dy: sys_int_machine_t;           {size of inquire rectangle}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

label
  wait, event_unexpected;

begin
  wind_to_image (                      {find image pixel where event was}
    event.key.x, event.key.y,          {input window coordinate}
    inqx, inqy);                       {output image coordinate}
  rect.xmin := inqx;                   {init rectangle to original pixel}
  rect.xmax := inqx;
  rect.ymin := inqy;
  rect.ymax := inqy;
  clip_rect (rect);                    {clip rectangle to image and window}
  inqx := rect.xmin;                   {save clipped inquire starting point}
  inqy := rect.ymin;
  rend_set.enter_level^ (1);           {enter graphics mode}
  drag_on;                             {set up state for dragging with pointer}
  drag_draw;                           {set of for drawing dragged object}
  draw_inqrect (rect);                 {show the inquire rectangle}

wait:                                  {back here to wait for new event}
  rend_set.enter_level^ (0);           {leave graphics mode before event wait}
  rend_event_get (event);              {get the next event}
  case event.ev_type of                {what kind of event is this ?}

rend_ev_key_k: begin                   {user hit or released a key}
      if event.key.key_p^.id_user <> key_inquire_k {this is not our key ?}
        then goto event_unexpected;
      end;                             {end of key event in pan operation}

rend_ev_pnt_move_k: begin              {the pointer was moved}
      wind_to_image (                  {find image pixel where pointer is now}
        event.pnt_move.x, event.pnt_move.y, {input window coordinate}
        ix, iy);                       {output image coordinate}
      rend_set.enter_rend^;            {enter graphics mode}
      drag_undraw;                     {set up for undrawing dragged object}
      draw_inqrect (rect);             {undraw old inquire rectangle}
      drag_draw;                       {set up for drawing dragged object}
      rect.xmin := min(inqx, ix);      {make new inquire rectangle}
      rect.xmax := max(inqx, ix);
      rect.ymin := min(inqy, iy);
      rect.ymax := max(inqy, iy);
      clip_rect (rect);                {clip new rectangle to image and window}
      draw_inqrect (rect);             {draw new inquire rectangle}
      goto wait;                       {back and wait for more events within PAN}
      end;

otherwise
event_unexpected:                      {jump here if got unexpected event}
    rend_event_push (event);           {put the event back}
    end;                               {end of event cases within pan operation}
{
*   The final inquire rectangle is all set.  Now undraw it and actually do the
*   inquire.
}
  rend_set.enter_rend^;                {enter graphics mode}
  drag_undraw;                         {set up for undrawing rectangle}
  draw_inqrect (rect);                 {undraw the inquire rectangle}
  drag_off;                            {all done dragging}
  rend_set.exit_rend^;                 {don't need to draw anything more}

  acc_red := 0;                        {init average value accumulators}
  acc_grn := 0;
  acc_blu := 0;
  acc_alpha := 0;

  if img.next_y <> 0 then begin        {image file not at start of image ?}
    img_rewind (img, stat);            {rewind image file to first scan line}
    rend_error_abort (stat, 'img', 'rewind', nil, 0);
    end;

  while img.next_y <= rect.ymax do begin {still above or within the rectangle ?}
    img_read_scan1 (img, scan_img_p^, stat); {read this scan line from image file}
    rend_error_abort (stat, 'img', 'read_scan_line', nil, 0);
    if img.next_y <= rect.ymin         {still above the inquire rectangle ?}
      then next;
    for ix := rect.xmin to rect.xmax do begin {once for each inq pixel this scan}
      with scan_img_p^[ix]: p do begin {P is this input scan line pixel}
        acc_red := acc_red + p.red;    {accumulate values for this pixel}
        acc_grn := acc_grn + p.grn;
        acc_blu := acc_blu + p.blu;
        acc_alpha := acc_alpha + p.alpha;
        end;                           {done with P abbreviation}
      end;                             {back and do next pixel accross within rect}
    end;                               {back and do next scan line down}

  dx := rect.xmax - rect.xmin + 1;     {make size of inquire rectangle}
  dy := rect.ymax - rect.ymin + 1;
  n := dx * dy;                        {number of pixels in rectangle}

  av_ir := acc_red / n;                {make average 0 to 255 color values}
  av_ig := acc_grn / n;
  av_ib := acc_blu / n;
  av_ia := acc_alpha / n;

  av_red := av_ir / 255.0;             {make average 0.0 to 1.0 color values}
  av_grn := av_ig / 255.0;
  av_blu := av_ib / 255.0;
  av_alpha := av_ia / 255.0;

  writeln;                             {leave blank line before writing values}
  if n = 1
    then begin                         {inquire area is just one pixel}
      sys_msg_parm_int (msg_parm[1], rect.xmin);
      sys_msg_parm_int (msg_parm[2], rect.ymin);
      sys_message_parms ('rend', 'image_disp_pix_coor', msg_parm, 2);
      end
    else begin                         {inquire area is a real rectangle}
      sys_msg_parm_int (msg_parm[1], dx);
      sys_msg_parm_int (msg_parm[2], dy);
      sys_msg_parm_int (msg_parm[3], rect.xmin);
      sys_msg_parm_int (msg_parm[4], rect.ymin);
      sys_msg_parm_int (msg_parm[5], rect.xmax);
      sys_msg_parm_int (msg_parm[6], rect.ymax);
      sys_message_parms ('rend', 'image_disp_rect_coor', msg_parm, 6);
      end
    ;

  sys_msg_parm_real (msg_parm[1], av_red);
  sys_msg_parm_real (msg_parm[2], av_grn);
  sys_msg_parm_real (msg_parm[3], av_blu);
  sys_msg_parm_real (msg_parm[4], av_alpha);
  sys_msg_parm_real (msg_parm[5], av_ir);
  sys_msg_parm_real (msg_parm[6], av_ig);
  sys_msg_parm_real (msg_parm[7], av_ib);
  sys_msg_parm_real (msg_parm[8], av_ia);
  sys_message_parms ('rend', 'image_disp_values', msg_parm, 8);
  end;
{
**********************************************************
*
*   Local subroutine OPEN_IMAGE
*
*   Ensure that the current image input file is open.
}
procedure open_image;

const
  max_retry_k = 10;                    {max number of retries allowed to open file}
  retry_wait_sec_k = 0.5;              {amount of time to wait between retries}

var
  retry_cnt: sys_int_machine_t;        {number of this try to open file}
  stat: sys_err_t;

label
  retry;

begin
  if img_open then return;             {image file already open}
  retry_cnt := 1;                      {next try will be first attempt}

retry:                                 {back here to retry opening image file}
  img_open_read_img (tnam_p^, img, stat); {try to open new image file}
  if file_not_found(stat) then begin
    img_open_read_img (tnam_p^, img, stat); {set error status again}
    retry_cnt := max_retry_k;          {don't allow any more retries}
    end;
  if sys_error(stat) and (retry_cnt < max_retry_k) then begin {OK to retry on fail ?}
    sys_wait (retry_wait_sec_k);       {wait a while before trying again}
    retry_cnt := retry_cnt + 1;        {update retry count for this new try}
    goto retry;                        {try to open file again}
    end;
  sys_msg_parm_vstr (msg_parm[1], tnam_p^);
  sys_error_abort (stat, 'img', 'open_read', msg_parm, 1);
  img_open := true;                    {image file is now open}

  file_info (                          {get info about newly opened image file}
    img.tnam,                          {name of file inquiring about}
    [file_iflag_dtm_k],                {we are requesting last modified time stamp}
    imgfile_info,                      {returned date/time info}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
**********************************************************
*
*   Local subroutine CLOSE_IMAGE
*
*   The the currently open image, if any.
}
procedure close_image;

const
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

begin
  if img_open then begin               {need to close old image file ?}
    img_close (img, stat);             {close the currently displayed image file}
    sys_msg_parm_vstr (msg_parm[1], img.tnam);
    rend_error_abort (stat, 'img', 'close', msg_parm, 1);
    img_open := false;                 {indicate image file is now closed}
    end;
  end;
{
**********************************************************
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
**********************************************************
*
*   Start of main routine.
}
begin
  string_cmline_init;                  {init for reading command line}

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

  string_list_init (img_list, util_top_mem_context); {init list of image files}
  img_list.deallocable := false;       {won't need to deallocate individual entries}

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
{
*   Create the environment variable RENDLIB_NO_PEX and set it to TRUE, if
*   is doesn't already exist.
}
  sys_envvar_get (envvar_nopex, parm, stat); {try to read environment variable}
  if sys_error(stat) then begin        {apparently doesn't exist ?}
    sys_envvar_set (                   {create environment variable and set value}
      envvar_nopex,                    {environment variable name}
      string_v('TRUE'(0)),             {value to set envvar to}
      stat);
    sys_error_none (stat);             {reset any error status}
    end;

  rend_start;                          {init RENDlib}
  rend_open (                          {open our graphics device}
    dev_name,                          {name of RENDlib device to use}
    rend_dev,                          {returned RENDlib device ID}
    stat);                             {error status}
  sys_error_abort (stat, 'rend', 'rend_open', nil, 0);
  rend_set.enter_rend^;                {get into graphics mode}

  rend_set.alloc_bitmap_handle^ (      {create handle to bitmap of RGB values}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    image_bitmap);                     {returned bitmap handle}
  bitmap_alloc := false;               {no bitmap pixels have been allocated}

  rend_get.clip_2dim_handle^ (clip_handle); {create handle to a 2DIM clip window}

  rend_set.iterp_on^ (rend_iterp_red_k, true); {turn on RGB interpolants}
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_on^ (rend_iterp_red_k, true); {enable for SPAN primitive}
  rend_set.iterp_span_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_span_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_ofs^ (           {set position in scan line pixels}
    rend_iterp_red_k, ord(img_col_red_k));
  rend_set.iterp_span_ofs^ (
    rend_iterp_grn_k, ord(img_col_grn_k));
  rend_set.iterp_span_ofs^ (
    rend_iterp_blu_k, ord(img_col_blu_k));

  rend_set.span_config^ (sizeof(img_pixel1_t)); {offset for one pixel to the right}

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
  rend_event_req_stdin_line (true);

  xor_ok := true;                      {init to use XOR mode for dragging}
  drag_on;                             {set up state as if for dragging}
  rend_get.update_sw_prim^ (           {check for XOR vectors read SW bitmap}
    rend_prim.vect_2dimcl,             {call table entry for primitive}
    use_sw);                           {TRUE if XOR vectors use SW bitmap}
  drag_off;                            {restore state from dragging mode}
  if use_sw then begin                 {XOR vectors access SW bitmap ?}
    xor_ok := false;                   {init to not use XOR mode for dragging}
    drag_on;                           {set up state as if for dragging}
    rend_get.update_sw_prim^ (         {check for dragging vectors write SW bitmap}
      rend_prim.vect_2dimcl,           {call table entry for primitive}
      use_sw);                         {TRUE if would do SW emulation anyway}
    drag_off;                          {restore state from dragging mode}
    xor_ok := use_sw;                  {use XOR if alternative no better}
    end;

  rend_set.exit_rend^;

  scan_img_p := nil;                   {init to no scan line memory allocated}
  img_open := false;                   {init to no image file currently open}
  first_img := true;                   {init to next draw is first image}
{
*   Back here to advance to next image in list and display it.
}
next_image:
  close_image;                         {make sure no image currently open}

  if img_list.curr >= img_list.n then begin {already at the last image in the list ?}
    if auto_loop
      then begin                       {loop back to first image in list}
        string_list_pos_start (img_list); {reset to before first image}
        end
      else begin                       {done with last image, exit program}
        rend_end;                      {close the graphics}
        return;                        {exit the program}
        end
      ;
    end;                               {done handling at end of images list}

  string_list_pos_rel (img_list, 1);   {go to next image in image files list}
{
*   Back here to display with a new current image.  The new IMG_LIST
*   position has already been set.
}
new_image:
  close_image;                         {make sure old image, if any, is closed}

  tnam_p := univ_ptr(img_list.str_p);  {make pointer to image file name treename}
  open_image;                          {open the new image file}

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
  open_image;                          {make sure image file is open}
  rend_set.enter_level^ (1);           {get into graphics mode}
  rend_get.image_size^ (               {find out what size window we have}
    image_width, image_height, aspect);

  if bitmap_alloc then begin           {need to deallocate previous bitmap pixels ?}
    rend_set.dealloc_bitmap^ (image_bitmap); {deallocate old pixel memory}
    rend_mem_dealloc (scan_dev_p, rend_scope_dev_k); {deallocate scan line buffer}
    end;

  rend_mem_alloc (                     {allocate memory for RENDlib scan line}
    image_width * sizeof(img_pixel1_t), {amount of memory to allocate}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    true,                              {we will need to individually deallcate this}
    scan_dev_p);                       {returned pointer to the new memory}
  bitmap_alloc := true;                {a bitmap is currently allocated}

  rend_set.alloc_bitmap^ (             {allocate the RGB pixels for this image}
    image_bitmap,                      {handle to this bitmap}
    image_width, image_height,         {size of image in pixels}
    3,                                 {number of bytes to allocate for each pixel}
    rend_scope_dev_k);                 {bitmap belongs to RENDlib device}

  rend_set.iterp_bitmap^ (             {connect bitmap to red interpolator}
    rend_iterp_red_k,                  {interpolant ID to connect bitmap to}
    image_bitmap,                      {handle to the bitmap}
    0);                                {byte index into pixel for this interpolant}
  rend_set.iterp_bitmap^ (             {connect bitmap to green interpolator}
    rend_iterp_grn_k,
    image_bitmap,
    1);
  rend_set.iterp_bitmap^ (             {connect bitmap to blue interpolator}
    rend_iterp_blu_k,
    image_bitmap,
    2);

  rend_set.update_mode^ (rend_updmode_buffall_k); {may buffer pixel writes}

  rend_set.exit_rend^;

  if fit_on then begin                 {zoom image to fit draw area ?}
    zoom :=                            {largest zoom that still lets image fit}
      max(1, min(image_width div img.x_size, image_height div img.y_size));
    end;
{
*   Back here to redraw.
}
redraw:
  open_image;                          {make sure image input file is open}
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
        for i := 0 to dx-1 do begin    {once for each device pixel to fill in}
          if x_zoom <= 0 then begin    {exhausted this pixel, move on to next ?}
            ix := ix + 1;              {advance to next source pixel}
            x_zoom := zoom;            {reset zoom phase for new pixel}
            end;
          scan_dev_p^[i] := scan_img_p^[ix]; {copy this output pixel}
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
    close_image;                       {close currently displayed image file}
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
  close_image;                         {close current image file, if open}
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
  close_image;                         {close current image file, if open}
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
      pending_redraw := pending_redraw or key_pan;
      end;

key_inquire_k: begin                   {get value of pixel or rectangular region}
      key_inquire;                     {handle inquire in separate routine}
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
